data "aws_caller_identity" "current" {}

resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-launch-template"
  image_id      = var.ami_id
  instance_type = "t3.micro"

  key_name = "aws-ha-key"

  network_interfaces {
    associate_public_ip_address = false

    security_groups = [
      aws_security_group.app_sg.id
    ]
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    account_id  = data.aws_caller_identity.current.account_id
    aws_region  = var.aws_region
    ecr_repo    = "task-manager-app"
    bucket_name = aws_s3_bucket.app_bucket.bucket
    secret_name = aws_secretsmanager_secret.db_credentials.name
  }))


  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "asg-instance"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 30
      volume_type = "gp3"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name             = "app-asg"
  desired_capacity = 0
  max_size         = 0
  min_size         = 0

  vpc_zone_identifier = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  target_group_arns = [
    aws_lb_target_group.app_tg.arn
  ]

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 120

  tag {
    key                 = "Name"
    value               = "asg-instance"
    propagate_at_launch = true
  }
}