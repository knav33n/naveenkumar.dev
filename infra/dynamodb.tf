resource "aws_dynamodb_table" "crc_db_table" {
  name         = "VisitorsCount"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ip_hash"

  attribute {
    name = "ip_hash"
    type = "S"
  }
}

# Short links: naveenkumar.dev/r/<id> -> name to show in visit notifications.
resource "aws_dynamodb_table" "share_links" {
  name         = "ShareLinks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
