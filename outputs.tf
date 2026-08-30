output "alb_dns_name" {
  description = "Public DNS name of the load balancer"
  value       = aws_lb.app.dns_name
}

output "incidents_table_name" {
  description = "Name of the DynamoDB table storing incident records"
  value       = aws_dynamodb_table.incidents.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for incident alerts"
  value       = aws_sns_topic.incidents.arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}