variable "deploy_users" {
  description = "The IAM users to give write permissions to."
}

variable "domain" {
  description = "The domain the site will be hosted on."
}

variable "subdomain" {
  description = "The subdomain the site will be hosted on."
}

variable "certificate_arn" {
  description = "The ARN of the certificate in AWS certificate manager"
}
