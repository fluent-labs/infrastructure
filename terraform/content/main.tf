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

resource "aws_s3_bucket" "definitions" {
  bucket = "foreign-language-reader-definitions"
  acl    = "private"
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