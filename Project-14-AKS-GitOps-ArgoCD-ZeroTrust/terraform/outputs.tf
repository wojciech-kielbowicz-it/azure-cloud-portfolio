output "argocd_namespace" {
  description = "Kubernetes namespace where ArgoCD is deployed"
  value       = var.argocd_namespace
}

output "argocd_application_name" {
  description = "Name of the bootstrapped ArgoCD Application"
  value       = "zero-trust-web-gitops"
}

output "argocd_ui_port_forward" {
  description = "Command to securely access ArgoCD UI locally"
  value       = "kubectl port-forward svc/argocd-server -n ${var.argocd_namespace} 8080:80"
}
