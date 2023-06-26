resource "aws_cloudwatch_metric_alarm" "crc_cw_alarm_1" {
  alarm_name          = "NKDBackendLambdaErrors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "This metric monitors lambda errors"

  alarm_actions = [aws_sns_topic.crc_sns.arn]
  ok_actions    = [aws_sns_topic.crc_sns.arn]

  dimensions = {
    FunctionName = aws_lambda_function.lambda.function_name
  }

  depends_on = [
    aws_lambda_function.lambda,
    aws_sns_topic.crc_sns
  ]
}

resource "aws_cloudwatch_metric_alarm" "crc_cw_alarm_2" {
  alarm_name          = "NKDBackendLambdaInvocations"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors lambda invocations"

  dimensions = {
    FunctionName = aws_lambda_function.lambda.function_name
  }

  alarm_actions = [aws_sns_topic.crc_sns.arn]
  ok_actions    = [aws_sns_topic.crc_sns.arn]

  depends_on = [
    aws_lambda_function.lambda,
    aws_sns_topic.crc_sns
  ]
}
