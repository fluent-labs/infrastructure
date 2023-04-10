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
      version = "2.21.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.10.0"
    }
  }
}

variable "digitalocean_token" {}

provider "digitalocean" {
  token = var.digitalocean_token
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

provider "aws" {
  region = "us-west-2"
}

variable "sematext_index_name" {}

module "infrastructure" {
  source              = "./terraform"
  # cluster_name        = digitalocean_kubernetes_cluster.prod.name
  cluster_name        = "prod"
  digitalocean_token  = var.digitalocean_token
  sematext_index_name = var.sematext_index_name
}

# Held here so that Helm and K8s providers can be initialized to work on this cluster
# data "digitalocean_kubernetes_versions" "kubernetes_1_24" {
#   version_prefix = "1.24."
# }

# resource "digitalocean_kubernetes_cluster" "prod" {
#   name         = "prod"
#   region       = "lon1"
#   auto_upgrade = true
#   version      = data.digitalocean_kubernetes_versions.kubernetes_1_24.latest_version

#   maintenance_policy {
#     start_time = "04:00"
#     day        = "sunday"
#   }

#   node_pool {
#     name       = "default"
#     size       = "s-4vcpu-8gb"
#     auto_scale = true
#     min_nodes  = 1
#     max_nodes  = 5
#   }
# }
