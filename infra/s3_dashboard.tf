data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "dashboard" {
  bucket = "${local.name_prefix}-dashboard-${data.aws_caller_identity.current.account_id}"
  tags   = local.tags
}

resource "aws_s3_bucket_public_access_block" "dashboard" {
  bucket                  = aws_s3_bucket.dashboard.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

data "aws_iam_policy_document" "dashboard_public" {
  statement {
    sid     = "PublicRead"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.dashboard.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "dashboard" {
  bucket = aws_s3_bucket.dashboard.id
  policy = data.aws_iam_policy_document.dashboard_public.json
}

locals {
  dashboard_html = templatefile(
    "${path.module}/templates/dashboard.html.tpl",
    {
      get_leaderboard_url = aws_lambda_function_url.get_leaderboard.function_url
    }
  )
}

resource "aws_s3_object" "dashboard_index" {
  bucket       = aws_s3_bucket.dashboard.id
  key          = "index.html"
  content      = local.dashboard_html
  content_type = "text/html"

  etag = md5(local.dashboard_html)

  tags = local.tags
}
