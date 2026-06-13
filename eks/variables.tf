variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes control-plane version."
  type        = string
  default     = "1.31"
}

variable "vpc_id" {
  description = "ID of the VPC the cluster runs in."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the EKS worker nodes (private subnets)."
  type        = list(string)
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

variable "tags" {
  description = "Tags applied to all EKS resources."
  type        = map(string)
  default     = {}
}