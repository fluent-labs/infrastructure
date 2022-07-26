# Content jobs runtime
# Content requires long running jobs that could be split into parallel
# This is a good use case for spark.

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.21.0"
    }
  }
}

# Spark config

resource "kubernetes_namespace" "content" {
  metadata {
    name = "content"
  }
}

resource "helm_release" "spark" {
  name       = "spark"
  namespace  = "content"
  repository = "https://googlecloudplatform.github.io/spark-on-k8s-operator"
  chart      = "spark-operator"
  version    = "1.1.25"
  values     = [file("${path.module}/spark.yml")]
}

# Service user for jenkins to launch content jobs

resource "kubernetes_role" "jenkins" {
  metadata {
    name      = "jenkins-spark-job"
    namespace = "content"
  }

  rule {
    api_groups = ["sparkoperator.k8s.io"]
    resources  = ["sparkapplications"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
}

resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins-spark-job"
    namespace = "content"
  }
}

resource "kubernetes_role_binding" "jenkins" {
  metadata {
    name      = "jenkins-spark-job"
    namespace = "content"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "jenkins-spark-job"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins-spark-job"
    namespace = "default"
  }
}

# DigitalOcean buckets

resource "digitalocean_spaces_bucket" "definitions" {
  name   = "definitions"
  region = "fra1"
  acl    = "private"

  lifecycle_rule {
    enabled                                = true
    abort_incomplete_multipart_upload_days = 1

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      days = 7
    }
  }

  versioning {
    enabled = true
  }
}

# Content buckets for spark to read

resource "aws_s3_bucket" "content" {
  bucket = "fluentlabs-content"
}

resource "aws_s3_bucket_acl" "content_acl" {
  bucket = aws_s3_bucket.content.bucket
  acl    = "private"
}

# S3 Credentials for Spark

resource "aws_iam_access_key" "spark" {
  user = aws_iam_user.spark.name
}

resource "aws_iam_user" "spark" {
  name = "spark"
}

data "aws_iam_policy_document" "spark_read" {
  statement {
    actions   = ["s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.content.arn}/*"]
  }
}

resource "aws_iam_policy" "spark_read" {
  name        = "spark-read-role"
  description = "IAM policy to let spark read from content uploaded to S3"

  policy = data.aws_iam_policy_document.spark_read.json
}

resource "aws_iam_policy_attachment" "spark_read" {
  name       = "spark-read-role-attach"
  users      = [aws_iam_user.spark.name]
  policy_arn = aws_iam_policy.spark_read.arn
}

data "aws_iam_policy_document" "spark_write" {
  statement {
    actions   = ["*"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.content.arn}/*"]
  }
}

resource "aws_iam_policy" "spark_write" {
  name        = "spark-write-role"
  description = "IAM policy to let spark write results from content uploaded to S3"

  policy = data.aws_iam_policy_document.spark_write.json
}

resource "aws_iam_policy_attachment" "spark_write" {
  name       = "spark-write-role-attach"
  users      = [aws_iam_user.spark.name]
  policy_arn = aws_iam_policy.spark_write.arn
}

# S3 Deploy credentials

resource "aws_iam_access_key" "github" {
  user = aws_iam_user.github.name
}

resource "aws_iam_user" "github" {
  name = "github-spark-deploy"
}

data "aws_iam_policy_document" "spark_deploy" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObjectAcl", "s3:GetObject", "s3:ListBucketMultipartUploads", "s3:AbortMultipartUpload", "s3:ListBucket", "s3:DeleteObject", "s3:GetBucketLocation", "s3:PutObjectAcl", "s3:ListMultipartUploadParts"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.content.arn}/*"]
  }
}

resource "aws_iam_policy" "deploy" {
  name        = "spark-deploy-role"
  description = "IAM policy for deploying to spark"

  policy = data.aws_iam_policy_document.spark_deploy.json
}

resource "aws_iam_policy_attachment" "deploy" {
  name       = "spark-deploy-role-attach"
  users      = [aws_iam_user.github.name]
  policy_arn = aws_iam_policy.deploy.arn
}

# Configuration variables for all spark jobs

resource "random_password" "truststore_password" {
  length  = 32
  special = false
}

resource "random_password" "elasticsearch_password" {
  length  = 64
  special = false
}

# resource "kubernetes_secret" "spark_config" {
#   metadata {
#     name = "spark-config"
#   }

#   data = {
#     "AWS_ACCESS_KEY_ID"     = aws_iam_access_key.spark.id
#     "AWS_SECRET_ACCESS_KEY" = aws_iam_access_key.spark.secret
#     "es_truststore"         = random_password.truststore_password.result
#     "es_user"               = "spark"
#     "es_password"           = random_password.elasticsearch_password.result
#   }
# }
