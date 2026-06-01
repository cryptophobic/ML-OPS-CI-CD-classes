output "argocd_namespace" {
  description = "Namespace ArgoCD is installed in."
  value       = kubernetes_namespace.infra_tools.metadata[0].name
}

output "argocd_release_name" {
  description = "Helm release name for ArgoCD."
  value       = helm_release.argocd.name
}

output "argocd_chart_version" {
  description = "Deployed argo-cd chart version."
  value       = helm_release.argocd.version
}

output "argocd_server_service" {
  description = "ClusterIP Service exposing the ArgoCD API/UI."
  value       = "${helm_release.argocd.name}-server"
}

output "port_forward_command" {
  description = "Open the ArgoCD UI locally."
  value       = "kubectl port-forward svc/${helm_release.argocd.name}-server -n ${var.namespace} 8080:443"
}

output "initial_admin_password_command" {
  description = "Fetch the auto-generated initial admin password."
  value       = "kubectl -n ${var.namespace} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}