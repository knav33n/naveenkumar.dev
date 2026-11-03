# Alarms on the views counter Lambda. Each alarm_description is used as the
# Slack alert's headline, so keep it short and human-readable.
#
# treat_missing_data = "notBreaching": the site is quiet most of the time, and
# without it the alarms flap through INSUFFICIENT_DATA whenever there is no
# traffic.

locals {
  backend_function = aws_lambda_function.lambda.function_name
  alarm_topic      = [aws_sns_topic.crc_sns.arn]
}

resource "aws_cloudwatch_metric_alarm" "crc_cw_alarm_1" {
  alarm_name          = "NKDBackendLambdaErrors"
  alarm_description   = "Views counter is failing — visitors see \"Couldn't load views\""
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = local.backend_function
  }

  alarm_actions = local.alarm_topic
  ok_actions    = local.alarm_topic
}

resource "aws_cloudwatch_metric_alarm" "crc_cw_alarm_2" {
  alarm_name          = "NKDBackendLambdaInvocations"
  alarm_description   = "Traffic spike on the views counter (more than 10 requests/min)"
  namespace           = "AWS/Lambda"
  metric_name         = "Invocations"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = local.backend_function
  }

  alarm_actions = local.alarm_topic
  ok_actions    = local.alarm_topic
}

# Early warning: slow invocations approaching the timeout turn into 502s.
resource "aws_cloudwatch_metric_alarm" "backend_duration" {
  alarm_name          = "NKDBackendLambdaSlow"
  alarm_description   = "Views counter is slow — close to its ${aws_lambda_function.lambda.timeout}s timeout"
  namespace           = "AWS/Lambda"
  metric_name         = "Duration"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = aws_lambda_function.lambda.timeout * 1000 * 0.8
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = local.backend_function
  }

  alarm_actions = local.alarm_topic
  ok_actions    = local.alarm_topic
}

resource "aws_cloudwatch_metric_alarm" "backend_throttles" {
  alarm_name          = "NKDBackendLambdaThrottles"
  alarm_description   = "Views counter is being throttled — requests are rejected"
  namespace           = "AWS/Lambda"
  metric_name         = "Throttles"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = local.backend_function
  }

  alarm_actions = local.alarm_topic
  ok_actions    = local.alarm_topic
}
