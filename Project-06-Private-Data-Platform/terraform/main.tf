data "azurerm_client_config" "current" {}

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

# Obtaining Log Analytics Workspace -> Project-05 (rg-secops-monitoring)
data "azurerm_log_analytics_workspace" "law" {
  name                = "law-secops-central-ktdi8h"
  resource_group_name = "rg-secops-monitoring"
}

resource "random_string" "data_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Private DNS Zones (Blob, DFS for Data Lake, Database for SQL)
resource "azurerm_private_dns_zone" "dns_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

resource "azurerm_private_dns_zone" "dns_dfs" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

resource "azurerm_private_dns_zone" "dns_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

# Private DNS <-> VNet integration
locals {
  vnets = {
    hub     = data.azurerm_virtual_network.vnet_hub.id
    spokeai = data.azurerm_virtual_network.vnet_spoke_ai.id
    compute = data.azurerm_virtual_network.vnet_spoke_compute.id
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_blob" {
  for_each            = local.vnets
  name                = "link-dns-blob-to-${each.key}"
  private_dns_zone_id = azurerm_private_dns_zone.dns_blob.id
  virtual_network_id  = each.value
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_dfs" {
  for_each            = local.vnets
  name                = "link-dns-dfs-to-${each.key}"
  private_dns_zone_id = azurerm_private_dns_zone.dns_dfs.id
  virtual_network_id  = each.value
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_sql" {
  for_each            = local.vnets
  name                = "link-dns-sql-to-${each.key}"
  private_dns_zone_id = azurerm_private_dns_zone.dns_sql.id
  virtual_network_id  = each.value
}

# Data Lake Storage Gen2 (HNS enabled, Zero Trust)
resource "azurerm_storage_account" "adls_ai" {
  name                            = "stadlsai${random_string.data_suffix.result}"
  resource_group_name             = data.azurerm_resource_group.rg_spoke_ai.name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = var.storage_replication_type
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true # HNS enabled
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Entra ID Authentification only (SA Keys disabled )
  local_user_enabled              = false
  public_network_access           = "Disabled"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"] # Bypass
  }

  tags = {
    Env  = "Spoke-AI"
    Role = "DataLake-Gen2"
  }
}

# Data Lake Private Endpoints (Blob oraz DFS)
resource "azurerm_private_endpoint" "pe_adls_blob" {
  name                = "pe-adls-blob-ai"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  subnet_id           = data.azurerm_subnet.subnet_priv_end.id

  private_service_connection {
    name                           = "psc-adls-blob-ai"
    private_connection_resource_id = azurerm_storage_account.adls_ai.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_blob.id]
  }
}

resource "azurerm_private_endpoint" "pe_adls_dfs" {
  name                = "pe-adls-dfs-ai"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  subnet_id           = data.azurerm_subnet.subnet_priv_end.id

  private_service_connection {
    name                           = "psc-adls-dfs-ai"
    private_connection_resource_id = azurerm_storage_account.adls_ai.id
    is_manual_connection           = false
    subresource_names              = ["dfs"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_dfs.id]
  }
}

# Azure SQL Server (Entra ID Only, No public access)
resource "azurerm_mssql_server" "sql_server_ai" {
  name                          = "sql-spoke-ai-${random_string.data_suffix.result}"
  resource_group_name           = data.azurerm_resource_group.rg_spoke_ai.name
  location                      = var.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  azuread_administrator {
    login_username              = "EntraAdmin-OIDC"
    object_id                   = data.azurerm_client_config.current.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true # Entra ID Authentication only
  }

  tags = {
    Env  = "Spoke-AI"
    Role = "AI-Structured-DB"
  }
}

# Azure SQL Database (Serverless for future AI / Copilot Studio workloads)
resource "azurerm_mssql_database" "sql_db_ai" {
  name                        = "sqldb-ai-knowledge"
  server_id                   = azurerm_mssql_server.sql_server_ai.id
  sku_name                    = var.sql_sku_name
  max_size_gb                 = 2
  auto_pause_delay_in_minutes = 60 # Auto pause after 60 minuts inactive
  min_capacity                = 0.5
  zone_redundant              = false
  storage_account_type        = "Local"

  tags = {
    Env  = "Spoke-AI"
    Role = "Knowledge-Base"
  }
}

# Azure SQL Server Private Endpoint 
resource "azurerm_private_endpoint" "pe_sql" {
  name                = "pe-sql-spoke-ai"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  subnet_id           = data.azurerm_subnet.subnet_priv_end.id

  private_service_connection {
    name                           = "psc-sql-spoke-ai"
    private_connection_resource_id = azurerm_mssql_server.sql_server_ai.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_sql.id]
  }
}

# SQL, Data Lake Logs integration with Sentinel
resource "azurerm_monitor_diagnostic_setting" "diag_sql_db" {
  name                       = "diag-sqldb-to-sentinel"
  target_resource_id         = azurerm_mssql_database.sql_db_ai.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_adls_blob" {
  name                       = "diag-adls-blob-to-sentinel"
  target_resource_id         = "${azurerm_storage_account.adls_ai.id}/blobServices/default"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}
