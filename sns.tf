resource "aws_sns_topic" "incidents" {
  name = "${var.project_name}-incidents"

  tags = {
    Name = "${var.project_name}-incidents-topic"
  }
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.incidents.arn
  protocol  = "email"
  endpoint  = var.alert_email
}