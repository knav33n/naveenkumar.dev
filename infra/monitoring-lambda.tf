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

  runtime = "python3.12"
  handler = "index.lambda_handler"
  timeout = 10

  source_code_hash = data.archive_file.sns_lambda.output_base64sha256

  role = aws_iam_role.notifier.arn

  environment {
    variables = {
      SLACK_WEBHOOK = var.SLACK_WEBHOOK
    }
  }
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

# The notifier has its own role: it reads the backend's logs and alarm history
# to enrich alerts, and needs no DynamoDB access.
resource "aws_iam_role" "notifier" {
  name               = "NKDSlackNotifierRole"
  assume_role_policy = data.aws_iam_policy_document.policy_doc_to_assume_role.json
}

resource "aws_iam_role_policy_attachment" "notifier_basic" {
  role       = aws_iam_role.notifier.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "notifier" {
  statement {
    effect    = "Allow"
    actions   = ["logs:FilterLogEvents"]
    resources = ["arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.lambda.function_name}:*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["cloudwatch:DescribeAlarmHistory"]
    resources = ["arn:aws:cloudwatch:us-east-1:${data.aws_caller_identity.current.account_id}:alarm:NKD*"]
  }
}

resource "aws_iam_role_policy" "notifier" {
  name   = "NKDSlackNotifierPolicy"
  role   = aws_iam_role.notifier.id
  policy = data.aws_iam_policy_document.notifier.json
}
