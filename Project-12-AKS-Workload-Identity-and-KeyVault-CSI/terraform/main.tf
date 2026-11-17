data "azurerm_client_config" "current" {}

# Obtain data from Hub and Spoke-Compute resources
data "azurerm_resource_group" "rg_hub" {
  name = "rg-network-hub"
}

data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

data "azurerm_virtual_network" "vnet_spoke_compute" {
  name                = "vnet-spoke-compute"
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

data "azurerm_subnet" "subnet_db" {
  name                 = "subnet-db"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_compute.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_compute.name
}

# Obtain AKS Cluster from Project-11
data "azurerm_resources" "aks_clusters" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.ContainerService/managedClusters"
}

data "azurerm_kubernetes_cluster" "aks_compute" {
  name                = data.azurerm_resources.aks_clusters.resources[0].name
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

# Obtain Private ACR from Project-11
data "azurerm_resources" "acr_compute" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.ContainerRegistry/registries"
}

resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Obtain Private DNS Zone for Azure Key Vault (Project-04)
data "azurerm_private_dns_zone" "dns_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

# Key Vault (RBAC Enabled, Public Access enabled for GitHub Actions runner secret seeding)
resource "azurerm_key_vault" "kv_compute" {
  name                          = "kvspokecompute${random_string.kv_suffix.result}"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.rg_spoke_compute.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = var.kv_sku
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  rbac_authorization_enabled    = true
  public_network_access_enabled = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow"
  }

  tags = {
    Env  = "Spoke-Compute"
    Role = "Key-Vault"
  }
}

# Key Vault Private Endpoint in subnet-db (10.3.3.0/24)
resource "azurerm_private_endpoint" "pe_kv" {
  name                = "pe-kv-spoke-compute"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  subnet_id           = data.azurerm_subnet.subnet_db.id

  private_service_connection {
    name                           = "psc-kv-spoke-compute"
    private_connection_resource_id = azurerm_key_vault.kv_compute.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.dns_kv.id]
  }
}

# Grant Deployment Identity Key Vault Secrets Officer RBAC to seed secrets
resource "azurerm_role_assignment" "spn_kv_secrets_officer" {
  scope                = azurerm_key_vault.kv_compute.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Zero Trust Secret stored in Key Vault
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "DatabaseConnectionString"
  value        = "Server=tcp:sql-zerotrust.database.windows.net,1433;Database=core;Authentication=Active Directory Workload Identity;"
  key_vault_id = azurerm_key_vault.kv_compute.id

  depends_on = [azurerm_role_assignment.spn_kv_secrets_officer]
}

# Managed Identity for AKS Pod Workload Identity
resource "azurerm_user_assigned_identity" "id_workload" {
  name                = "id-aks-workload-spoke-compute"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name

  tags = {
    Env  = "Spoke-Compute"
    Role = "Workload-Identity"
  }
}

# Passwordless Key Vault Secrets User RBAC for AKS Pod Identity
resource "azurerm_role_assignment" "workload_kv_secrets_user" {
  scope                = azurerm_key_vault.kv_compute.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.id_workload.principal_id
}

# OIDC Federated Identity Credential between AKS ServiceAccount and Azure Identity
resource "azurerm_federated_identity_credential" "fic_workload" {
  name                      = "fic-aks-workload-spoke-compute"
  user_assigned_identity_id = azurerm_user_assigned_identity.id_workload.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = data.azurerm_kubernetes_cluster.aks_compute.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.k8s_namespace}:${var.k8s_service_account_name}"
}

# Kubernetes Manifests Provisioning via Direct kubectl_manifest (Plan-Time Safe)
resource "kubectl_manifest" "sa_workload" {
  yaml_body = <<-EOT
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: ${var.k8s_service_account_name}
      namespace: ${var.k8s_namespace}
      annotations:
        azure.workload.identity/client-id: "${azurerm_user_assigned_identity.id_workload.client_id}"
      labels:
        azure.workload.identity/use: "true"
  EOT
}

resource "kubectl_manifest" "secret_provider_class" {
  yaml_body = <<-EOT
    apiVersion: secrets-store.csi.x-k8s.io/v1
    kind: SecretProviderClass
    metadata:
      name: azure-kvname-wi
      namespace: ${var.k8s_namespace}
    spec:
      provider: azure
      parameters:
        usePodIdentity: "false"
        clientID: "${azurerm_user_assigned_identity.id_workload.client_id}"
        keyvaultName: "${azurerm_key_vault.kv_compute.name}"
        cloudName: ""
        objects: |
          array:
            - |
              objectName: ${azurerm_key_vault_secret.db_connection_string.name}
              objectType: secret
              objectVersion: ""
        tenantId: "${data.azurerm_client_config.current.tenant_id}"
  EOT

  depends_on = [
    azurerm_key_vault_secret.db_connection_string,
    azurerm_role_assignment.workload_kv_secrets_user,
    azurerm_federated_identity_credential.fic_workload
  ]
}

resource "kubectl_manifest" "zero_trust_pod" {
  yaml_body = <<-EOT
    apiVersion: v1
    kind: Pod
    metadata:
      name: zero-trust-app-pod
      namespace: ${var.k8s_namespace}
      labels:
        azure.workload.identity/use: "true"
        app: zero-trust-demo
    spec:
      serviceAccountName: ${var.k8s_service_account_name}
      containers:
        - name: app-container
          image: "${data.azurerm_resources.acr_compute.resources[0].name}.azurecr.io/nginx:1.25"
          securityContext:
            allowPrivilegeEscalation: false
          volumeMounts:
            - name: secrets-store01-inline
              mountPath: "/mnt/secrets-store"
              readOnly: true
      volumes:
        - name: secrets-store01-inline
          csi:
            driver: secrets-store.csi.k8s.io
            readOnly: true
            volumeAttributes:
              secretProviderClass: "azure-kvname-wi"
  EOT

  depends_on = [
    kubectl_manifest.sa_workload,
    kubectl_manifest.secret_provider_class,
    azurerm_private_endpoint.pe_kv
  ]
}
