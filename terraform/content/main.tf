# Content jobs runtime
# Content requires long running jobs that could be split into parallel
# This is a good use case for spark.

# Spark config

resource "helm_release" "spark" {
  name       = "spark"
  repository = "https://googlecloudplatform.github.io/spark-on-k8s-operator"
  chart      = "spark-operator"
  version    = "1.0.5"
  values     = [file("${path.module}/spark.yml")]
}

# Content buckets for spark to read

resource "aws_s3_bucket" "content" {
  bucket = "foreign-language-reader-content"
  acl    = "private"
}

# S3 Credentials for Spark

resource "aws_iam_access_key" "spark" {
  user = aws_iam_user.spark.name
}

resource "aws_iam_user" "spark" {
  name = "spark"
}

data "aws_iam_policy_document" "spark_read" {
  statement {
    actions   = ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.content.arn}/*"]
  }
}

resource "aws_iam_policy" "spark_read" {
  name        = "spark-read-role"
  description = "IAM policy to let spark read from content uploaded to S3"

  policy = data.aws_iam_policy_document.spark_read.json
}

resource "aws_iam_policy_attachment" "spark_read" {
  name       = "spark-read-role-attach"
  users      = [aws_iam_user.spark.name]
  policy_arn = aws_iam_policy.spark_read.arn
}

# S3 Deploy credentials

resource "aws_iam_access_key" "github" {
  user = aws_iam_user.github.name
}

resource "aws_iam_user" "github" {
  name = "github-spark-deploy"
}

data "aws_iam_policy_document" "spark_deploy" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObjectAcl", "s3:GetObject", "s3:ListBucketMultipartUploads", "s3:AbortMultipartUpload", "s3:ListBucket", "s3:DeleteObject", "s3:GetBucketLocation", "s3:PutObjectAcl", "s3:ListMultipartUploadParts"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.content.arn}/*"]
  }
}

resource "aws_iam_policy" "deploy" {
  name        = "spark-deploy-role"
  description = "IAM policy for deploying to spark"

  policy = data.aws_iam_policy_document.spark_deploy.json
}

resource "aws_iam_policy_attachment" "deploy" {
  name       = "spark-deploy-role-attach"
  users      = [aws_iam_user.github.name]
  policy_arn = aws_iam_policy.deploy.arn
}

# Configuration variables for all spark jobs

resource "random_password" "truststore_password" {
  length  = 32
  special = false
}

resource "random_password" "elasticsearch_password" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "spark_config" {
  metadata {
    name = "spark-config"
  }

  data = {
    "AWS_ACCESS_KEY_ID"     = aws_iam_access_key.spark.id
    "AWS_SECRET_ACCESS_KEY" = aws_iam_access_key.spark.secret
    "es_truststore"         = random_password.truststore_password.result
    "es_user"               = "spark"
    "es_password"           = random_password.elasticsearch_password.result
  }
}

# Data pipeline orchestration

resource "kubernetes_deployment" "example" {
  metadata {
    name = "prefect-agent"
    labels = {
      app = "prefect-agent"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prefect-agent"
      }
    }

    template {
      metadata {
        labels = {
          app = "prefect-agent"
        }
      }

      spec {
        container {
          name              = "agent"
          image             = "prefecthq/prefect:0.14.2-python3.6"
          image_pull_policy = "Always"
          args              = ["prefect agent kubernetes start"]
          command           = ["/bin/bash", "-c"]

          env {
            name = "PREFECT__CLOUD__AGENT__AUTH_TOKEN"
            value_from {
              secret_key_ref {
                name = "prefect-auth"
                key  = "token"
              }
            }
          }

          env {
            name  = "PREFECT__CLOUD__API"
            value = "https://api.prefect.io"
          }

          env {
            name  = "NAMESPACE"
            value = "default"
          }

          env {
            name  = "IMAGE_PULL_SECRETS"
            value = "regcred"
          }

          env {
            name  = "PREFECT__CLOUD__AGENT__LABELS"
            value = "[]"
          }

          env {
            name  = "JOB_MEM_REQUEST"
            value = "100Mi"
          }

          env {
            name  = "JOB_MEM_LIMIT"
            value = "500Mi"
          }

          env {
            name  = "JOB_CPU_REQUEST"
            value = "250m"
          }

          env {
            name  = "JOB_CPU_LIMIT"
            value = "500m"
          }

          env {
            name  = "IMAGE_PULL_POLICY"
            value = "Always"
          }

          env {
            name  = "SERVICE_ACCOUNT_NAME"
            value = "default"
          }

          env {
            name  = "PREFECT__BACKEND"
            value = "cloud"
          }

          env {
            name  = "PREFECT__CLOUD__AGENT__AGENT_ADDRESS"
            value = "http://:8080"
          }

          resources {
            limits {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 8080
            }

            failure_threshold     = 2
            initial_delay_seconds = 40
            period_seconds        = 40
          }
        }
      }
    }
  }
}

resource "kubernetes_role" "prefect_agent" {
  metadata {
    name = "prefect-agent-rbac"
  }

  rule {
    api_groups = ["batch", "extensions"]
    resources  = ["jobs"]
    verbs      = ["*"]
  }
  rule {
    api_groups = [""]
    resources  = ["events", "pods"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding" "prefect_agent" {
  metadata {
    name      = "prefect-agent-rbac"
    namespace = "default"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "prefect-agent-rbac"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "default"
    api_group = ""
  }
}