terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
  }
}

resource "digitalocean_container_registry" "api_registry" {
  name                   = "foreign-language-reader"
  subscription_tier_slug = "basic"
}

resource "digitalocean_container_registry_docker_credentials" "api" {
  registry_name = digitalocean_container_registry.api_registry.name
}

resource "kubernetes_secret" "registry" {
  metadata {
    name = "docker-cfg"
  }

  data = {
    ".dockerconfigjson" = digitalocean_container_registry_docker_credentials.api.docker_credentials
  }

  type = "kubernetes.io/dockerconfigjson"
}