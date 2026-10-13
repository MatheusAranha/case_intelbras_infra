resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "audit_store" {
  identifier     = "${var.project_name}-audit-db"
  engine         = "postgres"
  engine_version = "16"

  instance_class         = var.rds_instance_class
  allocated_storage      = var.rds_allocated_storage_gb
  storage_type           = "gp3"
  multi_az               = var.rds_multi_az
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  db_name  = var.rds_database_name
  username = jsondecode(aws_secretsmanager_secret_version.rds_credentials.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.rds_credentials.secret_string)["password"]

  backup_retention_period   = 7
  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-audit-db-final"

  # Flyway (already part of the app) owns schema migrations — Terraform only
  # provisions the empty instance.
}
