resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "fluentlabs-prod"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count = 3

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  vpc_id            = aws_vpc.main.id

  # Required so that the nodes can join the kubernetes cluster
  map_public_ip_on_launch = true

  tags = {
    Name                                                       = "fluentlabs-public-${count.index}"
    "kubernetes.io/cluster/fluentlabsprod" = "shared"
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

resource "aws_eks_cluster" "fluentlabs" {
  name     = "fluentlabsprod"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.21.2"

  vpc_config {
    subnet_ids = aws_subnet.public[*].id
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_controller,
  ]
}

resource "aws_iam_role" "service_workers" {
  name = "eks-node-group-service"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.service_workers.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_worker" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.service_workers.name
}

# This policy is mandatory from AWS so don't remove it.
resource "aws_iam_role_policy_attachment" "eks_container_read_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.service_workers.name
}

resource "aws_eks_node_group" "services" {
  cluster_name    = aws_eks_cluster.fluentlabs.name
  node_group_name = "services"
  node_role_arn   = aws_iam_role.service_workers.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = 1
    max_size     = 5
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy_worker,
    aws_iam_role_policy_attachment.eks_container_read_policy,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}