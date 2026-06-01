terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS provider is configured once here, at the root, and is inherited by the
# ./vpc and ./eks child modules (criterion #6 — provider works via profile or IAM).
provider "aws" {
  region = var.aws_region

  # Empty var.aws_profile => use the default credential chain
  # (env vars / shared credentials / IAM role). Set it to use a named profile.
  profile = var.aws_profile != "" ? var.aws_profile : null
}