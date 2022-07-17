resource "kubernetes_namespace" "jobs" {
  metadata {
    name = "jobs"
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://raw.githubusercontent.com/jenkinsci/kubernetes-operator/master/chart"
  chart      = "jenkins-operator"
  version    = "0.6.2"
  values     = [file("${path.module}/jenkins.yml")]
}