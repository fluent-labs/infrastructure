terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.21.0"
    }
  }
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
data "aws_route53_zone" "main" {
  name = var.domain
}

resource "aws_route53_record" "subdomain" {
  for_each = toset(var.subdomains)
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = "${each.value}.fluentlabs.io"
  type     = "CNAME"
  ttl      = "3600"
  records  = [data.kubernetes_service.nginx.status.0.load_balancer.0.ingress.0.hostname]
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