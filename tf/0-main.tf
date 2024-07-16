
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/24"
  tags = merge(
      local.common_tags,
      { version = "1" }
    )
}

# 2 public subnets
# 2 private subnets
# internet gw
# nat
# eip
# route table
# ECR registry
# EKS
# node pool
# IAM role binding
