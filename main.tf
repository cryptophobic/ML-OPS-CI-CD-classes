data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # First N AZs available in the region.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Derive subnet CIDRs from the VPC CIDR: one /24 per AZ.
  #   private: 10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24
  #   public : 10.0.100.0/24, 10.0.101.0/24, 10.0.102.0/24
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 8, i + 100)]

  cluster_name = "${var.project_name}-cluster"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Lesson    = "lesson-8-9"
  }
}

# --- VPC --------------------------------------------------------------------
module "vpc" {
  source = "./vpc"

  name            = "${var.project_name}-vpc"
  cidr            = var.vpc_cidr
  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  tags = local.common_tags
}

# --- EKS (consumes VPC outputs directly) ------------------------------------
module "eks" {
  source = "./eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  node_instance_type = var.node_instance_type
  cpu_desired_size   = var.cpu_desired_size

  tags = local.common_tags
}