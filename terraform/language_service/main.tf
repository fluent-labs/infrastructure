terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.20.0"
    }
  }
}

resource "kubernetes_service" "language_service" {
  metadata {
    name      = "language-service"
    namespace = var.env
    labels = {
      "app" = "language-service"
    }
  }
  spec {
    selector = {
      app = "language-service"
    }
    port {
      name = "language-service"
      port = 8000
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "language_service_autoscale" {
  metadata {
    name      = "language-service"
    namespace = var.env
  }
  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "language-service"
    }
    target_cpu_utilization_percentage = 75
  }
}

resource "kubernetes_deployment" "language_service" {
  metadata {
    name      = "language-service"
    namespace = var.env
  }

  spec {
    selector {
      match_labels = {
        app = "language-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "language-service"
        }
      }

      spec {
        # image_pull_secrets {
        #   name = "regcred"
        # }

        container {
          image = "lkjaero/language-service:latest"
          name  = "language-service"

          port {
            container_port = 8000
          }

          env {
            name  = "ENVIRONMENT"
            value = var.env
          }

          resources {
            limits = {
              memory = "2000Mi"
            }
            requests = {
              memory = "1400Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }
        }
      }
    }
  }

  # This resource is to make sure the deployment exists
  # Not blow away what's current for something that doesn't exist.
  lifecycle {
    ignore_changes = [
      spec.0.template.0.spec.0.container.0.image,
      spec.0.replicas
    ]
  }
}