
locals {
  name = "${var.project_name}-${var.environment}-site"
}

# Bucket
resource "aws_s3_bucket" "site" {
  bucket = local.name
}

# Propietario del bucket
resource "aws_s3_bucket_ownership_controls" "own" {
  bucket = aws_s3_bucket.site.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Bloquear ACLs públicas (lo maneja la policy)
resource "aws_s3_bucket_public_access_block" "pab" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Habilitar static website hosting
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  index_document {
    suffix = var.index_doc
  }
  error_document {
    key = var.error_doc
  }
}

# Política: público lectura
resource "aws_s3_bucket_policy" "site_policy" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.site.arn}/*"
      }
    ]
  })
}
