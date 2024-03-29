terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.21.0"
    }
  }
}

locals {
  certificate_namespaces = concat([var.namespace], var.additional_certificate_namespaces)
}

resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://helm.nginx.com/stable"
  chart      = "nginx-ingress"
  version    = "0.13.1"
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
  for_each = toset(local.certificate_namespaces)
  metadata {
    name      = "nginx-certificate"
    namespace = each.value
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
data "aws_route53_zone" "main" {
  name = var.domain
}

resource "aws_route53_record" "subdomain" {
  for_each = toset(var.subdomains)
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "${each.value}.fluentlabs.io"
  type     = "A"
  ttl      = "3600"
  records  = [data.kubernetes_service.nginx.status.0.load_balancer.0.ingress.0.ip]
}

resource "kubernetes_ingress_v1" "ingress" {
  metadata {
    name = "fluentlabs-ingress"
    annotations = {
      "kubernetes.io/ingress.class"             = "nginx"
      "nginx.ingress.kubernetes.io/enable-cors" = "true"
    }
  }

  spec {
    tls {
      hosts       = ["api.fluentlabs.io", "jobs.fluentlabs.io"]
      secret_name = "nginx-certificate"
    }

    rule {
      host = "api.fluentlabs.io"
      http {
        path {
          backend {
            service {
              name = "api"
              port {
                number = 9000
              }
            }
          }
        }
      }
    }

    rule {
      host = "jobs.fluentlabs.io"
      http {
        path {
          backend {
            service {
              name = "jenkins-operator-http-fluentlabs"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}