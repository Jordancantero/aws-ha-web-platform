resource "aws_secretsmanager_secret" "db_credentials" {
  name = "app-postgres-credentials"

  tags = {
    Name = "app-postgres-credentials"
  }
}


resource "aws_secretsmanager_secret_version" "db_credentials_version" {

  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    database = var.db_name
    host     = aws_db_instance.postgres.address
  })
}