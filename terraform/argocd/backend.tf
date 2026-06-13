# ---------------------------------------------------------------------------
# State backend for the ArgoCD layer.
#
# DEFAULT: local state (terraform/argocd/terraform.tfstate). Kept SEPARATE from
# the root VPC/EKS state so the two layers can be applied and destroyed
# independently (apply EKS first, then this; destroy this first, then EKS).
# ---------------------------------------------------------------------------
terraform {
  backend "local" {}
}

# ---------------------------------------------------------------------------
# OPTIONAL: remote S3 backend (use a DIFFERENT key from the root config so the
# two states never collide).
#
# terraform {
#   backend "s3" {
#     bucket       = "my-tfstate-bucket-<unique-suffix>"
#     key          = "eks-argocd/terraform.tfstate"
#     region       = "eu-central-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
# ---------------------------------------------------------------------------