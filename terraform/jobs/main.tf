resource "kubernetes_namespace" "jobs" {
  metadata {
    name = "jobs"
  }
}

resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = "jobs"
  repository = "https://raw.githubusercontent.com/jenkinsci/kubernetes-operator/master/chart"
  chart      = "jenkins-operator"
  version    = "0.6.2"
  values     = [file("${path.module}/jenkins.yml")]

  depends_on = [kubernetes_namespace.jobs]
}

resource "kubernetes_config_map" "jenkins" {
  metadata {
    name = "jenkins-config-as-code"
  }

  data = {
    "1-jenkins-config.yaml" = file("${path.module}/jenkins.yml")
  }
}

resource "kubernetes_role" "jenkins" {
  for_each = toset(var.job_namespaces)

  metadata {
    name      = "jenkins-operator-fluentlabs"
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
    name      = "jenkins-operator-fluentlabs"
    namespace = each.value
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "jenkins-operator-fluentlabs"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins-operator-fluentlabs"
    namespace = "default"
  }

  depends_on = [helm_release.jenkins]
}

resource "kubernetes_persistent_volume_claim" "cache" {
  for_each = toset(var.job_caches)

  metadata {
    name      = "${each.value}-cache"
    namespace = "jobs"
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "do-block-storage"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}