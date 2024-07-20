
data "aws_region" "current" {}

variable "env" {
  type        = string
  default     = "int"
  nullable = false
}

variable "cluster_name" {
  type = string
  default = "pyecho-cluster"
}

variable "app_name" {
  type = string
  default = "pyecho"
}

variable "workers_instance_type" {
  type = string
  default = "t3.medium"
}

variable "helm_release_version" {
  type = string
  default = "1.0.0"
}

locals {
    common_tags = {
        Name = "Mark"
        Owner = "Nati"
        Department = "DevOps"
        Temp = "True"
    }
    eks_workers_role_name = "eks_worker_role"
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  az_list = data.aws_availability_zones.available.names
}