output "endpoint" {
  description = "RDS instance endpoint (host)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Database name"
  value       = aws_db_instance.this.db_name
}

output "db_username" {
  description = "Master username"
  value       = aws_db_instance.this.username
  sensitive   = true
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret containing credentials"
  value       = aws_secretsmanager_secret.db.arn
}

output "security_group_id" {
  description = "Security group ID of the RDS instance"
  value       = aws_security_group.rds.id
}
