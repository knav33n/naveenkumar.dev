data "aws_iam_policy_document" "policy_doc_to_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
    ]
  }
}

data "aws_iam_policy_document" "policy_doc_to_access_dynamodb" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DescribeTable",
      "dynamodb:Scan",
      "lambda:GetFunction"
    ]
    resources = [aws_dynamodb_table.crc_db_table.arn]
  }
}

data "archive_file" "lambda" {
  type = "zip"

  source_dir  = "../${path.module}/back-end"
  output_path = "../${path.module}/back-end.zip"
}

resource "aws_iam_role" "lambda_iam" {
  name               = "NKDDynamoDBRole"
  assume_role_policy = data.aws_iam_policy_document.policy_doc_to_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_iam" {
  role       = aws_iam_role.lambda_iam.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "policy_to_access_dynamodb" {
  name   = "NKDDynamoDBPolicy"
  policy = data.aws_iam_policy_document.policy_doc_to_access_dynamodb.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_iam.name
  policy_arn = aws_iam_policy.policy_to_access_dynamodb.arn
}

resource "aws_s3_object" "lambda" {
  bucket = aws_s3_bucket.s3.id

  key    = "back-end.zip"
  source = data.archive_file.lambda.output_path

  etag = filemd5(data.archive_file.lambda.output_path)
}

resource "aws_lambda_function" "lambda" {

  function_name = "VisitorsCounter"

  s3_bucket = aws_s3_bucket.s3.id
  s3_key    = aws_s3_object.lambda.key

  runtime = "python3.9"
  handler = "index.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  role = aws_iam_role.lambda_iam.arn
}

resource "aws_lambda_function_url" "lambda_function_url" {
  function_name      = aws_lambda_function.lambda.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["https://naveenkumar.dev", "https://www.naveenkumar.dev"]
    allow_methods     = ["*"]
    allow_headers     = ["date", "keep-alive"]
    expose_headers    = ["keep-alive", "date"]
    max_age           = 86400
  }
}

output "fn_url" {
  value = aws_lambda_function_url.lambda_function_url.function_url
}
