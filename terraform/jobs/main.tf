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

resource "kubernetes_role" "jenkins" {
  metadata {
    name      = "jenkins-operator-jenkins"
    namespace = "jobs"
  }

  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["image.openshift.io"]
    resources  = ["imagestreams"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["build.openshift.io"]
    resources  = ["buildconfigs"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["build.openshift.io"]
    resources  = ["builds"]
    verbs      = ["get", "list", "watch"]
  }
}