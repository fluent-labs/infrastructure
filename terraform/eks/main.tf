resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_one" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "fluentlabs-public-1"
  }
}

resource "aws_subnet" "public_two" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "fluentlabs-public-2"
  }
}

resource "aws_subnet" "public_three" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "fluentlabs-public-3"
  }
}

# Permissions for K8s cluster go below here.
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_controller" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# resource "aws_eks_cluster" "fluentlabs" {
#   name     = "fluentlabs-prod"
#   role_arn = aws_iam_role.eks_cluster_role.arn

#   vpc_config {
#     subnet_ids = [aws_subnet.example1.id, aws_subnet.example2.id]
#   }

#   depends_on = [
#     aws_iam_role_policy_attachment.eks_role_attach,
#     aws_iam_role_policy_attachment.eks_vpc_controller,
#   ]
# }