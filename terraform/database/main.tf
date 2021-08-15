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
  // Basic config
  engine               = "postgres"
  engine_version       = "12.5"
  instance_class       = "db.t3.micro"
  identifier           = "fluentlabs"
  name                 = "fluentlabs"
  parameter_group_name = "default.postgres12"

  // Backups and deletion protection
  skip_final_snapshot        = true
  deletion_protection        = true
  auto_minor_version_upgrade = true
  backup_retention_period    = 30

  // Security goes here
  // This is fine because we have tight security groups
  username               = "fluentlabs_admin"
  password               = random_password.database_admin_password.result
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.database.id]

  // Networking
  db_subnet_group_name = aws_db_subnet_group.main.name

  # Storage autoscaling
  allocated_storage     = 20
  max_allocated_storage = 100
}

data "aws_subnet" "first" {
  id = var.subnet_ids[0]
}

data "aws_vpc" "main" {
  id = data.aws_subnet.first.vpc_id
}

resource "aws_security_group" "database" {
  name        = "database"
  description = "Allow database inbound traffic from the vpc"
  vpc_id      = data.aws_vpc.main.id

  ingress = [
    {
      description      = "database from VPC"
      from_port        = 5432
      to_port          = 5432
      protocol         = "tcp"
      cidr_blocks      = [data.aws_vpc.main.cidr_block]
      ipv6_cidr_blocks = [data.aws_vpc.main.ipv6_cidr_block]
    }
  ]

  tags = {
    Name = "database"
  }
}