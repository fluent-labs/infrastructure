variable "cluster_name" {
  description = "The cluster this will run on"
}

variable "env" {
  description = "The K8s namespace to run this in"
}

variable "min_replicas" {
  description = "The minimum number of service replicas to run"
}

variable "max_replicas" {
  description = "The maximum number of service replicas to run"
}
