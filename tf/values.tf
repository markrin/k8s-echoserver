
# vars.region set automatically by provider

variable "env" {
  type        = string
  default     = "internal"
  nullable = false
}

variable "cluster_name" {
  type = string
  default = "mark-assignment"
}

variable "ecr_repo_name" {
  type = string
  default = "mark-pyecho"
}

variable "workers_instance_type" {
  type = string
  default = "t3.small"
}

locals {
    common_tags = {
        Name = "Mark"
        Owner = "Nati"
        Department = "DevOps"
        Temp = "True"
    }
    eks_workers_role_name = "eks_workers_role"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  az_list = data.aws_availability_zones.available.names
}