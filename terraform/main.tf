terraform {
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

# Hold K8s configuration in an intermediate level
# Terraform currently cannot create a cluster and use it to set up a provider on the same leve.

data "digitalocean_kubernetes_cluster" "foreign_language_reader" {
  name = var.cluster_name
}

provider "kubernetes" {
  load_config_file = false
  host             = data.digitalocean_kubernetes_cluster.foreign_language_reader.endpoint
  token            = data.digitalocean_kubernetes_cluster.foreign_language_reader.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.foreign_language_reader.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = data.digitalocean_kubernetes_cluster.foreign_language_reader.endpoint
    token = data.digitalocean_kubernetes_cluster.foreign_language_reader.kube_config[0].token
    cluster_ca_certificate = base64decode(
      data.digitalocean_kubernetes_cluster.foreign_language_reader.kube_config[0].cluster_ca_certificate
    )
  }
}

# Service container registries
module "container_registries" {
  source = "./container_registries"
}

# Mysql database to store user context.
# module "database" {
#   source       = "./database"
#   cluster_name = var.cluster_name
#   node_count   = 1
#   size         = "db-s-1vcpu-1gb"
# }

# Static content served to users

# module "frontend" {
#   source       = "./static_bucket"
#   domain       = digitalocean_domain.main.name
#   subdomain    = "www"
#   deploy_users = [aws_iam_user.github.name]
# }

# module "storybook" {
#   source       = "./static_bucket"
#   domain       = digitalocean_domain.main.name
#   subdomain    = "storybook"
#   deploy_users = [aws_iam_user.github.name]
# }

# QA environment

resource "kubernetes_namespace" "qa" {
  metadata {
    annotations = {
      name = "qa"
    }

    name = "qa"
  }
}

# module "api_qa" {
#   source        = "./api"
#   cluster_name  = var.cluster_name
#   database_name = module.database.database_name
#   env           = "qa"
#   min_replicas  = 1
#   max_replicas  = 1
# }

# Production environment

resource "kubernetes_namespace" "prod" {
  metadata {
    annotations = {
      name = "prod"
    }

    name = "prod"
  }
}

module "api" {
  source       = "./api"
  cluster_name = var.cluster_name
  env          = "prod"
  min_replicas = 1
  max_replicas = 10
}

# Content infrastructure
# Spark jobs that scrape wiktionary for definitions
# Should also have job triggers
# And potentially example sentences in the future

module "content" {
  source = "./content"
}

# Contains logging and monitoring configuration
module "monitoring" {
  source = "./monitoring"
}

# Ingress
# Handles traffic going in to the cluster
# Proxies everything through a load balancer and nginx

module "nginx_ingress_prod" {
  source          = "./nginx_ingress"
  domain          = digitalocean_domain.main.name
  subdomains      = ["api"]
  private_key_pem = acme_certificate.certificate.private_key_pem
  certificate_pem = acme_certificate.certificate.certificate_pem
  issuer_pem      = acme_certificate.certificate.issuer_pem
  namespace       = "prod"
}

resource "kubernetes_ingress" "prod_ingress" {
  metadata {
    name = "foreign-language-reader-ingress"
    annotations = {
      "kubernetes.io/ingress.class"             = "nginx"
      "nginx.ingress.kubernetes.io/enable-cors" = "true"
    }
    namespace = "prod"
  }

  spec {
    tls {
      secret_name = "nginx-certificate"
    }

    rule {
      host = "api.foreignlanguagereader.com"
      http {
        path {
          backend {
            service_name = "api"
            service_port = 9000
          }
        }
      }
    }
  }
}


# Shared resources for the cluster go down here.

resource "digitalocean_domain" "main" {
  name = "foreignlanguagereader.com"
}

# TLS

resource "tls_private_key" "tls_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.tls_private_key.private_key_pem
  email_address   = "letsencrypt@lucaskjaerozhang.com"
}

resource "acme_certificate" "certificate" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "*.foreignlanguagereader.com"

  dns_challenge {
    provider = "digitalocean"
    config = {
      DO_AUTH_TOKEN          = var.digitalocean_token
      DO_HTTP_TIMEOUT        = 60
      DO_POLLING_INTERVAL    = 30
      DO_PROPAGATION_TIMEOUT = 600
    }
  }
}
