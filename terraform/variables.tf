variable "cluster_name" {
  description = "The name of the K8s cluster to post secrets to"
}

variable "digitalocean_token" {
  description = "The digitalocean auth token. Used to generate cert challenges"
}

variable "sematext_index_name" {
  description = "The elasticsearch index to send logs to. This is kept secret."
}