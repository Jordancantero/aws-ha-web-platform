resource "aws_vpc_endpoint" "s3" {

  vpc_id = aws_vpc.main.id

  service_name = "com.amazonaws.us-east-1.s3"

  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_app_rt.id
  ]

  tags = {
    Name = "s3-gateway-endpoint"
  }

}

resource "aws_security_group" "vpce_sg" {

  name        = "vpce-security-group"
  description = "Security Group for VPC Interface Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {

    description = "HTTPS from application instances"

    from_port = 443
    to_port   = 443
    protocol  = "tcp"

    security_groups = [
      aws_security_group.app_sg.id
    ]
  }

  egress {

    from_port = 0
    to_port   = 0
    protocol  = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "vpce-security-group"
  }

}

resource "aws_vpc_endpoint" "secretsmanager" {

  vpc_id = aws_vpc.main.id

  service_name = "com.amazonaws.us-east-1.secretsmanager"

  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "secretsmanager-endpoint"
  }

}

resource "aws_vpc_endpoint" "ecr_api" {

  vpc_id = aws_vpc.main.id

  service_name = "com.amazonaws.us-east-1.ecr.api"

  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "ecr-api-endpoint"
  }

}

resource "aws_vpc_endpoint" "ecr_dkr" {

  vpc_id = aws_vpc.main.id

  service_name = "com.amazonaws.us-east-1.ecr.dkr"

  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "ecr-dkr-endpoint"
  }

}

resource "aws_vpc_endpoint" "cloudwatch_logs" {

  vpc_id = aws_vpc.main.id

  service_name = "com.amazonaws.us-east-1.logs"

  vpc_endpoint_type = "Interface"

  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  security_group_ids = [
    aws_security_group.vpce_sg.id
  ]

  private_dns_enabled = true

  tags = {
    Name = "cloudwatch-logs-endpoint"
  }

}
