terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
  }
}

# Container registries for use in this app.

# module "api_registry" {
#   source      = "./container_registry"
#   name        = "foreign-language-reader-api"
#   image_count = 5
#   push_users  = var.push_users
#   pull_users  = [aws_iam_user.kubernetes.name]
# }

resource "digitalocean_container_registry" "api_registry" {
  name                   = "foreign-language-reader-api"
  subscription_tier_slug = "starter"
}

# module "content_jobs" {
#   source      = "./container_registry"
#   name        = "foreign-language-reader-content-jobs"
#   image_count = 10
#   push_users  = var.push_users
#   pull_users  = [aws_iam_user.kubernetes.name]
# }

# module "language_service_registry" {
#   source      = "./container_registry"
#   name        = "foreign-language-reader-language-service"
#   image_count = 5
#   push_users  = var.push_users
#   pull_users  = [aws_iam_user.kubernetes.name]
# }

# ECR credentials
# Used to be able to pull images from ECR
# Sadly is namespaced so will need two configurations.

resource "helm_release" "ecr_cred_refresher_default" {
  for_each = toset(var.kubernetes_namespaces)

  name       = "ecr-cred-refresher-${each.value}"
  repository = "https://architectminds.github.io/helm-charts/"
  chart      = "aws-ecr-credential"
  version    = "1.4.2"

  set_sensitive {
    name  = "aws.account"
    value = data.aws_caller_identity.current.account_id
  }
  set {
    name  = "aws.region"
    value = "us-west-2"
  }
  set_sensitive {
    name  = "aws.accessKeyId"
    value = base64encode(aws_iam_access_key.kubernetes.id)
  }
  set_sensitive {
    name  = "aws.secretAccessKey"
    value = base64encode(aws_iam_access_key.kubernetes.secret)
  }
  set {
    name  = "targetNamespace"
    value = each.value
  }
}
