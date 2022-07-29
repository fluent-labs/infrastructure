terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.21.0"
    }
  }
}

# Elasticsearch installation

resource "helm_release" "elasticsearch" {
  name       = "elastic-operator"
  repository = "https://helm.elastic.co"
  chart      = "eck-operator"
  version    = "2.3.0"
}

resource "kubernetes_manifest" "elasticsearch" {
  manifest = yamldecode(file("${path.module}/elasticsearch.yml"))

  depends_on = [helm_release.elasticsearch]
}

resource "kubernetes_manifest" "kibana" {
  manifest = yamldecode(file("${path.module}/kibana.yml"))

  depends_on = [helm_release.elasticsearch]
}

# Role configuration can be file based

resource "kubernetes_secret" "elasticsearch_roles" {
  metadata {
    name = "elasticsearch-roles"
  }

  data = {
    "roles.yml" = file("${path.module}/elastic_roles.yml")
  }
}

// Configure elasticsearch after it's been created
// In the same way that we provision kubernetes and then configure it in a submodule
// This way we can guarantee that it's been created before we try to use it.
module "elasticsearch_config" {
  source = "./elasticsearch_config"

  depends_on = [kubernetes_manifest.elasticsearch, kubernetes_manifest.kibana]
}

# Backups in S3

# resource "aws_s3_bucket" "backup" {
#   bucket = "fluentlabs-elasticsearch-backups"
#   acl    = "private"
# }

# # S3 Credentials for Elasticsearch

# resource "aws_iam_access_key" "elasticsearch" {
#   user = aws_iam_user.elasticsearch.name
# }

# resource "aws_iam_user" "elasticsearch" {
#   name = "elasticsearch"
# }

# data "aws_iam_policy_document" "elasticsearch_backup" {
#   statement {
#     actions   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketMultipartUploads", "s3:ListBucketVersions"]
#     effect    = "Allow"
#     resources = [aws_s3_bucket.backup.arn]
#   }
#   statement {
#     actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts"]
#     effect    = "Allow"
#     resources = ["${aws_s3_bucket.backup.arn}/*"]
#   }
# }

# resource "aws_iam_policy" "elasticsearch_backup" {
#   name        = "elasticsearch-backup-role"
#   description = "IAM policy to let elasticsearch backup documents to S3"

#   policy = data.aws_iam_policy_document.elasticsearch_backup.json
# }

# resource "aws_iam_policy_attachment" "elasticsearch_backup" {
#   name       = "elasticsearch-backup-role-attach"
#   users      = [aws_iam_user.elasticsearch.name]
#   policy_arn = aws_iam_policy.elasticsearch_backup.arn
# }

# resource "kubernetes_secret" "elasticsearch_aws_credentials" {
#   metadata {
#     name = "elasticsearch-s3-creds"
#   }

#   data = {
#     "s3.client.default.access_key" = aws_iam_access_key.elasticsearch.id
#     "s3.client.default.secret_key" = aws_iam_access_key.elasticsearch.secret
#   }
# }
