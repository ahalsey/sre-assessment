output "service_url" {
  description = "Load balancer hostname for the demo app"
  value       = try(kubernetes_service.app.status[0].load_balancer[0].ingress[0].hostname, "pending")
}

output "namespace" {
  description = "Kubernetes namespace for the application"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "lb_controller_ready" {
  description = "Indicates the LB controller is installed"
  value       = helm_release.lb_controller.status
}
