# --- DynamoDB table: the permanent, queryable incident record ---
resource "aws_dynamodb_table" "incidents" {
  name         = "${var.project_name}-incidents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "incident_id"

  attribute {
    name = "incident_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-incidents-table"
  }
}

# --- IAM role for the incident-logging Lambda ---
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "incident_logger" {
  name               = "${var.project_name}-incident-logger-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# --- Least-privilege: this Lambda can only write to THIS table, nothing else ---
data "aws_iam_policy_document" "incident_logger_permissions" {
  statement {
    sid       = "WriteIncidents"
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.incidents.arn]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:*:*:*"]
  }
}

resource "aws_iam_role_policy" "incident_logger" {
  name   = "${var.project_name}-incident-logger-policy"
  role   = aws_iam_role.incident_logger.id
  policy = data.aws_iam_policy_document.incident_logger_permissions.json
}