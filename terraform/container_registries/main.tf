terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
  }
}

resource "digitalocean_container_registry" "api_registry" {
  name                   = "foreign-language-reader-api"
  subscription_tier_slug = "starter"
}

 resource "digitalocean_container_registry_docker_credentials" "api" {
  registry_name = digitalocean_container_registry.api_registry.name
}

resource "kubernetes_secret" "api" {
  metadata {
    name = "docker-cfg-api"
  }

  data = {
    ".dockerconfigjson" = digitalocean_container_registry_docker_credentials.api.docker_credentials
  }

  type = "kubernetes.io/dockerconfigjson"
}