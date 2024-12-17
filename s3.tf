resource "aws_s3_bucket" "this" {
  bucket = "${var.name_prefix}-documentation-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.id}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
      kms_master_key_id = null
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id

  policy = data.aws_iam_policy_document.this.json
}

data "aws_iam_policy_document" "this" {
  source_policy_documents = compact([
    try(data.aws_iam_policy_document.allow_read_cloudfront_distribution_arns[0].json, ""),
  ])
}

data "aws_iam_policy_document" "allow_read_cloudfront_distribution_arns" {
  count = var.resource_policy_allow_read_cloudfront_distribution_arns == null ? 0 : 1

  statement {
    sid    = "ReadFromCloudFrontDistribution"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = var.resource_policy_allow_read_cloudfront_distribution_arns
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  ignore_public_acls      = true
  block_public_acls       = true
  restrict_public_buckets = true
  block_public_policy     = true
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  name   = "all"

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 180
  }
}

resource "aws_s3_object" "redoc" {
  bucket = aws_s3_bucket.this.bucket
  key    = "index.html"

  cache_control = "public, max-age=0"

  content = templatefile("${path.module}/resources/redoc.html", {
    title = urlencode(var.title)
    apis  = terraform_data.apis.output
  })
  content_type = "text/html"
}

resource "terraform_data" "apis" {
  input = jsonencode([
    for key, value in var.apis : {
      name = value.name
      url  = aws_s3_object.open_api_spec[key].key
    }
  ])
}

resource "aws_s3_object" "open_api_spec" {
  for_each = var.apis

  bucket = aws_s3_bucket.this.bucket
  key    = "${lower(each.key)}-api-${substr(sha256(each.value.open_api_spec), 0, 10)}.yml"

  cache_control = "public, max-age=604800, immutable"

  content      = each.value.open_api_spec
  content_type = "application/yaml"

  lifecycle {
    create_before_destroy = true
  }
}
