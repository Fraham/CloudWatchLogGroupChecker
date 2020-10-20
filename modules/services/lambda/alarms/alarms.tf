variable "function_name" {
  description = "The name of the function having default alarms set"
  type        = string
}
variable "cloud_watch_alarm_topic" {
  type        = string
  description = "The SNS topic for CloudWatch alarms"
  default     = ""
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors_alarm" {
  alarm_name          = "${var.function_name}-LambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "${var.function_name} lambda errors"
  treat_missing_data  = "notBreaching"
  dimensions = {
    FunctionName = var.function_name
  }
  alarm_actions = [var.cloud_watch_alarm_topic]
  ok_actions    = [var.cloud_watch_alarm_topic]
  count         = var.cloud_watch_alarm_topic == "" ? 0 : 1
}
