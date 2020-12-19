variable "cluster_name" {
  description = "The name of the K8s cluster to post secrets to"
}

variable "digitalocean_token" {
  description = "The digitalocean auth token. Used to generate cert challenges"
}
