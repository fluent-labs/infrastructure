variable "name" {
  description = "The name of the container"
}

variable "image_count" {
  description = "The number of images to keep"
}

variable "push_users" {
  description = "An array of users who can push containers to this registry"
}

variable "pull_users" {
  description = "An array of users who can pull containers from this registry"
}
