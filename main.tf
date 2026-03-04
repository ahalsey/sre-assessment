terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Networking

module "vpc" {
  source = "./modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway

  tags = local.common_tags
}

# EKS

module "eks" {
  source = "./modules/eks"

  project_name          = var.project_name
  environment           = var.environment
  cluster_version       = var.eks_cluster_version
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  node_instance_types   = var.eks_node_instance_types
  node_desired_capacity = var.eks_node_desired_capacity
  node_min_size         = var.eks_node_min_size
  node_max_size         = var.eks_node_max_size
  node_disk_size        = var.eks_node_disk_size

  tags = local.common_tags
}

# RDS

module "rds" {
  source = "./modules/rds"

  project_name               = var.project_name
  environment                = var.environment
  vpc_id                     = module.vpc.vpc_id
  database_subnet_ids        = module.vpc.database_subnet_ids
  allowed_security_group_ids = [module.eks.node_security_group_id]

  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  db_name           = var.rds_db_name
  db_username       = var.rds_db_username
  multi_az          = var.rds_multi_az

  tags = local.common_tags
}

# Demo Application

module "app" {
  source = "./modules/app"

  project_name    = var.project_name
  environment     = var.environment
  namespace       = var.app_namespace
  container_image = var.app_container_image
  container_port  = var.app_container_port
  replicas        = var.app_replicas

  db_host       = module.rds.endpoint
  db_port       = module.rds.port
  db_name       = module.rds.db_name
  db_username   = module.rds.db_username
  db_secret_arn = module.rds.secret_arn

  depends_on = [module.eks, module.rds]
}

# Observability

module "observability" {
  source = "./modules/observability"

  project_name    = var.project_name
  environment     = var.environment
  cluster_name    = module.eks.cluster_name
  sns_alert_email = var.alert_email

  tags = local.common_tags

  depends_on = [module.eks]
}
