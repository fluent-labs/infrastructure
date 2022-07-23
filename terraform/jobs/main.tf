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
    name      = "jenkins-operator-jenkins"
    namespace = "default"
  }

  depends_on = [helm_release.jenkins]
}

resource "kubernetes_persistent_volume" "example" {
  metadata {
    name      = "sbt-cache"
    namespace = "jobs"
  }
  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      csi {
        driver        = "dobs.csi.digitalocean.com"
        volume_handle = "jenkins-sbt-cache"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "sbt" {
  metadata {
    name      = "sbt-cache"
    namespace = "jobs"
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
    volume_name = "sbt_cache"
  }
}