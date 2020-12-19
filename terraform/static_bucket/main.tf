locals {
  full_domain = "${var.subdomain}.${var.domain}"
}

data "digitalocean_domain" "main" {
  name = var.domain
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "main" {
  bucket = local.full_domain
  acl    = "public-read"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

# TODO add push permissions to the deploy user

resource "aws_s3_bucket_policy" "public_access" {
  bucket = aws_s3_bucket.main.id

  policy = <<POLICY
{
    "Version": "2008-10-17",
    "Id": "PolicyForPublicWebsiteContent",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "${aws_s3_bucket.main.arn}/*"
        }
    ]
}
POLICY
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.main.bucket_regional_domain_name
    origin_id   = local.full_domain
  }

  enabled             = true
  default_root_object = "index.html"

  aliases = [local.full_domain]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.full_domain

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = "arn:aws:acm:us-east-1:${data.aws_caller_identity.current.account_id}:certificate/23bf2e3d-1934-4470-a27d-05f3847a5ef2"
    ssl_support_method  = "sni-only"
  }
}

resource "digitalocean_record" "subdomain" {
  domain = data.digitalocean_domain.main.name
  type   = "CNAME"
  name   = var.subdomain
  value  = "${aws_cloudfront_distribution.s3_distribution.domain_name}."
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions   = ["s3:DeleteObject", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:PutObject"]
    effect    = "Allow"
    resources = ["${aws_s3_bucket.main.arn}/*"]
  }
  statement {
    actions   = ["cloudfront:CreateInvalidation"]
    effect    = "Allow"
    resources = [aws_cloudfront_distribution.s3_distribution.arn]
  }
}

resource "aws_iam_policy" "deploy" {
  name        = "${local.full_domain}-deploy-role"
  description = "IAM policy for deploying to ${local.full_domain}"

  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_policy_attachment" "deploy" {
  name       = "${local.full_domain}-deploy-role-attach"
  users      = var.deploy_users
  policy_arn = aws_iam_policy.deploy.arn
}
