terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
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

# Use this to get the load balancer external IP for DNS configuration
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

# Backups in S3

resource "aws_s3_bucket" "backup" {
  bucket = "foreign-language-reader-elasticsearch-backups"
  acl    = "private"
}

# S3 Credentials for Elasticsearch

resource "aws_iam_access_key" "elasticsearch" {
  user = aws_iam_user.elasticsearch.name
}

resource "aws_iam_user" "elasticsearch" {
  name = "elasticsearch"
}

data "aws_iam_policy_document" "elasticsearch_backup" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObjectAcl", "s3:GetObject", "s3:ListBucketMultipartUploads", "s3:AbortMultipartUpload", "s3:ListBucket", "s3:DeleteObject", "s3:GetBucketLocation", "s3:PutObjectAcl", "s3:ListMultipartUploadParts"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.backup.arn}/*"]
  }
}

resource "aws_iam_policy" "elasticsearch_backup" {
  name        = "elasticsearch-backup-role"
  description = "IAM policy to let elasticsearch backup documents to S3"

  policy = data.aws_iam_policy_document.elasticsearch_backup.json
}

resource "aws_iam_policy_attachment" "elasticsearch_backup" {
  name       = "elasticsearch-backup-role-attach"
  users      = [aws_iam_user.elasticsearch.name]
  policy_arn = aws_iam_policy.elasticsearch_backup.arn
}

resource "kubernetes_secret" "elasticsearch_aws_credentials" {
  metadata {
    name = "elasticsearch-s3-creds"
  }

  data = {
    "s3.client.default.access_key" = aws_iam_access_key.elasticsearch.id
    "s3.client.default.secret_key" = aws_iam_access_key.elasticsearch.secret
  }
}

# Backup configuration

resource elasticsearch_snapshot_repository "backups" {
  name     = "S3-backup"
  type     = "s3"
  settings = {
    "bucket" = aws_s3_bucket.backup.id
  }
}