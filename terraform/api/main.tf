terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.12.1"
    }
  }
}

locals {
  database_name = "fluentlabs-${var.env}"
}

data "aws_db_instance" "api_db" {
  db_instance_identifier = var.database_name
}

resource "kubernetes_service" "api" {
  metadata {
    name      = "api"
    namespace = var.env
    labels = {
      "app" = "api"
    }
  }
  spec {
    selector = {
      app = "api"
    }
    port {
      name = "api"
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
        # image_pull_secrets {
        #   name = "regcred"
        # }

        container {
          image = "lkjaero/foreign-language-reader-api:LATEST"
          name  = "api"

          port {
            container_port = 9000
          }

          env {
            name = "APPLICATION_SECRET"
            value_from {
              secret_key_ref {
                name = "application-secret"
                key  = "application_secret"
              }
            }
          }

          env {
            name = "WEBSTER_LEARNERS_KEY"
            value_from {
              secret_key_ref {
                name = "webster"
                key  = "learners"
              }
            }
          }

          env {
            name = "WEBSTER_SPANISH_KEY"
            value_from {
              secret_key_ref {
                name = "webster"
                key  = "spanish"
              }
            }
          }

          env {
            name = "ELASTICSEARCH_PASSWORD"
            value_from {
              secret_key_ref {
                name = "elasticsearch-credentials"
                key  = "password"
              }
            }
          }

          env {
            name = "DATABASE_URL"
            value_from {
              secret_key_ref {
                name = "api-database-credentials"
                key  = "connection_string"
              }
            }
          }

          env {
            name = "DATABASE_USERNAME"
            value_from {
              secret_key_ref {
                name = "api-database-credentials"
                key  = "username"
              }
            }
          }

          env {
            name = "DATABASE_PASSWORD"
            value_from {
              secret_key_ref {
                name = "api-database-credentials"
                key  = "password"
              }
            }
          }

          env {
            name = "AUTH0_AUDIENCE"
            value_from {
              secret_key_ref {
                name = "auth0"
                key  = "audience"
              }
            }
          }

          env {
            name = "AUTH0_DOMAIN"
            value_from {
              secret_key_ref {
                name = "auth0"
                key  = "domain"
              }
            }
          }

          env {
            name  = "GOOGLE_APPLICATION_CREDENTIALS"
            value = "/etc/flrcredentials/gcloud-creds.json"
          }

          volume_mount {
            mount_path = "/etc/flrcredentials"
            name       = "flrcredentials"
            read_only  = true
          }

          env {
            name  = "ENVIRONMENT"
            value = var.env
          }

          resources {
            limits = {
              memory = "500Mi"
            }
            requests = {
              memory = "100Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 9000
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }

          readiness_probe {
            http_get {
              path = "/readiness"
              port = 9000
            }

            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 5
          }
        }

        volume {
          name = "flrcredentials"
          secret {
            secret_name = "credentials"
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
  ## TODO create the database table and user credentials
  depends_on = [
    kubernetes_secret.api_database_credentials
  ]
}

# Configure database

resource "kubernetes_secret" "api_database_credentials" {
  metadata {
    name      = "api-database-credentials"
    namespace = var.env
  }

  data = {
    username          = "username"
    password          = "password"
    host              = data.aws_db_instance.api_db.address
    port              = data.aws_db_instance.api_db.port
    database          = local.database_name
    connection_string = "jdbc:postgresql://${data.aws_db_instance.api_db.address}:${data.aws_db_instance.api_db.port}/${local.database_name}"
  }
}

# Secret key base powers encryption at rest for the database

resource "random_password" "application_secret" {
  length  = 64
  special = true
}

resource "kubernetes_secret" "application-secret" {
  metadata {
    name      = "application-secret"
    namespace = var.env
  }

  data = {
    application_secret = random_password.application_secret.result
  }
}

resource "random_password" "elasticsearch_password" {
  length  = 64
  special = true
}

resource "random_password" "truststore_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "elasticsearch_credentials" {
  metadata {
    name      = "elasticsearch-credentials"
    namespace = var.env
  }

  data = {
    password   = random_password.elasticsearch_password.result
    truststore = random_password.truststore_password.result
  }
}