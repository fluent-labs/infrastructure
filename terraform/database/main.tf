resource "random_password" "database_admin_password" {
  length  = 64
  special = true
}

resource "aws_db_instance" "fluentlabs" {
  engine                     = "postgres"
  engine_version             = "12.5"
  instance_class             = "db.t3.micro"
  name                       = "fluentlabs"
  username                   = "admin"
  password                   = random_password.database_admin_password.result
  parameter_group_name       = "default.postgres12"
  skip_final_snapshot        = true
  deletion_protection        = true
  auto_minor_version_upgrade = true

  # Storage autoscaling goes here
  allocated_storage     = 20
  max_allocated_storage = 100
}