
#remote_state {
#  backend = "s3"
#  config = {
#    bucket         = "markr-test-assignment-tf-state"
#    key            = "terraform.tfstate"
#    dynamodb_table = "markr-terraform-state-locking"
#    encrypt        = true
#    region         = local.aws_region
#  }
#}

locals {
  aws_region = "eu-central-1"
}

remote_state {
#   backend = "s3"  # explicit deny on s3 put policy and block public access
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    # bucket = "pyecho-terraform-state"

    # key = "${path_relative_to_include()}/terraform.tfstate"
    # region         = local.aws_region
    # encrypt        = true
    # dynamodb_table = "pyecho-lock-table"
  }
}
