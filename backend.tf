# ---------------------------------------------------------------------------
# Terraform state backend
#
# DEFAULT: local state (./terraform.tfstate). The project runs with ZERO
# pre-setup and `terraform destroy` can never delete the bucket holding its
# own state (the problem the task warns about).
# ---------------------------------------------------------------------------
terraform {
  backend "local" {}
}

# ---------------------------------------------------------------------------
# OPTIONAL: remote S3 backend.
#
# To switch:
#   1. Create the bucket FIRST (it must exist before `terraform init`):
#        aws s3api create-bucket \
#          --bucket my-tfstate-bucket-<unique-suffix> \
#          --region eu-central-1 \
#          --create-bucket-configuration LocationConstraint=eu-central-1
#   2. Comment out the `backend "local" {}` block above.
#   3. Uncomment the block below, set a globally-unique bucket name.
#   4. Run: terraform init -migrate-state
#
# Keep this bucket OUT of `terraform destroy` (don't manage it in this config)
# so destroying the cluster never wipes your state.
#
# terraform {
#   backend "s3" {
#     bucket       = "my-tfstate-bucket-<unique-suffix>"
#     key          = "eks-vpc-cluster/terraform.tfstate"
#     region       = "eu-central-1"
#     encrypt      = true
#     use_lockfile = true # native S3 locking (Terraform >= 1.10); no DynamoDB needed
#   }
# }
# ---------------------------------------------------------------------------