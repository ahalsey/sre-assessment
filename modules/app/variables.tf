variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "namespace" {
  type    = string
  default = "demo"
}

variable "container_image" {
  type    = string
  default = "adminer"
}

variable "container_port" {
  type    = number
  default = 8080
}

variable "replicas" {
  type    = number
  default = 2
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret for DB credentials"
  type        = string
}
