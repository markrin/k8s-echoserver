
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

