output "fluentd_password" {
  value = random_password.fluent_elasticsearch_password.result
}
