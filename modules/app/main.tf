##############################################################################
# App Module
#
# Deploys a demo Kubernetes workload (Deployment + Service) reachable
# from the internet via a LoadBalancer service.
##############################################################################

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.namespace

    labels = {
      app         = var.project_name
      environment = var.environment
    }
  }
}

# ---------------------------------------------------------------------------
# ConfigMap — non-sensitive application config
# ---------------------------------------------------------------------------
resource "kubernetes_config_map" "app" {
  metadata {
    name      = "${var.project_name}-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    DB_HOST = var.db_host
    DB_PORT = tostring(var.db_port)
    DB_NAME = var.db_name
  }
}

# ---------------------------------------------------------------------------
# Deployment
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.project_name
    namespace = kubernetes_namespace.app.metadata[0].name

    labels = {
      app = var.project_name
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.project_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.project_name
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(var.container_port)
        }
      }

      spec {
        container {
          name  = "app"
          image = var.container_image

          port {
            container_port = var.container_port
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app.metadata[0].name
            }
          }

          # --- Health checks ---
          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "128Mi"
            }
          }

          security_context {
            read_only_root_filesystem  = false # nginx needs /tmp
            run_as_non_root            = false # nginx default image runs as root; override in prod
            allow_privilege_escalation = false
          }
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Service — LoadBalancer
# ---------------------------------------------------------------------------
resource "kubernetes_service" "app" {
  metadata {
    name      = var.project_name
    namespace = kubernetes_namespace.app.metadata[0].name

    annotations = {
      # Use NLB for better performance / static IPs
      "service.beta.kubernetes.io/aws-load-balancer-type"   = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-scheme" = "internet-facing"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = var.project_name
    }

    port {
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }
  }
}
