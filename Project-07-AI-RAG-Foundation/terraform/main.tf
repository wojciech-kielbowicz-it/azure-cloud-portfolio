# Obtaining data -> Project-03 (Hub & Spoke)
data "azurerm_resource_group" "rg_hub" {
  name = "rg-network-hub"
}

data "azurerm_resource_group" "rg_spoke_ai" {
  name = "rg-spoke-ai-data"
}

data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

data "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_virtual_network" "vnet_spoke_ai" {
  name                = "vnet-spoke-ai-data"
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
}

data "azurerm_virtual_network" "vnet_spoke_compute" {
  name                = "vnet-spoke-compute"
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

data "azurerm_subnet" "subnet_priv_end" {
  name                 = "subnet-private-endpoints"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_ai.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_ai.name
}

# Obtaining Log Analytics Workspace -> Project-05
data "azurerm_log_analytics_workspace" "law" {
  name                = "law-secops-central-ktdi8h"
  resource_group_name = "rg-secops-monitoring"
}

# Obtaining Data Lake Storage Account -> Project-06 (for RBAC assignment)
data "azurerm_resources" "adls_storage" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  type                = "Microsoft.Storage/storageAccounts"
}

resource "random_string" "ai_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Private DNS Zones in Hub (AI Search & Cognitive Services)
resource "azurerm_private_dns_zone" "dns_search" {
  name                = "privatelink.search.windows.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

resource "azurerm_private_dns_zone" "dns_cognitive" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

locals {
  vnets = {
    hub     = data.azurerm_virtual_network.vnet_hub.id
    spokeai = data.azurerm_virtual_network.vnet_spoke_ai.id
    compute = data.azurerm_virtual_network.vnet_spoke_compute.id
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_search" {
  for_each            = local.vnets
  name                = "link-dns-search-to-${each.key}"
  private_dns_zone_id = azurerm_private_dns_zone.dns_search.id
  virtual_network_id  = each.value
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_cognitive" {
  for_each            = local.vnets
  name                = "link-dns-cognitive-to-${each.key}"
  private_dns_zone_id = azurerm_private_dns_zone.dns_cognitive.id
  virtual_network_id  = each.value
}

# Azure AI Search (Vector & Hybrid Search for Copilot Studio / RAG)
resource "azurerm_search_service" "ai_search" {
  name                          = "srch-spoke-ai-${random_string.ai_suffix.result}"
  resource_group_name           = data.azurerm_resource_group.rg_spoke_ai.name
  location                      = var.location
  sku                           = var.search_sku
  public_network_access_enabled = false
  local_authentication_enabled  = false # Enforces Entra ID authentication (Zero Trust)
  semantic_search_sku           = "free"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Env  = "Spoke-AI"
    Role = "Enterprise-RAG-Search"
  }
}

# Azure AI Services (Multi-service account for LLM / Embeddings)
resource "azurerm_cognitive_account" "ai_services" {
  name                          = "ais-spoke-ai-${random_string.ai_suffix.result}"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.rg_spoke_ai.name
  kind                          = "AIServices"
  sku_name                      = var.ai_services_sku
  custom_subdomain_name         = "ais-spoke-ai-${random_string.ai_suffix.result}"
  public_network_access_enabled = false
  local_auth_enabled            = false # Enforces Entra ID authentication

  identity {
    type = "SystemAssigned"
  }

  network_acls {
    default_action = "Deny"
  }

  tags = {
    Env  = "Spoke-AI"
    Role = "AI-Foundry-Services"
  }
}

# Private Endpoints for AI Search and AI Services
resource "azurerm_private_endpoint" "pe_search" {
  name                = "pe-aisearch-spoke-ai"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  subnet_id           = data.azurerm_subnet.subnet_priv_end.id

  private_service_connection {
    name                           = "psc-aisearch-spoke-ai"
    private_connection_resource_id = azurerm_search_service.ai_search.id
    is_manual_connection           = false
    subresource_names              = ["searchService"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_search.id]
  }
}

resource "azurerm_private_endpoint" "pe_cognitive" {
  name                = "pe-aiservices-spoke-ai"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  subnet_id           = data.azurerm_subnet.subnet_priv_end.id

  private_service_connection {
    name                           = "psc-aiservices-spoke-ai"
    private_connection_resource_id = azurerm_cognitive_account.ai_services.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_cognitive.id]
  }
}

# Zero Trust RBAC: Allow AI Search Managed Identity to read Data Lake -> Project-06
resource "azurerm_role_assignment" "search_to_adls_reader" {
  scope                = data.azurerm_resources.adls_storage.resources[0].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_search_service.ai_search.identity[0].principal_id
}

# Send AI Diagnostics to Microsoft Sentinel (Integration with Project-05)
resource "azurerm_monitor_diagnostic_setting" "diag_search" {
  name                       = "diag-aisearch-to-sentinel"
  target_resource_id         = azurerm_search_service.ai_search.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_cognitive" {
  name                       = "diag-aiservices-to-sentinel"
  target_resource_id         = azurerm_cognitive_account.ai_services.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}
