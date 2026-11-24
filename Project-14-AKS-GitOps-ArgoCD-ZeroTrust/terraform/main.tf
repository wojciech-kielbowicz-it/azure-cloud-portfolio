data "azurerm_client_config" "current" {}

# Obtain Spoke Compute Resource Group & AKS from Project-11
data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

data "azurerm_resources" "aks_clusters" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.ContainerService/managedClusters"
}

data "azurerm_kubernetes_cluster" "aks_compute" {
  name                = data.azurerm_resources.aks_clusters.resources[0].name
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

# Install ArgoCD via Helm (Zero Trust: ClusterIP only, no public IP)
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  timeout          = 600

  values = [
    <<-EOT
      server:
        service:
          type: ClusterIP
        extraArgs:
          - --insecure
      configs:
        params:
          server.insecure: true
      controller:
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
      repoServer:
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 250m
            memory: 256Mi
    EOT
  ]
}

# ArgoCD AppProject (Least Privilege Boundary)
resource "kubectl_manifest" "argocd_project" {
  yaml_body = <<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: AppProject
    metadata:
      name: zero-trust-project
      namespace: ${var.argocd_namespace}
    spec:
      description: "Zero Trust Application Project managed by GitOps"
      sourceRepos:
        - "${var.git_repo_url}"
      destinations:
        - namespace: "${var.k8s_namespace}"
          server: "https://kubernetes.default.svc"
      clusterResourceWhitelist:
        - group: ""
          kind: Namespace
  EOT

  depends_on = [helm_release.argocd]
}

# ArgoCD Application (GitOps Continuous Reconciliation)
resource "kubectl_manifest" "argocd_application" {
  yaml_body = <<-EOT
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: zero-trust-web-gitops
      namespace: ${var.argocd_namespace}
      finalizers:
        - resources-finalizer.argocd.argoproj.io
    spec:
      project: zero-trust-project
      source:
        repoURL: "${var.git_repo_url}"
        targetRevision: "${var.git_target_revision}"
        path: "${var.git_manifests_path}"
      destination:
        server: "https://kubernetes.default.svc"
        namespace: "${var.k8s_namespace}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  EOT

  depends_on = [kubectl_manifest.argocd_project]
}
