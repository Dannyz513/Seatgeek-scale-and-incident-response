data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

resource "aws_lambda_function" "incident_logger" {
  function_name    = "${var.project_name}-incident-logger"
  role             = aws_iam_role.incident_logger.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.incidents.name
    }
  }
}

# --- EventBridge rule: catches every CloudWatch alarm state change ---
resource "aws_cloudwatch_event_rule" "alarm_state_change" {
  name        = "${var.project_name}-alarm-state-change"
  description = "Captures CloudWatch alarm state changes for incident logging"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    resources   = [
      aws_cloudwatch_metric_alarm.high_latency.arn,
      aws_cloudwatch_metric_alarm.high_error_rate.arn,
      aws_cloudwatch_metric_alarm.asg_at_max_capacity.arn,
    ]
  })
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.alarm_state_change.name
  target_id = "incident-logger"
  arn       = aws_lambda_function.incident_logger.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident_logger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_state_change.arn
}