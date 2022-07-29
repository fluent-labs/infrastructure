variable "api_password" {
  description = "The size machine to run the database on."
  sensitive   = true
}

variable "fluentd_password" {
  description = "The password for the logging user."
  sensitive   = true
}

variable "spark_password" {
  description = "The password for the spark user."
  sensitive   = true
}

variable "domain" {
  description = "The domain to attach subdomains to"
}