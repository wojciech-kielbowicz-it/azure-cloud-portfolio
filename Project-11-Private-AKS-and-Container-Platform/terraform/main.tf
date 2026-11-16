data "azurerm_client_config" "current" {}

# Obtain data from Project-01 and Project-03 resources
data "azurerm_resource_group" "rg_onprem" {
  name = "rg-onpremises"
}

data "azurerm_virtual_network" "vnet_onprem" {
  name                = "vnet-onpremises"
  resource_group_name = data.azurerm_resource_group.rg_onprem.name
}

data "azurerm_resource_group" "rg_hub" {
  name = "rg-network-hub"
}

data "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_resource_group" "rg_spoke_ai" {
  name = "rg-spoke-ai-data"
}

data "azurerm_virtual_network" "vnet_spoke_ai" {
  name                = "vnet-spoke-ai-data"
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
}

data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

data "azurerm_virtual_network" "vnet_spoke_compute" {
  name                = "vnet-spoke-compute"
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

data "azurerm_subnet" "subnet_api" {
  name                 = "subnet-api"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_compute.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_compute.name
}

data "azurerm_subnet" "subnet_db" {
  name                 = "subnet-db"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_compute.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_compute.name
}

# Obtain Log Analytics Workspace from Project-05
data "azurerm_resources" "law_hub" {
  type = "Microsoft.OperationalInsights/workspaces"
}

resource "random_string" "acr_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Private DNS Zone for Azure Container Registry
resource "azurerm_private_dns_zone" "dns_acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = data.azurerm_resource_group.rg_hub.name

  tags = {
    Env  = "Network"
    Role = "DNS"
  }
}

# Private DNS connection to all VNets
resource "azurerm_private_dns_zone_virtual_network_link" "link_acr_hub" {
  name                = "link-dns-acr-to-hub"
  private_dns_zone_id = azurerm_private_dns_zone.dns_acr.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_acr_spoke_compute" {
  name                = "link-dns-acr-to-spoke-compute"
  private_dns_zone_id = azurerm_private_dns_zone.dns_acr.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_spoke_compute.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_acr_spoke_ai" {
  name                = "link-dns-acr-to-spoke-ai"
  private_dns_zone_id = azurerm_private_dns_zone.dns_acr.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_spoke_ai.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_acr_onprem" {
  name                = "link-dns-acr-to-onprem"
  private_dns_zone_id = azurerm_private_dns_zone.dns_acr.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_onprem.id
}

# Private Azure Container Registry (No Admin User, No Public Access)
resource "azurerm_container_registry" "acr_compute" {
  name                          = "acrspokecompute${random_string.acr_suffix.result}"
  resource_group_name           = data.azurerm_resource_group.rg_spoke_compute.name
  location                      = var.location
  sku                           = var.acr_sku
  admin_enabled                 = false
  public_network_access_enabled = false
  zone_redundancy_enabled       = true
  network_rule_bypass_option    = "AzureServices"

  tags = {
    Env  = "Spoke-Compute"
    Role = "Container-Registry"
  }
}

# ACR Private Endpoint in subnet-db (10.3.3.0/24)
resource "azurerm_private_endpoint" "pe_acr" {
  name                = "pe-acr-spoke-compute"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  subnet_id           = data.azurerm_subnet.subnet_db.id

  private_service_connection {
    name                           = "psc-acr-spoke-compute"
    private_connection_resource_id = azurerm_container_registry.acr_compute.id
    is_manual_connection           = false
    subresource_names              = ["registry"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_acr.id]
  }
}

# Managed Identity for AKS Control Plane
resource "azurerm_user_assigned_identity" "id_aks" {
  name                = "id-aks-spoke-compute"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name

  tags = {
    Env  = "Spoke-Compute"
    Role = "Identity"
  }
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = data.azurerm_virtual_network.vnet_spoke_compute.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.id_aks.principal_id
}

# Azure Kubernetes Service (AKS) in subnet-api (10.3.2.0/24)
resource "azurerm_kubernetes_cluster" "aks_compute" {
  name                      = "aks-spoke-compute-${random_string.acr_suffix.result}"
  location                  = var.location
  resource_group_name       = data.azurerm_resource_group.rg_spoke_compute.name
  dns_prefix                = "aks-wojtech-compute"
  sku_tier                  = "Free"
  local_account_disabled    = true
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  azure_policy_enabled      = true
  private_cluster_enabled   = false

  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name                        = "systempool"
    vm_size                     = var.aks_node_vm_size
    vnet_subnet_id              = data.azurerm_subnet.subnet_api.id
    auto_scaling_enabled        = true
    min_count                   = 1
    max_count                   = 2
    max_pods                    = 50
    os_disk_size_gb             = 64
    os_disk_type                = "Managed"
    temporary_name_for_rotation = "temppool"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.id_aks.id]
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  dynamic "oms_agent" {
    for_each = length(data.azurerm_resources.law_hub.resources) > 0 ? [1] : []
    content {
      log_analytics_workspace_id = data.azurerm_resources.law_hub.resources[0].id
    }
  }

  tags = {
    Env  = "Spoke-Compute"
    Role = "Kubernetes"
  }

  depends_on = [azurerm_role_assignment.aks_network_contributor]
}

# Passwordless AcrPull RBAC for AKS Kubelet Identity -> Private ACR
resource "azurerm_role_assignment" "aks_kubelet_acrpull" {
  scope                            = azurerm_container_registry.acr_compute.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks_compute.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Grant Deployment Identity Cluster Admin RBAC on AKS
resource "azurerm_role_assignment" "aks_cluster_admin" {
  scope                = azurerm_kubernetes_cluster.aks_compute.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}
