locals {
  shared_tags = {
    Terraform   = "true"
    Environment = var.env
    Repo        = var.aws_repo
  }
}

terraform {
  required_version = ">= 1.2.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.22.0"
    }
  }
}

data "aws_caller_identity" "current" {}
