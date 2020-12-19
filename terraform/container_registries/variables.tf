variable "push_users" {
  description = "An array of users who can push containers to these registries"
}

variable "kubernetes_namespaces" {
  description = "An array of namespaces that can pull containers from these registries"
}
