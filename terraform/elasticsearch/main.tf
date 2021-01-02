terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.3.0"
    }
    elasticsearch = {
      source  = "disaster37/elasticsearch"
      version = "7.0.4"
    }
  }
}

# Elasticsearch installation

resource "helm_release" "elasticsearch" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "1.3.1"
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

# Users and roles

data "kubernetes_secret" "elastic_user" {
  metadata {
    name = "elastic-es-elastic-user"
  }
}

provider "elasticsearch" {
  urls     = "https://elastic.foreignlanguagereader.com:9200"
  username = "elastic"
  password = data.kubernetes_secret.elastic_user.data.elastic
}

resource "kubernetes_secret" "elasticsearch_roles" {
  metadata {
    name = "elasticsearch-roles"
  }

  data = {
    "roles.yml" = file("${path.module}/elastic_roles.yml")
  }
}

resource "elasticsearch_user" "api" {
  username  = "apiprod"
  enabled   = "true"
  email     = "apiprod@foreignlanguagereader.com"
  full_name = "api prod"
  password  = var.api_password
  roles     = ["api_prod"]
}

resource "elasticsearch_user" "fluentd" {
  username  = "fluentd"
  enabled   = "true"
  email     = "fluentd@foreignlanguagereader.com"
  full_name = "fluentd"
  password  = var.fluentd_password
  roles     = ["fluentd"]
}

resource "elasticsearch_user" "spark" {
  username  = "spark"
  enabled   = "true"
  email     = "spark@foreignlanguagereader.com"
  full_name = "spark"
  password  = var.spark_password
  roles     = ["spark"]
}

# Domains for services

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
    actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads", "s3:ListBucketVersions"]
    effect    = "Allow"
    resources = [aws_s3_bucket.backup.arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
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

resource "elasticsearch_snapshot_repository" "backups" {
  name = "S3-backup"
  type = "s3"
  settings = {
    "bucket" = aws_s3_bucket.backup.id
  }
}

resource "elasticsearch_snapshot_lifecycle_policy" "daily_backup" {
  name          = "daily-snapshots"
  snapshot_name = "backup"
  schedule      = "0 30 1 * * ?"
  repository    = elasticsearch_snapshot_repository.backups.name
  configs       = <<EOF
{
    "partial": true,
}
EOF
  retention     = <<EOF
{
    "expire_after": "120d"
}
EOF
}

# Automated log rollover
resource "elasticsearch_index_lifecycle_policy" "rollover" {
  name   = "logging-rollover"
  policy = <<EOF
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_size": "50gb",
            "max_age": "30d"
          }
        }
      },
      "delete": {
        "min_age": "60d",
        "actions": {
          "wait_for_snapshot": {
            "policy": "daily-snapshots"
          }
        }
      }
    }
  }
}
EOF

  depends_on = [elasticsearch_snapshot_lifecycle_policy.daily_backup]
}

resource "elasticsearch_index_template" "fluentd" {
  name     = "fluentd"
  template = <<EOF
{
  "index_patterns": [
    "logstash-*"
  ],
  "settings": {
    "index.lifecycle.name": "logging-rollover",
    "index.lifecycle.rollover_alias": "logstash-backup-alias"
  }
}
EOF

  depends_on = [elasticsearch_index_lifecycle_policy.rollover]
}