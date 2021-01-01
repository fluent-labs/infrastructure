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