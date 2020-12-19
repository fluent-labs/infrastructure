# Required for horizontal pod autoscaling to work
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-charts.storage.googleapis.com"
  chart      = "metrics-server"
  version    = "2.10.1"
}

# Logging configuration
# Every node has a log collection agent that posts logs to elasticsearch

resource "kubernetes_namespace" "logging" {
  metadata {
    annotations = {
      name = "logging"
    }

    name = "logging"
  }
}

resource "random_password" "fluent_elasticsearch_password" {
  length      = 32
  special     = false
  min_numeric = 10
}

resource "helm_release" "fluentd_elasticsearch" {
  name       = "fluentd"
  repository = "https://kiwigrid.github.io"
  chart      = "fluentd-elasticsearch"
  version    = "6.2.2"
  namespace  = "logging"

  values = [file("${path.module}/fluentd.yml")]

  set_sensitive {
    name  = "elasticsearch.auth.password"
    value = random_password.fluent_elasticsearch_password.result
  }

  depends_on = [
    kubernetes_namespace.logging
  ]
}
