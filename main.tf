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
  description = "The SNS topic for CloudWatch alarms"
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

module "log_group_checker_lambda_alarms" {
  source = "github.com/Fraham/TerraformModuleForAws//modules/services/lambda/alarms"
  
  function_name = [aws_lambda_function.log_group_checker.function_name]
  cloud_watch_alarm_topic = var.cloud_watch_alarm_topic
}

module "check_schedule" {
  source = "github.com/Fraham/TerraformModuleForAws//modules/services/lambda/schedule"
  
  function_name = aws_lambda_function.log_group_checker.function_name
  function_arn = aws_lambda_function.log_group_checker.arn
  schedule_expression = "rate(1 day)"
}
