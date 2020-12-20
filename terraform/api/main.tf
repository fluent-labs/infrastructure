terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
  }
}

data "digitalocean_kubernetes_cluster" "foreign_language_reader" {
  name = var.cluster_name
}

resource "kubernetes_service" "api" {
  metadata {
    name      = "api"
    namespace = var.env
  }
  spec {
    selector = {
      app = "api"
    }
    port {
      port = 9000
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "api_autoscale" {
  metadata {
    name      = "api"
    namespace = var.env
  }
  spec {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "api"
    }
    target_cpu_utilization_percentage = 75
  }
}

resource "kubernetes_deployment" "api" {
  metadata {
    name      = "api"
    namespace = var.env
  }

  spec {
    selector {
      match_labels = {
        app = "api"
      }
    }

    template {
      metadata {
        labels = {
          app = "api"
        }
      }

      spec {
        container {
          image = "registry.digitalocean.com/foreign-language-reader-api/api:latest"
          name  = "api"

          port {
            container_port = 9000
          }

          resources {
            limits {
              memory = "500Mi"
            }
            requests {
              memory = "100Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 9000
            }

            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/readiness"
              port = 9000
            }

            initial_delay_seconds = 60
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

  # The deployment will not come up without the database connection
  # depends_on = [
  #   digitalocean_database_user.api_user,
  #   digitalocean_database_db.api_database,
  #   kubernetes_secret.api_database_credentials
  # ]
}

# Configure database

# resource "digitalocean_database_user" "api_user" {
#   cluster_id = data.digitalocean_database_cluster.api_mysql.id
#   name       = "api-${var.env}"
# }

# resource "digitalocean_database_db" "api_database" {
#   cluster_id = data.digitalocean_database_cluster.api_mysql.id
#   name       = "foreign-language-reader-${var.env}"
# }

# resource "kubernetes_secret" "api_database_credentials" {
#   metadata {
#     name      = "api-database-credentials"
#     namespace = var.env
#   }

#   data = {
#     username          = digitalocean_database_user.api_user.name
#     password          = digitalocean_database_user.api_user.password
#     host              = data.digitalocean_database_cluster.api_mysql.private_host
#     port              = data.digitalocean_database_cluster.api_mysql.port
#     database          = digitalocean_database_db.api_database.name
#     connection_string = "ecto://${digitalocean_database_user.api_user.name}:${digitalocean_database_user.api_user.password}@${data.digitalocean_database_cluster.api_mysql.private_host}:${data.digitalocean_database_cluster.api_mysql.port}/${digitalocean_database_db.api_database.name}"
#   }
# }

# Secret key base powers encryption at rest for the database

resource "random_password" "api_secret_key_base" {
  length  = 64
  special = true
}

resource "kubernetes_secret" "api_secret_key_base" {
  metadata {
    name      = "api-secret-key-base"
    namespace = var.env
  }

  data = {
    secret_key_base = random_password.api_secret_key_base.result
  }
}
