variable "domain" {
  description = "The domain to attach subdomains to"
}

variable "subdomains" {
  description = "The subdomains to point at the K8s cluster"
}

variable "private_key_pem" {}

variable "certificate_pem" {}

variable "issuer_pem" {}

variable "namespace" {
  description = "The kubernetes namespace to install in"
}

variable "additional_certificate_namespaces" {
  description = "Additional namespaces to make the fluentlabs certificate available in."
}