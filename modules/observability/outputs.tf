output "sns_topic_arn" {
  description = "ARN of the SNS alerts topic"
  value       = aws_sns_topic.alerts.arn
}

output "log_group_name" {
  description = "CloudWatch log group for cluster logs"
  value       = data.aws_cloudwatch_log_group.eks.name
}
