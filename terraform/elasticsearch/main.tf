terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
    elasticsearch = {
      source  = "disaster37/elasticsearch"
      version = "7.0.4"
    }
  }
}

# Elasticsearch config

resource "helm_release" "elasticsearch" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "1.3.1"
}

resource "kubernetes_secret" "elasticsearch_roles" {
  metadata {
    name = "elasticsearch-roles"
  }

  data = {
    "roles.yml" = file("${path.module}/elastic_roles.yml")
  }
}

resource "elasticsearch_user" "fluentd" {
  username  = "fluentd"
  enabled   = "true"
  email     = "fluentd@foreignlanguagereader.com"
  full_name = "fluentd"
  password  = var.fluentd_password
  roles     = ["fluentd"]
}

// Cannot install through terraform until ECK 1.4
// Manually configure until then

# resource "kubernetes_manifest" "elasticsearch" {
#   provider = kubernetes-alpha
#   manifest = yamldecode(file("${path.module}/elasticsearch.yml"))

#   depends_on = [helm_release.elasticsearch]
# }

# resource "kubernetes_manifest" "kibana" {
#   provider = kubernetes-alpha
#   manifest = yamldecode(file("${path.module}/kibana.yml"))

#   depends_on = [helm_release.elasticsearch]
# }

# Domains for services

data "kubernetes_service" "elastic" {
  metadata {
    name      = "elastic-es-http"
    namespace = "default"
  }
}

resource "digitalocean_record" "elastic_subdomain_dns" {
  domain = var.domain
  type   = "A"
  name   = "elastic"
  value  = data.kubernetes_service.elastic.load_balancer_ingress.0.ip

  lifecycle {
    ignore_changes = [
      value,
    ]
  }
}

data "kubernetes_service" "kibana" {
  metadata {
    name      = "kibana-kb-http"
    namespace = "default"
  }
}

resource "digitalocean_record" "kibana_subdomain_dns" {
  domain = var.domain
  type   = "A"
  name   = "kibana"
  value  = data.kubernetes_service.kibana.load_balancer_ingress.0.ip

  lifecycle {
    ignore_changes = [
      value,
    ]
  }
}