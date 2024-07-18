
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { version = "1" }
}

resource "aws_subnet" "private-az1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = local.az_list[0]
}

resource "aws_subnet" "private-az2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = local.az_list[1]
}

resource "aws_subnet" "public-az1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = local.az_list[0]
  # map_public_ip_on_launch = true
  tags = { "kubernetes.io/role/elb" = "1" }
}

resource "aws_subnet" "public-az2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = local.az_list[1]
  # map_public_ip_on_launch = true
  tags = { "kubernetes.io/role/elb" = "1" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "nat" {
  # domain = "vpc"
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-az1.id

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      nat_gateway_id             = aws_nat_gateway.nat.id
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      gateway_id                 = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]

}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route = [
    {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.igw.id
      nat_gateway_id             = ""
      carrier_gateway_id         = ""
      destination_prefix_list_id = ""
      egress_only_gateway_id     = ""
      instance_id                = ""
      ipv6_cidr_block            = ""
      local_gateway_id           = ""
      network_interface_id       = ""
      transit_gateway_id         = ""
      vpc_endpoint_id            = ""
      vpc_peering_connection_id  = ""
    },
  ]


}

resource "aws_route_table_association" "private-az1" {
  subnet_id      = aws_subnet.private-az1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-az2" {
  subnet_id      = aws_subnet.private-az2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public-az1" {
  subnet_id      = aws_subnet.public-az1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-az2" {
  subnet_id      = aws_subnet.public-az2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_ecr_repository" "repo" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

}

data "aws_iam_policy_document" "ecr_policy" {
  statement {
    sid       = "AllowPushPull"
    effect    = "Allow"
    actions   = ["ecr:*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.arn]
    }
  }

  statement {
    sid       = "AllowEksToPullImages"
    effect    = "Allow"
    actions   = ["ecr:GetDownloadUrlForLayer",
                 "ecr:BatchGetImage",
                 "ecr:BatchCheckLayerAvailability",
                 "ecr:BatchGetImage",
                 "ecr:DescribeImages",
                 "ecr:DescribePullThroughCacheRules",
                 "ecr:DescribeRegistry",
                 "ecr:DescribeRepositories",
                 "ecr:GetAuthorizationToken",
                 "ecr:ListImages"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.eks_workers_role_name}"]
    }
  }
}

resource "aws_ecr_repository_policy" "attach_policy_1" {
  repository = aws_ecr_repository.repo.name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}

resource "aws_iam_role" "eks_master_role" {
  name = "eks-control-plane-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "policy-attachment-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_master_role.name
}


resource "aws_eks_cluster" "cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_master_role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.private-az1.id,
      aws_subnet.private-az2.id,
      aws_subnet.public-az1.id,
      aws_subnet.public-az2.id
    ]
  }

  depends_on = [aws_iam_role_policy_attachment.policy-attachment-AmazonEKSClusterPolicy]
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "workers-role" {
  name = local.eks_workers_role_name

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

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.workers-role.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.workers-role.name
}

resource "aws_iam_role_policy_attachment" "nodes-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.workers-role.name
}

resource "aws_eks_node_group" "private-nodes" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "private-nodes"
  node_role_arn   = aws_iam_role.workers-role.arn

  subnet_ids = [
    aws_subnet.private-az1.id,
    aws_subnet.private-az2.id
  ]

  instance_types = [ var.workers_instance_type ]

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "general"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.nodes-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes-AmazonEC2ContainerRegistryReadOnly,
  ]
}


# ECR registry (and access policy) +-
# EKS (oidc, cert) +
# node pool +
# IAM service role binding
# helm deploy
