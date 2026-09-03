#--------------------------------
# SNS Topic & Subscription
#--------------------------------

resource "aws_sns_topic" "ops_alerts" {
  name = "distribution-ops-alerts"

  tags = {
    Name        = "distribution-ops-alerts"
    environment = "development"
    managed_by  = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "ops_alerts_email" {
  topic_arn = aws_sns_topic.ops_alerts.arn
  protocol  = "email"
  endpoint  = "ivorydcops@gmail.com"
}

#--------------------------------
# 1. ALB Unhealthy Hosts Alarm
#--------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "distribution-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "Alarm when any target instance behind ALB becomes unhealthy"
  alarm_actions       = [aws_sns_topic.ops_alerts.arn]
  ok_actions          = [aws_sns_topic.ops_alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.distribution_app_tg.arn_suffix
    LoadBalancer = aws_lb.distribution_internal_alb.arn_suffix
  }

  tags = {
    Name        = "distribution-alb-unhealthy-hosts"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#--------------------------------
# 2. EC2 ASG High CPU Alarm
#--------------------------------

resource "aws_cloudwatch_metric_alarm" "asg_high_cpu" {
  alarm_name          = "distribution-asg-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when ASG average CPU utilization exceeds 80%"
  alarm_actions       = [aws_sns_topic.ops_alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.distribution_app.name
  }

  tags = {
    Name        = "distribution-asg-high-cpu"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#--------------------------------
# 3. RDS High CPU Alarm
#--------------------------------

resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  alarm_name          = "distribution-rds-high-cpu"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alarm when RDS CPU utilization exceeds 80%"
  alarm_actions       = [aws_sns_topic.ops_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.distribution_mysql.identifier
  }

  tags = {
    Name        = "distribution-rds-high-cpu"
    environment = "development"
    managed_by  = "Terraform"
  }
}

#--------------------------------
# 4. RDS Low Free Storage Alarm
#--------------------------------

resource "aws_cloudwatch_metric_alarm" "rds_low_storage" {
  alarm_name          = "distribution-rds-low-storage"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 5000000000 # 5 GB in bytes
  alarm_description   = "Alarm when RDS free storage drops below 5GB"
  alarm_actions       = [aws_sns_topic.ops_alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.distribution_mysql.identifier
  }

  tags = {
    Name        = "distribution-rds-low-storage"
    environment = "development"
    managed_by  = "Terraform"
  }
}
