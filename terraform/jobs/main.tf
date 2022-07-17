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

data "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins-operator-jenkins"
    namespace = "jobs"
  }
  depends_on = [helm_release.jenkins]
}

resource "kubernetes_role" "jenkins" {
  for_each = toset(var.job_namespaces)

  metadata {
    name      = "jenkins-operator-jenkins"
    namespace = each.value
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

resource "kubernetes_role_binding" "jenkins" {
  for_each = toset(var.job_namespaces)

  metadata {
    name      = "jenkins-operator-jenkins"
    namespace = each.value
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "jenkins-operator-jenkins"
  }
  subject {
    kind      = "ServiceAccount"
    # Intentionally using the variable just to make terraform understand the dependency graph.
    name      = data.kubernetes_service_account.jenkins.metadata.name
    namespace = "jobs"
  }
}
