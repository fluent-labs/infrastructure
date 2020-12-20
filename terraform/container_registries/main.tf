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