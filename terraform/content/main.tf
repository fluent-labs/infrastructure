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
  chart      = "sparkoperator"
  version    = "1.0.5"
  namespace  = "content"

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

resource "kubernetes_secret" "spark_s3_creds" {
  metadata {
    name      = "spark-s3-creds"
    namespace = "content"
  }

  data = {
    access_key = aws_iam_access_key.spark.id
    secret_key = aws_iam_access_key.spark.secret
  }

  depends_on = [
    kubernetes_namespace.content
  ]
}
# resource "helm_release" "zeppelin" {
#   name       = "zeppelin"
#   repository = "https://kubernetes-charts.storage.googleapis.com"
#   chart      = "zeppelin"
#   version    = "1.1.1"
#   namespace  = "content"

#   depends_on = [
#     kubernetes_namespace.content
#   ]
# }