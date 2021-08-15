resource "random_password" "database_admin_password" {
  length  = 64
  special = true
}

resource "aws_db_subnet_group" "main" {
  name       = "fluentlabs-kubernetes-subnets"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "Fluentlabs database subnet group"
  }
}

resource "aws_db_instance" "fluentlabs" {
  engine                     = "postgres"
  engine_version             = "12.5"
  instance_class             = "db.t3.micro"
  identifier                 = "fluentlabs"
  name                       = "fluentlabs"
  username                   = "fluentlabs_admin"
  password                   = random_password.database_admin_password.result
  parameter_group_name       = "default.postgres12"
  skip_final_snapshot        = true
  aws_db_subnet_group        = aws_db_subnet_group.main.name
  deletion_protection        = true
  auto_minor_version_upgrade = true
  backup_retention_period    = 30

  # Storage autoscaling goes here
  allocated_storage     = 20
  max_allocated_storage = 100
}