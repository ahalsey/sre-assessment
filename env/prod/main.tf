terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    #   Configured via environment variables
    #   bucket         = "platform-sre-demo-tfstate"
    #   key            = "prod/terraform.tfstate"
    #   region         = "us-east-1"
    #   dynamodb_table = "terraform-state-lock"
    #   encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "platform-sre-demo"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

module "platform" {
  source = "../../"

  project_name       = "platform-sre-demo"
  environment        = "prod"
  aws_region         = var.aws_region
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
  single_nat_gateway = false # HA in prod

  # EKS
  eks_cluster_version       = "1.31"
  eks_node_instance_types   = ["t3.large"]
  eks_node_desired_capacity = 3
  eks_node_min_size         = 2
  eks_node_max_size         = 6
  eks_node_disk_size        = 50

  # RDS
  rds_instance_class    = "db.t3.small"
  rds_allocated_storage = 50
  rds_multi_az          = true

  # App
  app_replicas = 3

  # Observability
  alert_email = var.alert_email
}

variable "aws_region" {
  default = "us-east-1"
}

variable "alert_email" {
  default = ""
}

output "kubeconfig_command" {
  value = module.platform.eks_kubeconfig_command
}

output "app_url" {
  value = module.platform.app_service_url
}

data "aws_eks_cluster" "this" {
  name = "platform-sre-demo-prod-eks"
}

data "aws_eks_cluster_auth" "this" {
  name = "platform-sre-demo-prod-eks"
}

provider "kubernetes" {
  host                   = module.platform.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.platform.eks_cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.platform.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.platform.eks_cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
