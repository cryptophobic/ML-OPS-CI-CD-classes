# ---------------------------------------------------------------------------
# Providers for the ArgoCD layer.
#
# This is a SEPARATE Terraform root from the VPC/EKS config at the repo root.
# The cluster must already exist (terraform apply at the repo root) before this
# layer is applied. We discover the running cluster with data sources instead
# of wiring module outputs — that avoids the "chicken-and-egg" problem where the
# helm/kubernetes providers need a live API endpoint that does not exist yet on
# the very first apply.
# ---------------------------------------------------------------------------

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null
}

# Look up the cluster that the root config created.
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}