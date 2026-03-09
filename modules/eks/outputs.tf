output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint for the EKS API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded CA certificate for the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for the cluster"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "node_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.node.id
}

output "node_role_arn" {
  description = "IAM role ARN of the node group"
  value       = aws_iam_role.node_group.arn
}

output "lb_controller_ready" {
  description = "Indicates the LB controller is installed"
  value       = var.install_lb_controller ? helm_release.lb_controller[0].status : null
}

output "cluster_security_group_id" {
  description = "EKS-managed cluster security group ID"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
