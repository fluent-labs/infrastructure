terraform {
  required_providers {
    elasticsearch = {
      source  = "disaster37/elasticsearch"
      version = "7.12.2"
    }
  }
}

# data "kubernetes_secret" "elastic_user" {
#   metadata {
#     name = "elastic-es-elastic-user"
#   }
# }

# provider "elasticsearch" {
#   urls     = "https://elastic.fluentlabs.io:9200"
#   username = "elastic"
#   password = data.kubernetes_secret.elastic_user.data.elastic
# }

# resource "elasticsearch_user" "api" {
#   username  = "apiprod"
#   enabled   = "true"
#   email     = "apiprod@foreignlanguagereader.com"
#   full_name = "api prod"
#   password  = var.api_password
#   roles     = ["api_prod"]
# }

# resource "elasticsearch_user" "fluentd" {
#   username  = "fluentd"
#   enabled   = "true"
#   email     = "fluentd@fluentlabs.io"
#   full_name = "fluentd"
#   password  = var.fluentd_password
#   roles     = ["fluentd"]
# }

# resource "elasticsearch_user" "spark" {
#   username  = "spark"
#   enabled   = "true"
#   email     = "spark@foreignlanguagereader.com"
#   full_name = "spark"
#   password  = var.spark_password
#   roles     = ["spark"]
# }

# Backup configuration

# resource "elasticsearch_snapshot_repository" "backups" {
#   name = "S3-backup"
#   type = "s3"
#   settings = {
#     "bucket" = aws_s3_bucket.backup.id
#   }
# }

# resource "elasticsearch_snapshot_lifecycle_policy" "daily_backup" {
#   name          = "daily-snapshots"
#   snapshot_name = "backup"
#   schedule      = "0 30 1 * * ?"
#   repository    = elasticsearch_snapshot_repository.backups.name
#   retention     = <<EOF
# {
#     "expire_after": "120d"
# }
# EOF
# }

# Automated log rollover
# resource "elasticsearch_index_lifecycle_policy" "rollover" {
#   name   = "logging-rollover"
#   policy = <<EOF
# {
#   "policy": {
#     "phases": {
#       "hot": {
#         "min_age": "0ms",
#         "actions": {
#           "rollover": {
#             "max_size": "50gb",
#             "max_age": "30d"
#           }
#         }
#       },
#       "delete": {
#         "min_age": "60d",
#         "actions": {
#           "wait_for_snapshot": {
#             "policy": "daily-snapshots"
#           }
#         }
#       }
#     }
#   }
# }
# EOF

#   depends_on = [elasticsearch_snapshot_lifecycle_policy.daily_backup]
# }

# resource "elasticsearch_index_template" "fluentd" {
#   name     = "fluentd"
#   template = <<EOF
# {
#   "index_patterns": [
#     "logstash-*"
#   ],
#   "settings": {
#     "index.lifecycle.name": "logging-rollover",
#     "index.lifecycle.rollover_alias": "logstash-backup-alias"
#   }
# }
# EOF

#   depends_on = [elasticsearch_index_lifecycle_policy.rollover]
# }