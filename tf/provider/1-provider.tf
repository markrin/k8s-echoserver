provider "aws" {
  # alias = "region"
  default_tags {
    tags = {
        Name = "Mark"
        Owner = "Nati"
        Department = "DevOps"
        Temp = "True"
    }
  }
}

# data "aws_region" "current" {
#   provider = aws.region
# }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
  required_version = ">= 1.2"
  # COMMENT BEFORE FIRST APPLY AND UNCOMMENT AFTER
  # backend "s3" {
  #   bucket         = "markr-test-assignment-tf-state"
  #   key            = "terraform.tfstate"
  #   dynamodb_table = "markr-terraform-state-locking"
  #   encrypt        = true
  # }
  backend "local" {}
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = "markr-test-assignment-tf-state"
  force_destroy = true
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_bucket_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state_crypto_conf" {
  bucket = aws_s3_bucket.terraform_state.bucket 
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = "markr-terraform-state-locking"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  lifecycle {
    prevent_destroy = true
  }
}
