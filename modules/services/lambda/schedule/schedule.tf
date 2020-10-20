variable "function_name" {
  description = "The name of the function having a schedule set"
  type        = string
}
variable "function_arn" {
  description = "The arn of the function having a schedule set"
  type        = string
}
variable "schedule_expression" {
  description = "The expression for the schedule"
  type        = string
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  description         = "Schedule for ${var.function_name} with expression ${var.schedule_expression}"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "event_target" {
  rule      = aws_cloudwatch_event_rule.event_rule.name
  target_id = "lambda"
  arn       = var.function_arn
}

resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = var.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.event_rule.arn
}