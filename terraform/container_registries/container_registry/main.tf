resource "aws_ecr_repository" "repository" {
  name                 = var.name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "clean_up_container_registry" {
  repository = aws_ecr_repository.repository.name

  policy = <<EOF
{
  "rules": [
    {
      "action": {
        "type": "expire"
      },
      "selection": {
        "countType": "imageCountMoreThan",
        "countNumber": ${var.image_count},
        "tagStatus": "any"
      },
      "description": "Only keep the last ${var.image_count} images",
      "rulePriority": 1
    }
  ]
}
EOF
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "pull_access" {
  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:GetRepositoryPolicy", "ecr:DescribeRepositories", "ecr:ListImages", "ecr:DescribeImages", "ecr:BatchGetImage", "ecr:GetLifecyclePolicy", "ecr:GetLifecyclePolicyPreview", "ecr:ListTagsForResource", "ecr:DescribeImageScanFindings"]
    effect    = "Allow"
    resources = ["arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.name}"]
  }
}

resource "aws_iam_policy" "pull_access" {
  name        = "${var.name}-pull-role"
  description = "IAM policy for pulling containers from ${var.name}"

  policy = data.aws_iam_policy_document.pull_access.json
}

resource "aws_iam_policy_attachment" "pull_attach" {
  name       = "${var.name}-pull-role-attach"
  users      = var.pull_users
  policy_arn = aws_iam_policy.pull_access.arn
}

data "aws_iam_policy_document" "push_access" {
  statement {
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:GetDownloadUrlForLayer", "ecr:GetRepositoryPolicy", "ecr:DescribeRepositories", "ecr:ListImages", "ecr:DescribeImages", "ecr:BatchGetImage", "ecr:GetLifecyclePolicy", "ecr:GetLifecyclePolicyPreview", "ecr:ListTagsForResource", "ecr:DescribeImageScanFindings", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"]
    effect    = "Allow"
    resources = ["arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.name}"]
  }
}

resource "aws_iam_policy" "push_access" {
  name        = "${var.name}-push-role"
  description = "IAM policy for pushing containers to ${var.name}"

  policy = data.aws_iam_policy_document.push_access.json
}

resource "aws_iam_policy_attachment" "push_attach" {
  name       = "${var.name}-push-role-attach"
  users      = var.push_users
  policy_arn = aws_iam_policy.push_access.arn
}
