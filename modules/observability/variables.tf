variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "sns_alert_email" {
  description = "Email for alarm notifications (empty = no subscription)"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}
