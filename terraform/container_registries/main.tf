# Read only pull user for K8s

resource "aws_iam_access_key" "kubernetes" {
  user = aws_iam_user.kubernetes.name
}

resource "aws_iam_user" "kubernetes" {
  name = "foreign-language-reader-kubernetes"
}

# Give K8s credentials

data "aws_caller_identity" "current" {}

resource "kubernetes_secret" "kubernetes_user_secret" {
  metadata {
    name = "aws"
  }

  data = {
    AWS_ACCOUNT_NUMBER    = data.aws_caller_identity.current.account_id
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.kubernetes.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.kubernetes.secret
  }
}

# Generic policy attachment allowing auth against ECR

data "aws_iam_policy_document" "ecr_user" {
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    effect    = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_user" {
  name        = "ecr-user"
  description = "IAM policy for getting access to ECR"

  policy = data.aws_iam_policy_document.ecr_user.json
}

resource "aws_iam_policy_attachment" "ecr_user_attach" {
  name       = "ecr_user"
  users      = concat(var.push_users, [aws_iam_user.kubernetes.name])
  policy_arn = aws_iam_policy.ecr_user.arn
}

# Container registries for use in this app.

module "api_registry" {
  source      = "./container_registry"
  name        = "foreign-language-reader-api"
  image_count = 5
  push_users  = var.push_users
  pull_users  = [aws_iam_user.kubernetes.name]
}

module "content_jobs" {
  source      = "./container_registry"
  name        = "foreign-language-reader-content-jobs"
  image_count = 10
  push_users  = var.push_users
  pull_users  = [aws_iam_user.kubernetes.name]
}

module "language_service_registry" {
  source      = "./container_registry"
  name        = "foreign-language-reader-language-service"
  image_count = 5
  push_users  = var.push_users
  pull_users  = [aws_iam_user.kubernetes.name]
}

# ECR credentials
# Used to be able to pull images from ECR
# Sadly is namespaced so will need two configurations.

resource "helm_release" "ecr_cred_refresher_default" {
  for_each = toset(var.kubernetes_namespaces)

  name       = "ecr-cred-refresher-${each.value}"
  repository = "https://architectminds.github.io/helm-charts/"
  chart      = "aws-ecr-credential"
  version    = "1.4.2"

  set_sensitive {
    name  = "aws.account"
    value = data.aws_caller_identity.current.account_id
  }
  set {
    name  = "aws.region"
    value = "us-west-2"
  }
  set_sensitive {
    name  = "aws.accessKeyId"
    value = base64encode(aws_iam_access_key.kubernetes.id)
  }
  set_sensitive {
    name  = "aws.secretAccessKey"
    value = base64encode(aws_iam_access_key.kubernetes.secret)
  }
  set {
    name  = "targetNamespace"
    value = each.value
  }
}
