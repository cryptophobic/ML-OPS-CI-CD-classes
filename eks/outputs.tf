output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_security_group_id" {
  description = "Cluster security group ID created by the EKS module."
  value       = module.eks.cluster_security_group_id
}

output "node_group_names" {
  description = "Names of the managed node groups."
  value       = keys(module.eks.eks_managed_node_groups)
}