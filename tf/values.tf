
# vars.region set automatically by provider

variable "env" {
  type        = string
  default     = "internal"
}

locals {
    common_tags = {
        Name = "Mark"
        Owner = "Nati"
        Department = "DevOps"
        Temp = "True"
    }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_list = data.aws_availability_zones.available.names
}