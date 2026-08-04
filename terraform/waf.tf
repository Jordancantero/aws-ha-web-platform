resource "aws_wafv2_web_acl" "app_waf" {

  name  = "task-manager-waf"
  scope = "REGIONAL"

  description = "WAF protecting the Application Load Balancer"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "task-manager-waf"
    sampled_requests_enabled   = true
  }

  rule {

    name     = "AllowFileUpload"
    priority = 0

    action {
      allow {}
    }

    statement {

      and_statement {

        statement {

          byte_match_statement {

            positional_constraint = "EXACTLY"

            search_string = "/add"

            field_to_match {
              uri_path {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }

          }

        }

        statement {

          byte_match_statement {

            positional_constraint = "EXACTLY"

            search_string = "POST"

            field_to_match {
              method {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }

          }

        }

      }

    }

    visibility_config {

      cloudwatch_metrics_enabled = true
      metric_name                = "AllowFileUpload"
      sampled_requests_enabled   = true

    }

  }

  #############################################################
  # AWS Managed Common Rule Set
  #############################################################

  rule {

    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {

      managed_rule_group_statement {

        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

      }

    }

    visibility_config {

      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true

    }

  }

  #############################################################
  # Known Bad Inputs
  #############################################################

  rule {

    name     = "KnownBadInputs"
    priority = 2

    override_action {
      none {}
    }

    statement {

      managed_rule_group_statement {

        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"

      }

    }

    visibility_config {

      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true

    }

  }

  #############################################################
  # Amazon IP Reputation
  #############################################################

  rule {

    name     = "AmazonIpReputation"
    priority = 3

    override_action {
      none {}
    }

    statement {

      managed_rule_group_statement {

        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"

      }

    }

    visibility_config {

      cloudwatch_metrics_enabled = true
      metric_name                = "IpReputation"
      sampled_requests_enabled   = true

    }

  }

  #############################################################
  # Anonymous IP List
  #############################################################

  rule {

    name     = "AnonymousIP"
    priority = 4

    override_action {
      none {}
    }

    statement {

      managed_rule_group_statement {

        vendor_name = "AWS"
        name        = "AWSManagedRulesAnonymousIpList"

      }

    }

    visibility_config {

      cloudwatch_metrics_enabled = true
      metric_name                = "AnonymousIP"
      sampled_requests_enabled   = true

    }

  }

  #############################################################
  # Rate Limiting
  #############################################################

  rule {

    name     = "RateLimit"
    priority = 5

    action {
      block {}
    }

    statement {

      rate_based_statement {

        limit              = 1000
        aggregate_key_type = "IP"

      }

    }

    visibility_config {

      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true

    }

  }

  tags = {
    Name        = "task-manager-waf"
    Project     = "aws-ha-task-manager"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }

}

resource "aws_wafv2_web_acl_association" "app_waf_association" {

  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.app_waf.arn

}