# This directory is consumed as a LOCAL child module (source = "./eks") from the
# root configuration, so it does NOT declare its own backend — Terraform state
# is owned by the root module (see ../backend.tf). A `backend` block here would
# be ignored by Terraform.
#
# This file exists to match the required project structure.
#
# ---------------------------------------------------------------------------
# Note on `data.terraform_remote_state` (mentioned in the task's step #2):
#
# We chose the LOCAL child-module composition, so EKS receives the VPC outputs
# directly through module inputs (see ../main.tf) — no remote state needed and
# a single `terraform apply` builds everything.
#
# If you split this into a standalone state instead, you would read the VPC
# from S3 like this (and remove the vpc_id / subnet_ids variables):
#
#   data "terraform_remote_state" "vpc" {
#     backend = "s3"
#     config = {
#       bucket = "my-tfstate-bucket-<unique-suffix>"
#       key    = "eks-vpc-cluster/vpc/terraform.tfstate"
#       region = "eu-central-1"
#     }
#   }
#
#   # then: vpc_id    = data.terraform_remote_state.vpc.outputs.vpc_id
#   #       subnet_ids = data.terraform_remote_state.vpc.outputs.private_subnet_ids
# ---------------------------------------------------------------------------