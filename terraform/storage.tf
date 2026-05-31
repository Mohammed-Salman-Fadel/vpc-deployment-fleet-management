locals {
  sample_data_files = fileset("${path.module}/../app/data", "*.json")
}

resource "aws_s3_bucket" "fleet_data" {
  bucket_prefix = "fleet-data-${data.aws_caller_identity.current.account_id}-"

  tags = {
    Name = "fleet-data"
  }
}

resource "aws_s3_bucket_public_access_block" "project_data" {
  bucket = aws_s3_bucket.fleet_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_versioning" "project_data" {
  bucket = aws_s3_bucket.fleet_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "fleet_data" {
  bucket = aws_s3_bucket.fleet_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "sample_data" {
  for_each = local.sample_data_files

  bucket                 = aws_s3_bucket.fleet_data.id
  key                    = "sample-data/current/${each.value}"
  source                 = "${path.module}/../app/data/${each.value}"
  source_hash            = filemd5("${path.module}/../app/data/${each.value}")
  content_type           = "application/json"
  server_side_encryption = "AES256"
  storage_class          = "STANDARD"

  tags = {
    Name        = "current-${each.value}"
    DataSet     = "fleet-sample-data"
    StorageTier = "standard"
  }
}

resource "aws_s3_object" "glacier_sample_data" {
  for_each = local.sample_data_files

  bucket                 = aws_s3_bucket.fleet_data.id
  key                    = "sample-data/glacier-archive/${each.value}"
  source                 = "${path.module}/../app/data/${each.value}"
  source_hash            = filemd5("${path.module}/../app/data/${each.value}")
  content_type           = "application/json"
  server_side_encryption = "AES256"
  storage_class          = "GLACIER"

  tags = {
    Name        = "glacier-${each.value}"
    DataSet     = "fleet-sample-data"
    StorageTier = "glacier"
  }
}
