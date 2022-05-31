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
      version = "2.14.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.9.0"
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

variable "sematext_index_name" {}

module "infrastructure" {
  source              = "./terraform"
  cluster_name        = "fluentlabsprod"
  digitalocean_token  = var.digitalocean_token
  sematext_index_name = var.sematext_index_name
  subnet_ids          = module.kubernetes.subnet_ids
}

# Held here so that Helm and K8s providers can be initialized to work on this cluster
module "kubernetes" {
  source = "./terraform/eks"
}