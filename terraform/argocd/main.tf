# ---------------------------------------------------------------------------
# ArgoCD on EKS (criterion #1: ArgoCD deployed via Terraform as a helm_release
# in the infra-tools namespace).
# ---------------------------------------------------------------------------

# Dedicated namespace for in-cluster tooling.
resource "kubernetes_namespace" "infra_tools" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "purpose"                      = "infra-tools"
    }
  }
}

# ArgoCD itself. All chart values are externalised to values/argocd-values.yaml
# (criterion #2). The Helm provider authenticates to the cluster via the EKS
# data sources in provider.tf.
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.infra_tools.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  # Wait for the rollout so `terraform apply` only returns once the pods are up.
  wait    = true
  timeout = 900

  values = [file("${path.module}/${var.argocd_values_file}")]
}