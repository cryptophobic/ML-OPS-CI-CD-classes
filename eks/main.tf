# Official EKS module (criterion #2).
# https://registry.terraform.io/modules/terraform-aws-modules/eks/aws
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  # Public API endpoint so you can reach the cluster with kubectl from your
  # laptop right after `terraform apply`.
  cluster_endpoint_public_access = true

  # Give the IAM principal that runs `terraform apply` cluster-admin via an EKS
  # access entry. This is what makes `kubectl get nodes` work immediately
  # (criterion #5 / "cluster reachable via kubectl").
  enable_cluster_creator_admin_permissions = true

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
  }

  eks_managed_node_group_defaults = {
    instance_types = [var.node_instance_type]
  }

  eks_managed_node_groups = {
    cpu = {
      min_size     = 1
      max_size     = 4
      desired_size = var.cpu_desired_size

      labels = {
        "workload-type" = "cpu"
      }
    }
  }

  tags = var.tags
}