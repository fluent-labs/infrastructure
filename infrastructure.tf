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
      version = "2.10.1"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.5.2"
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
  profile = "default"
  region  = "us-west-2"
}

# Held here so that Helm and K8s providers can be initialized to work on this cluster
resource "digitalocean_kubernetes_cluster" "foreign_language_reader" {
  name    = "foreign-language-reader"
  region  = "sfo2"
  version = "1.19.6-do.0"
  tags    = ["prod"]

  node_pool {
    name       = "worker-pool"
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 5
  }
}


variable "sematext_index_name" {}

module "infrastructure" {
  source              = "./terraform"
  cluster_name        = "fluentlabsprod"
  digitalocean_token  = var.digitalocean_token
  sematext_index_name = var.sematext_index_name
}

module "kubernetes" {
  source = "./terraform/eks"
}