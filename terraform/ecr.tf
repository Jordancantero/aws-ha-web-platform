resource "aws_ecr_repository" "flask_app" {
  name                 = "task-manager-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "task-manager-app"
  }
}