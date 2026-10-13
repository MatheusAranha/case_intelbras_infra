resource "random_password" "rds_master" {
  length  = 32
  special = false # avoids characters RDS/JDBC URLs need escaping
}

resource "aws_secretsmanager_secret" "rds_credentials" {
  name                    = "${var.project_name}/rds/master-credentials"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = "iotevents"
    password = random_password.rds_master.result
  })
}
