terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    #   Configured via environment variables
    #   bucket         = "platform-sre-demo-tfstate"
    #   key            = "dev/terraform.tfstate"
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
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "platform" {
  source = "../../"

  providers = {
    aws        = aws
    kubernetes = kubernetes
    helm       = helm
  }

  project_name       = "platform-sre-demo"
  environment        = "dev"
  aws_region         = var.aws_region
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]
  single_nat_gateway = true # Cost saving

  # EKS — minimal for dev
  eks_cluster_version       = "1.29"
  eks_node_instance_types   = ["t3.medium"]
  eks_node_desired_capacity = 2
  eks_node_min_size         = 1
  eks_node_max_size         = 3
  eks_node_disk_size        = 20

  # RDS — smallest possible
  rds_instance_class    = "db.t3.micro"
  rds_allocated_storage = 20
  rds_multi_az          = false

  # App
  app_replicas = 1

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
  name = module.platform.eks_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.platform.eks_cluster_name
}

provider "kubernetes" {
  host                   = module.platform.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.platform.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
