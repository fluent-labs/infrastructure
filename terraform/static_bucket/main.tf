terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "2.21.0"
    }
  }
}

locals {
  full_domain = "${var.subdomain}.${var.domain}"
}

resource "aws_s3_bucket" "main" {
  bucket = local.full_domain
}

resource "aws_s3_bucket_website_configuration" "main" {
  bucket = aws_s3_bucket.main.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_acl" "main_acl" {
  bucket = aws_s3_bucket.main.bucket
  acl    = "public-read"
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
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.full_domain

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  ordered_cache_behavior {
    path_pattern     = "*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.full_domain

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = var.certificate_arn
    ssl_support_method  = "sni-only"
  }
}

data "aws_route53_zone" "main" {
  name = var.domain
}

resource "aws_route53_record" "subdomain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.fluentlabs.io"
  type    = "CNAME"
  ttl     = "3600"
  records = [aws_cloudfront_distribution.s3_distribution.domain_name]
}

data "aws_iam_policy_document" "deploy" {
  statement {
    actions   = ["s3:DeleteObject", "s3:GetBucketLocation", "s3:GetObject", "s3:ListBucket", "s3:PutObject", "s3:PutBucketWebsite", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
    effect    = "Allow"
    resources = [aws_s3_bucket.main.arn, "${aws_s3_bucket.main.arn}/*"]
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
