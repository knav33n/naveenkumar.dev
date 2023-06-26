resource "aws_iam_role" "crc_sns" {
  name               = "NKDSNSRole"
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "sns.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "crc_sns" {
  role       = aws_iam_role.crc_sns.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSNSRole"
}

resource "aws_sns_topic" "crc_sns" {
  name     = "NKDSnsTopic"

  lambda_success_feedback_sample_rate = 100

  lambda_failure_feedback_role_arn = aws_iam_role.crc_sns.arn
  lambda_success_feedback_role_arn = aws_iam_role.crc_sns.arn

  depends_on = [
    aws_iam_role.crc_sns
  ]
}
