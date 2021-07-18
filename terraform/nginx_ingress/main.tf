terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.10.1"
    }
  }
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://helm.nginx.com/stable"
  chart      = "nginx-ingress"
  version    = "0.7.1"
  namespace  = var.namespace
  values     = [file("${path.module}/nginx_ingress.yml")]
}

# Use this to get the load balancer external IP for DNS configuration
data "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-ingress-nginx-ingress"
    namespace = var.namespace
  }
  depends_on = [helm_release.nginx_ingress]
}

resource "kubernetes_secret" "nginx_certificate" {
  metadata {
    name      = "nginx-certificate"
    namespace = var.namespace
  }

  data = {
    "tls.key" = var.private_key_pem
    "tls.crt" = <<EOF
${var.certificate_pem}
${var.issuer_pem}
EOF
  }

  type = "kubernetes.io/tls"
}

# DNS to route to cluster
# TODO figure out what the output of the kubernetes service looks like
resource "digitalocean_record" "kubernetes_subdomain_dns" {
  for_each = toset(var.subdomains)
  domain   = var.domain
  type     = "A"
  name     = each.value
  value    = data.kubernetes_service.nginx.status.0.load_balancer.0.ingress.0.ip

  lifecycle {
    ignore_changes = [
      value,
    ]
  }
}

resource "kubernetes_ingress" "ingress" {
  metadata {
    name = "fluentlabs-ingress"
    annotations = {
      "kubernetes.io/ingress.class"             = "nginx"
      "nginx.ingress.kubernetes.io/enable-cors" = "true"
    }
  }

  spec {
    tls {
      hosts       = ["api.fluentlabs.io"]
      secret_name = "nginx-certificate"
    }

    rule {
      host = "api.fluentlabs.io"
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