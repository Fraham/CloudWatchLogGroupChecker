provider "aws" {
  region = "eu-west-1"
}

variable "bucket" {
}
variable "app_version" {
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
}

resource "aws_lambda_layer_version" "dependencies" {
  layer_name = "Dependencies"
  s3_bucket = var.bucket
  s3_key = "v${var.app_version}/dependencies.zip"
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
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "log_group_checker_logs" {
  role       = aws_iam_role.log_group_checker_exec.name
  policy_arn = aws_iam_policy.log_group_checker_logging.arn
}
