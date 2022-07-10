terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.21.0"
    }
    acme = {
      source  = "vancluever/acme"
      version = "2.10.0"
    }
    kubernetes-alpha = {
      source  = "hashicorp/kubernetes-alpha"
      version = "0.6.0"
    }
  }
}

# Certificate manager certificates need to be in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Hold K8s configuration in an intermediate level
# Terraform currently cannot create a cluster and use it to set up a provider on the same level.
data "digitalocean_kubernetes_cluster" "prod" {
  name = var.cluster_name
}

provider "kubernetes" {
  host  = data.digitalocean_kubernetes_cluster.prod.endpoint
  token = data.digitalocean_kubernetes_cluster.prod.kube_config[0].token
  cluster_ca_certificate = base64decode(
    data.digitalocean_kubernetes_cluster.prod.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = data.digitalocean_kubernetes_cluster.prod.endpoint
    token = data.digitalocean_kubernetes_cluster.prod.kube_config[0].token
    cluster_ca_certificate = base64decode(
      data.digitalocean_kubernetes_cluster.prod.kube_config[0].cluster_ca_certificate
    )
  }
}

# Mysql database to store user context.
# module "database" {
#   source       = "./database"
#   cluster_name = var.cluster_name
#   node_count   = 1
#   size         = "db-s-1vcpu-1gb"
#   subnet_ids   = var.subnet_ids
# }

# Static content served to users

module "frontend_fluent_labs" {
  source          = "./static_bucket"
  domain          = aws_route53_zone.main.name
  subdomain       = "www"
  deploy_users    = [aws_iam_user.github.name]
  certificate_arn = aws_acm_certificate.cert.arn
}

module "frontend_preprod_fluent_labs" {
  source          = "./static_bucket"
  domain          = aws_route53_zone.main.name
  subdomain       = "preprod"
  deploy_users    = [aws_iam_user.github.name]
  certificate_arn = aws_acm_certificate.cert.arn
}

# module "api" {
#   source        = "./api"
#   cluster_name  = var.cluster_name
#   database_name = module.database.database_name
#   env           = "default"
#   min_replicas  = 1
#   max_replicas  = 10
# }

# module "language_service" {
#   source       = "./language_service"
#   cluster_name = var.cluster_name
#   env          = "default"
#   min_replicas = 1
#   max_replicas = 10
# }

# Content infrastructure
# Spark jobs that scrape wiktionary for definitions
# Should also have job triggers
# And potentially example sentences in the future

module "content" {
  source = "./content"
}

# module "elasticsearch" {
#   source           = "./elasticsearch"
#   domain           = digitalocean_domain.fluentlabs.name
#   api_password     = module.api.elasticsearch_password
#   fluentd_password = module.monitoring.fluentd_password
#   spark_password   = module.content.elasticsearch_password
# }

# Contains logging and monitoring configuration
module "monitoring" {
  source              = "./monitoring"
  sematext_index_name = var.sematext_index_name
}

# Workflow orchestration
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://raw.githubusercontent.com/jenkinsci/kubernetes-operator/master/chart"
  chart      = "jenkins-operator"
  version    = "0.6.2"
}

# Note - this will fail plans until the helm release is installed. Fun times.
# resource "kubernetes_manifest" "jenkins" {
#   manifest = yamldecode(file("${path.module}/jenkins.yml"))

#   depends_on = [helm_release.jenkins]
# }

# Ingress
# Handles traffic going in to the cluster
# Proxies everything through a load balancer and nginx

module "nginx_ingress" {
  source          = "./nginx_ingress"
  domain          = aws_route53_zone.main.name
  subdomains      = ["api"]
  private_key_pem = acme_certificate.certificate_fluent_labs.private_key_pem
  certificate_pem = acme_certificate.certificate_fluent_labs.certificate_pem
  issuer_pem      = acme_certificate.certificate_fluent_labs.issuer_pem
  namespace       = "default"
}


# Shared resources for the cluster go down here.

resource "aws_route53_zone" "main" {
  name = "fluentlabs.io"
}

# Frontend deploy user
resource "aws_iam_access_key" "github" {
  user = aws_iam_user.github.name
}

resource "aws_iam_user" "github" {
  name = "foreign-language-reader-github"
}

# TLS

resource "tls_private_key" "tls_private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.tls_private_key.private_key_pem
  email_address   = "letsencrypt@lucaskjaerozhang.com"
}

resource "acme_certificate" "certificate_fluent_labs" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "*.fluentlabs.io"

  dns_challenge {
    provider = "route53"
  }
}

resource "aws_acm_certificate" "cert" {
  provider          = aws.us_east_1
  private_key       = acme_certificate.certificate_fluent_labs.private_key_pem
  certificate_body  = acme_certificate.certificate_fluent_labs.certificate_pem
  certificate_chain = acme_certificate.certificate_fluent_labs.issuer_pem

  lifecycle {
    create_before_destroy = true
  }
}