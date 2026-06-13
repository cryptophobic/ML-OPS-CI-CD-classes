variable "aws_region" {
  description = "AWS region to deploy the VPC and EKS cluster into."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Named AWS CLI/SDK profile. Leave empty to use the default credential chain (env vars / IAM role)."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Short name prefix used for the VPC and EKS cluster resources."
  type        = string
  default     = "mlops-eks"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to spread subnets across (eu-central-1 has 3)."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 (EKS needs at least 2 AZs; eu-central-1 has 3)."
  }
}

variable "cluster_version" {
  description = "Kubernetes control-plane version for EKS."
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for the managed node groups."
  type        = string
  default     = "t3.medium"
}

variable "cpu_desired_size" {
  description = "Desired number of nodes in the CPU node group."
  type        = number
  default     = 2
}

variable "gpu_desired_size" {
  description = "Desired number of nodes in the (labelled) GPU node group."
  type        = number
  default     = 0
}