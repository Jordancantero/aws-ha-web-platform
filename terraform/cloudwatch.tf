resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "aws-ha-taskmanager-dashboard"

  dashboard_body = jsonencode({
    widgets = [

      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.app_asg.name]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          title  = "EC2 CPU Utilization"
          period = 300
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.app_alb.arn_suffix]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          title  = "ALB Request Count"
          period = 300
        }
      },

      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.app_tg.arn_suffix]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          title  = "ALB Healthy Hosts"
          period = 300
        }
      },

      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "app-postgres"]
          ]
          view   = "timeSeries"
          region = "us-east-1"
          title  = "RDS CPU Utilization"
          period = 300
        }
      }

    ]

  })
}

resource "aws_cloudwatch_log_group" "app_logs" {

  name = "/aws/ec2/task-manager"

  retention_in_days = 30

  tags = {
    Name = "task-manager-logs"
  }

}
