# Elasticsearch config

resource "helm_release" "elasticsearch" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "1.0.5"
  namespace  = "content"
}

resource "kubernetes_secret" "elasticsearch_roles" {
  metadata {
    name      = "elasticsearch-roles"
    namespace = "content"
  }

  data = {
    "roles.yml" = file("${path.module}/elastic_roles.yml")
  }
}