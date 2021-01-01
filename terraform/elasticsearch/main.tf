# Elasticsearch config

resource "helm_release" "elasticsearch" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "1.0.5"
}

resource "kubernetes_secret" "elasticsearch_roles" {
  metadata {
    name = "elasticsearch-roles"
  }

  data = {
    "roles.yml" = file("${path.module}/elastic_roles.yml")
  }
}

resource "kubernetes_manifest" "elasticsearch" {
  provider = kubernetes-alpha
  manifest = yamldecode(file("${path.module}/elasticsearch.yml"))
}

resource "kubernetes_manifest" "kibana" {
  provider = kubernetes-alpha
  manifest = yamldecode(file("${path.module}/kibana.yml"))
}