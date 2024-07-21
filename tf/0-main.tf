
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { version = "1" }
}

resource "aws_subnet" "private-az1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = local.az_list[0]
  tags = { "kubernetes.io/role/internal-elb" = "1" }
}

resource "aws_subnet" "private-az2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = local.az_list[1]
  tags = { "kubernetes.io/role/internal-elb" = "1" }
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
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public-az1.id

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  route {
      cidr_block                 = "0.0.0.0/0"
      nat_gateway_id             = aws_nat_gateway.nat.id
    }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
      cidr_block                 = "0.0.0.0/0"
      gateway_id                 = aws_internet_gateway.igw.id
    }
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
  name                 = var.app_name
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

  depends_on = [ aws_eks_node_group.private-nodes ]
}

resource "aws_ecr_repository_policy" "attach_policy_1" {
  repository = aws_ecr_repository.repo.name
  policy     = data.aws_iam_policy_document.ecr_policy.json
}

resource "aws_iam_role" "eks_master_role" {
  name = "eks-master-role"

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

resource "aws_iam_role_policy_attachment" "policy-attachment-ecr-readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
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

# commented due vpcId not set and instance metadata access not configured
# module "eks_blueprints_addons" {
#   source = "aws-ia/eks-blueprints-addons/aws"
#   version = "~> 1.0"

#   cluster_name      = aws_eks_cluster.cluster.name
#   cluster_endpoint  = aws_eks_cluster.cluster.endpoint
#   cluster_version   = aws_eks_cluster.cluster.version
#   oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn

#   enable_aws_load_balancer_controller    = true
# }

# https://medium.com/@StephenKanyiW/provision-eks-with-terraform-helm-and-a-load-balancer-controller-821dacb35066
module "lb_role" {
 source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

 role_name                              = "${var.cluster_name}_eks_lb"
 attach_load_balancer_controller_policy = true

 oidc_providers = {
     main = {
     provider_arn               = aws_iam_openid_connect_provider.eks.arn
     namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
     }
 }
}

provider "kubernetes" {
    host                   = aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
    # token = data.aws_eks_cluster_auth.this.token
    exec {
        api_version = "client.authentication.k8s.io/v1beta1"
        args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.cluster.id]
        command     = "aws"
    }
}

resource "kubernetes_service_account" "service-account" {
    provider = kubernetes
    metadata {
        name      = "aws-load-balancer-controller"
        namespace = "kube-system"
        labels = {
        "app.kubernetes.io/name"      = "aws-load-balancer-controller"
        "app.kubernetes.io/component" = "controller"
        }
        annotations = {
        "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
        "eks.amazonaws.com/sts-regional-endpoints" = "true"
        }
    }
}

resource "helm_release" "alb-controller" {
    provider = helm
    name       = "aws-load-balancer-controller"
    repository = "https://aws.github.io/eks-charts"
    chart      = "aws-load-balancer-controller"
    namespace  = "kube-system"
    depends_on = [
        kubernetes_service_account.service-account
    ]

    set {
        name  = "region"
        value = data.aws_region.current.id
    }
    set {
        name  = "vpcId"
        value = aws_vpc.vpc.id
    }
    set {
        name  = "image.repository"
        value = "public.ecr.aws/eks/aws-load-balancer-controller"
    }
    set {
        name  = "serviceAccount.create"
        value = "false"
    }
    set {
        name  = "serviceAccount.name"
        value = "aws-load-balancer-controller"
    }
    set {
        name  = "clusterName"
        value = var.cluster_name
    }
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

# resource "aws_security_group_rule" "internet-to-alb" {
#   security_group_id = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
#   from_port = 80
#   to_port = 80
#   protocol = "tcp"
#   type = "ingress"
#   cidr_blocks = [ "0.0.0.0/0" ]
# }

data "aws_eks_cluster_auth" "this" {
  name = aws_eks_cluster.cluster.id
}

data "aws_ecr_authorization_token" "token" {
  registry_id = aws_ecr_repository.repo.registry_id
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.cluster.certificate_authority[0].data)
    # token = data.aws_eks_cluster_auth.this.token
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.cluster.id]
      command     = "aws"
    }
  }
  registry {
    url = "oci://${aws_ecr_repository.repo.repository_url}"
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

resource "helm_release" "pyecho" {
  name = "pyecho"

  repository = "oci://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.id}.amazonaws.com"
  chart      = "mark-pyecho"
  namespace  = "default"
  version    = var.helm_release_version

  set {
    name  = "env"
    value = var.env
  }
  set {
    name = "account_id"
    value = data.aws_caller_identity.current.account_id
  }
  set {
    name = "region"
    value = data.aws_region.current.id
  }

  depends_on = [aws_eks_node_group.private-nodes]
}

# data "kubernetes_service" "ingress" {
#   metadata {
#     name      = "ingress"
#     namespace = helm_release.pyecho.namespace
#   }
# }