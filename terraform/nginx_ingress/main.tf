resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes-charts.storage.googleapis.com/"
  chart      = "nginx-ingress"
  version    = "1.33.0"
}

# Use this to get the load balancer external IP for DNS configuration
data "kubernetes_service" "nginx" {
  metadata {
    name = "nginx-ingress-controller"
  }
  depends_on = [helm_release.nginx_ingress]
}

resource "kubernetes_secret" "nginx_certificate" {
  metadata {
    name = "nginx-certificate"
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
  value    = data.kubernetes_service.nginx.load_balancer_ingress.0.ip

  lifecycle {
    ignore_changes = [
      value,
    ]
  }
}
