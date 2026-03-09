variable "project_name" {
  description = "Project identifier used in resource naming and tagging"
  type        = string
  default     = "platform-sre-demo"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to deploy into (minimum 2)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cost saving for non-prod)"
  type        = bool
  default     = true
}

variable "eks_cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.34"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_node_desired_capacity" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "eks_node_disk_size" {
  description = "Disk size in GiB for worker nodes"
  type        = number
  default     = 20
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB"
  type        = number
  default     = 20
}

variable "rds_db_name" {
  description = "Name of the default database"
  type        = string
  default     = "appdb"
}

variable "rds_db_username" {
  description = "Master username for the database"
  type        = string
  default     = "dbadmin"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "app_namespace" {
  description = "Kubernetes namespace for the demo application"
  type        = string
  default     = "demo"
}

variable "app_container_image" {
  description = "Container image for the demo application"
  type        = string
  default     = "nginx:1.25-alpine"
}

variable "app_container_port" {
  description = "Port the application container listens on"
  type        = number
  default     = 80
}

variable "app_replicas" {
  description = "Number of application replicas"
  type        = number
  default     = 2
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "install_lb_controller" {
  type    = bool
  default = false
}

