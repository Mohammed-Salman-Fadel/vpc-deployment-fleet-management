data "aws_region" "current" {}

locals {
  monitored_ec2_instances = merge(
    {
      for instance in aws_instance.public : instance.tags.Name => {
        id     = instance.id
        subnet = instance.tags.Subnet
        tier   = instance.tags.Tier
      }
    },
    {
      for instance in aws_instance.private : instance.tags.Name => {
        id     = instance.id
        subnet = instance.tags.Subnet
        tier   = instance.tags.Tier
      }
    }
  )

  cloudwatch_alarm_actions = var.cloudwatch_alarm_email == null ? [] : [aws_sns_topic.cloudwatch_alerts[0].arn]

  public_ec2_cpu_metrics = [
    for instance in aws_instance.public : [
      "AWS/EC2",
      "CPUUtilization",
      "InstanceId",
      instance.id,
      { label = instance.tags.Name }
    ]
  ]

  private_ec2_cpu_metrics = [
    for instance in aws_instance.private : [
      "AWS/EC2",
      "CPUUtilization",
      "InstanceId",
      instance.id,
      { label = instance.tags.Name }
    ]
  ]

  ec2_status_metrics = [
    for name, instance in local.monitored_ec2_instances : [
      "AWS/EC2",
      "StatusCheckFailed",
      "InstanceId",
      instance.id,
      { label = name }
    ]
  ]
}

resource "aws_sns_topic" "cloudwatch_alerts" {
  count = var.cloudwatch_alarm_email == null ? 0 : 1

  name = "fleet-cloudwatch-alerts"

  tags = {
    Name = "fleet-cloudwatch-alerts"
  }
}

resource "aws_sns_topic_subscription" "cloudwatch_email" {
  count = var.cloudwatch_alarm_email == null ? 0 : 1

  topic_arn = aws_sns_topic.cloudwatch_alerts[0].arn
  protocol  = "email"
  endpoint  = var.cloudwatch_alarm_email
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  for_each = local.monitored_ec2_instances

  alarm_name          = "${each.key}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cloudwatch_cpu_alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.cloudwatch_metric_period
  statistic           = "Average"
  threshold           = var.cloudwatch_cpu_alarm_threshold
  alarm_description   = "Triggers when average CPU utilization is above ${var.cloudwatch_cpu_alarm_threshold}% for ${each.key}."
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value.id
  }

  tags = {
    Name   = "${each.key}-high-cpu"
    Tier   = each.value.tier
    Subnet = each.value.subnet
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  for_each = local.monitored_ec2_instances

  alarm_name          = "${each.key}-status-check-failed"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.cloudwatch_status_alarm_evaluation_periods
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = var.cloudwatch_status_alarm_period
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Triggers when EC2 status checks fail for ${each.key}."
  alarm_actions       = local.cloudwatch_alarm_actions
  ok_actions          = local.cloudwatch_alarm_actions
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = each.value.id
  }

  tags = {
    Name   = "${each.key}-status-check-failed"
    Tier   = each.value.tier
    Subnet = each.value.subnet
  }
}

resource "aws_cloudwatch_dashboard" "fleet" {
  dashboard_name = var.cloudwatch_dashboard_name

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Public EC2 CPU utilization"
          region  = data.aws_region.current.region
          view    = "timeSeries"
          stacked = false
          period  = var.cloudwatch_metric_period
          stat    = "Average"
          metrics = local.public_ec2_cpu_metrics
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Private EC2 CPU utilization"
          region  = data.aws_region.current.region
          view    = "timeSeries"
          stacked = false
          period  = var.cloudwatch_metric_period
          stat    = "Average"
          metrics = local.private_ec2_cpu_metrics
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6
        properties = {
          title   = "EC2 status check failures"
          region  = data.aws_region.current.region
          view    = "timeSeries"
          stacked = false
          period  = var.cloudwatch_status_alarm_period
          stat    = "Maximum"
          metrics = local.ec2_status_metrics
        }
      },
      {
        type   = "text"
        x      = 0
        y      = 12
        width  = 24
        height = 3
        properties = {
          markdown = "## Fleet monitoring\\nTracks CPU utilization and EC2 status checks for the public and private EC2 instances created across both Availability Zones."
        }
      }
    ]
  })
}
