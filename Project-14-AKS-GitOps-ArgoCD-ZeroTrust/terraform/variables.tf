variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD control plane"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "Official ArgoCD Helm chart version"
  type        = string
  default     = "7.7.10"
}

variable "k8s_namespace" {
  description = "Target Kubernetes namespace for Zero Trust Web App"
  type        = string
  default     = "default"
}

variable "git_repo_url" {
  description = "HTTPS URL of the GitHub repository tracked by ArgoCD"
  type        = string
  default     = "https://github.com/wojciech-kielbowicz-it/azure-cloud-portfolio.git"
}

variable "git_target_revision" {
  description = "Git branch tracked by ArgoCD"
  type        = string
  default     = "main"
}

variable "git_manifests_path" {
  description = "Path inside the repository containing Kubernetes manifests"
  type        = string
  default     = "Project-14-AKS-GitOps-ArgoCD-ZeroTrust/k8s-manifests/base"
}
