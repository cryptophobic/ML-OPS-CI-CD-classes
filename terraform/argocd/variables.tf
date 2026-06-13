variable "aws_region" {
  description = "AWS region the EKS cluster lives in (must match the root config)."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "Named AWS CLI/SDK profile. Empty => default credential chain."
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name of the existing EKS cluster to deploy ArgoCD into. Must match the root config's output (project_name-cluster)."
  type        = string
  default     = "mlops-eks-cluster"
}

variable "namespace" {
  description = "Namespace ArgoCD is installed into."
  type        = string
  default     = "infra-tools"
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart (argoproj.github.io/argo-helm)."
  type        = string
  default     = "9.5.15"
}

variable "argocd_values_file" {
  description = "Path to the Helm values file for the ArgoCD release."
  type        = string
  default     = "values/argocd-values.yaml"
}