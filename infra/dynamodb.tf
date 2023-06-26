resource "aws_dynamodb_table" "crc_db_table" {
  name         = "VisitorsCount"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ip_hash"

  attribute {
    name = "ip_hash"
    type = "S"
  }
}
