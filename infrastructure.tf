terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "foreign-language-reader"

    workspaces {
      name = "infrastructure"
    }
  }

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "1.6.3"
    }
  }
}

variable "digitalocean_token" {}

provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

provider "digitalocean" {
  token = var.digitalocean_token
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

# Held here so that Helm and K8s providers can be initialized to work on this cluster
resource "digitalocean_kubernetes_cluster" "foreign_language_reader" {
  name    = "foreign-language-reader"
  region  = "sfo2"
  version = "1.19.3-do.2"
  tags    = ["prod"]

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 3
  }
}

resource "digitalocean_container_registry" "api_registry" {
  name                   = "foreign-language-reader-api"
  subscription_tier_slug = "starter"
}

# module "infrastructure" {
#   source             = "./terraform"
#   cluster_name       = digitalocean_kubernetes_cluster.foreign_language_reader.name
#   digitalocean_token = var.digitalocean_token
# }
