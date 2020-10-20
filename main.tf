provider "aws" {
  region = "eu-west-1"
}

variable "bucket" {
}
variable "app_version" {
}
variable "notification_topic" {
  type    = string
  default = ""
}
variable "cloud_watch_alarm_topic" {
  type    = string
  default = ""
}

data "aws_caller_identity" "current" {}

resource "aws_lambda_function" "log_group_checker" {
  function_name = "LogGroupChecker"

  s3_bucket = var.bucket
  s3_key    = "v${var.app_version}/code.zip"

  handler = "logGroupChecker.handler"
  runtime = "nodejs12.x"

  role = aws_iam_role.log_group_checker_exec.arn

  layers = [aws_lambda_layer_version.dependencies.arn]

  tracing_config {
    mode = "Active"
  }

  timeout = 30

  environment {
    variables = {
      NOTIFICATION_TOPIC = var.notification_topic,
      PARAMETER_NAME     = aws_ssm_parameter.maximum_retention_period.name
    }
  }
}

resource "aws_lambda_layer_version" "dependencies" {
  layer_name = "Dependencies"
  s3_bucket  = var.bucket
  s3_key     = "v${var.app_version}/dependencies.zip"
}

resource "aws_iam_role" "log_group_checker_exec" {
  name = "log_group_checker_lambda_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

}

resource "aws_iam_policy" "log_group_checker_logging" {
  name        = "log_group_checker_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:ListTagsLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogGroups",
        "logs:DeleteRetentionPolicy",
        "logs:PutRetentionPolicy",
        "logs:CreateLogGroup",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:*",
      "Effect": "Allow"
    },
    {
      "Action": [
        "sns:Publish"
      ],
      "Resource":"${var.notification_topic == "" ? "*" : var.notification_topic}",
      "Effect": "Allow"
    },
    {
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource":"${aws_ssm_parameter.maximum_retention_period.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "log_group_checker_logs" {
  role       = aws_iam_role.log_group_checker_exec.name
  policy_arn = aws_iam_policy.log_group_checker_logging.arn
}

resource "aws_iam_role_policy_attachment" "aws_xray_write_only_access" {
  role       = aws_iam_role.log_group_checker_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_ssm_parameter" "maximum_retention_period" {
  name        = "/LogGroupChecker/maximumRetentionPeriod"
  description = "Maximum retention period for CloudWatch Log Groups, used in LogGroupChecker."
  type        = "String"
  value       = 3
  overwrite   = true
}

resource "aws_cloudwatch_metric_alarm" "log_group_checker_lambda_errors" {
  alarm_name          = "LogGroupCheckerLambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "LogGroupChecker lambda errors"
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = aws_lambda_function.log_group_checker.function_name
  }
  alarm_actions = [var.cloud_watch_alarm_topic]
  ok_actions    = [var.cloud_watch_alarm_topic]
  count         = var.cloud_watch_alarm_topic == "" ? 0 : 1
}

resource "aws_cloudwatch_event_rule" "every_day" {
  name                = "every-one-minute"
  description         = "Fires every one day"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "check_log_groups_every_day" {
  rule      = aws_cloudwatch_event_rule.every_day.name
  target_id = "lambda"
  arn       = aws_lambda_function.log_group_checker.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_log_groups" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_group_checker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_day.arn
}
