# Required for horizontal pod autoscaling to work
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = "3.8.2"
}

// Shared between elasticsearch and monitoring module
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

module "elasticsearch" {
  source = "./elasticsearch"
}

resource "kubernetes_ingress_v1" "ingress" {
  metadata {
    name      = "monitoring-ingress"
    namespace = "monitoring"

    annotations = {
      "kubernetes.io/ingress.class"             = "nginx"
      "nginx.ingress.kubernetes.io/enable-cors" = "true"
    }
  }

  spec {
    rule {
      host = "logs.fluentlabs.io"
      http {
        path {
          backend {
            service {
              name = "kibana-kb-http"
              port {
                number = 5601
              }
            }
          }
        }
      }
    }
  }
}

# Logging configuration
# Every node has a log collection agent that posts logs to elasticsearch

# resource "helm_release" "sematext_logagent" {
#   name       = "sematext"
#   repository = "https://cdn.sematext.com/helm-charts"
#   chart      = "sematext-agent"
#   version    = "1.0.46"

#   set {
#     name  = "region"
#     value = "US"
#   }

#   set_sensitive {
#     name  = "infraToken"
#     value = var.sematext_index_name
#   }
# }

# Monitoring from Prometheus

# resource "helm_release" "prometheus_operator" {
#   name       = "prometheus"
#   repository = "https://charts.bitnami.com/bitnami"
#   chart      = "kube-prometheus"
#   version    = "3.3.2"
# }

# resource "kubernetes_manifest" "api_prometheus" {
#   provider = kubernetes-alpha
#   manifest = yamldecode(file("${path.module}/api_prometheus.yml"))

#   depends_on = [helm_release.prometheus_operator]
# }