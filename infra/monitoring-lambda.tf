data "archive_file" "sns_lambda" {
  type = "zip"

  source_dir  = "../${path.module}/monitoring"
  output_path = "../${path.module}/monitoring.zip"
}

resource "aws_s3_object" "sns_lambda" {
  bucket = aws_s3_bucket.s3.id

  key    = "monitoring.zip"
  source = data.archive_file.sns_lambda.output_path

  etag = filemd5(data.archive_file.sns_lambda.output_path)
}

resource "aws_lambda_function" "sns_lambda" {

  function_name = "SlackNotifier"

  s3_bucket = aws_s3_bucket.s3.id
  s3_key    = aws_s3_object.sns_lambda.key

  runtime = "python3.9"
  handler = "index.lambda_handler"

  source_code_hash = data.archive_file.sns_lambda.output_base64sha256

  role = aws_iam_role.lambda_iam.arn
}

resource "aws_lambda_permission" "sns_lambda" {
  statement_id  = "AllowExecutionFromSNSAlarms"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.crc_sns.arn
}

resource "aws_sns_topic_subscription" "sns_lambda" {
  topic_arn = aws_sns_topic.crc_sns.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_lambda.arn
}
