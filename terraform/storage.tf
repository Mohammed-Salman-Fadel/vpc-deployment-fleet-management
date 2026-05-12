resource "aws_s3_bucket" "fleet_data" {
  # bucket = 

  tags = {
    Name = "fleet-data"
  }
}

resource "aws_s3_bucket_public_access_block" "project_data" {
  bucket = aws_s3_bucket.project_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "project_data" {
  bucket = aws_s3_bucket.project_data.id

  versioning_configuration {
    status = "Enabled"
  }
}
