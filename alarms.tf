resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.project_name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  extended_statistic  = "p99"
  threshold           = var.latency_threshold_seconds
  alarm_description   = "p99 latency exceeded ${var.latency_threshold_seconds}s for 3 consecutive minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.incidents.arn]
  ok_actions    = [aws_sns_topic.incidents.arn]
}

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  alarm_name          = "${var.project_name}-high-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = var.error_rate_threshold
  alarm_description   = "5xx error count exceeded ${var.error_rate_threshold} in a 1-minute period"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.app.arn_suffix
  }

  alarm_actions = [aws_sns_topic.incidents.arn]
  ok_actions    = [aws_sns_topic.incidents.arn]
}

resource "aws_cloudwatch_metric_alarm" "asg_at_max_capacity" {
  alarm_name          = "${var.project_name}-asg-at-max-capacity"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 60
  statistic           = "Maximum"
  threshold           = var.peak_capacity
  alarm_description   = "Auto Scaling Group has reached maximum capacity - a leading indicator that capacity planning may be insufficient"
  treat_missing_data  = "notBreaching"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app.name
  }

  alarm_actions = [aws_sns_topic.incidents.arn]
}