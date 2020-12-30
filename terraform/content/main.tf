# Content jobs runtime
# Content requires long running jobs that could be split into parallel
# This is a good use case for spark.

resource "kubernetes_namespace" "content" {
  metadata {
    annotations = {
      name = "content"
    }

    name = "content"
  }
}

resource "helm_release" "spark" {
  name       = "spark"
  repository = "https://googlecloudplatform.github.io/spark-on-k8s-operator"
  chart      = "spark-operator"
  version    = "1.0.5"
  namespace  = "content"
  values     = [file("${path.module}/spark.yml")]

  depends_on = [
    kubernetes_namespace.content
  ]
}

# Content buckets for spark to read

resource "aws_s3_bucket" "content" {
  bucket = "foreign-language-reader-content"
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

# Configuration variables for all spark jobs

resource "random_password" "truststore_password" {
  length  = 32
  special = false
}

resource "random_password" "elasticsearch_password" {
  length  = 64
  special = false
}

resource "kubernetes_secret" "spark_config" {
  metadata {
    name      = "spark-config"
    namespace = "content"
  }

  data = {
    "AWS_ACCESS_KEY_ID"     = "${aws_iam_access_key.spark.id}"
    "AWS_SECRET_ACCESS_KEY" = "${aws_iam_access_key.spark.secret}"
    "es_truststore"         = "${random_password.truststore_password.result}"
    "es_user"               = "spark"
    "es_password"           = "${random_password.elasticsearch_password.result}"
  }
}