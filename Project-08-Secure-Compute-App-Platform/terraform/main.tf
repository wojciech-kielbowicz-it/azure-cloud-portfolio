# Obtaining existing Hub & Spoke networks and subnets (Project-03)
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

# EObtaining Private Endpoints subnet (10.2.1.0/24) (Project-03)
data "azurerm_subnet" "subnet_priv_end" {
  name                 = "subnet-private-endpoints"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_ai.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_ai.name
}

# Obtaining App Service Integration subnet (10.2.2.0/24) with Microsoft.Web/serverFarms delegation (Project-03)
data "azurerm_subnet" "subnet_appservice" {
  name                 = "subnet-appservice-integration"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_ai.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_ai.name
}

# Obtaining Log Analytics Workspace (Project-05)
data "azurerm_log_analytics_workspace" "law" {
  name                = "law-secops-central-ktdi8h"
  resource_group_name = "rg-secops-monitoring"
}

# Obtaining Data Lake Storage (Project-06), SQL Server (Project-06) & Key Vault (Project-04)
data "azurerm_resources" "adls_storage" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  type                = "Microsoft.Storage/storageAccounts"
}

data "azurerm_resources" "sql_resources" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  type                = "Microsoft.Sql/servers"
}

data "azurerm_resources" "kv_resources" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  type                = "Microsoft.KeyVault/vaults"
}

resource "random_string" "app_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Central Private DNS Zone in Hub -> Azure Web Apps (privatelink.azurewebsites.net)
resource "azurerm_private_dns_zone" "dns_webapp" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

locals {
  vnets = {
    hub     = data.azurerm_virtual_network.vnet_hub.id
    spokeai = data.azurerm_virtual_network.vnet_spoke_ai.id
    compute = data.azurerm_virtual_network.vnet_spoke_compute.id
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_webapp" {
  for_each            = local.vnets
  name                = "link-dns-webapp-to-${each.key}"
  private_dns_zone_id = azurerm_private_dns_zone.dns_webapp.id
  virtual_network_id  = each.value
}

# User-Assigned Managed Identity _>  Passwordless Zero Trust Access
resource "azurerm_user_assigned_identity" "app_identity" {
  name                = "id-wojtech-copilot-api"
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  location            = var.location

  tags = {
    Env  = "Spoke-AI"
    Role = "Passwordless-Workload-Identity"
  }
}

# Managed Identity read access -> Data Lake Gen2 (Project-06) & Key Vault (Project-04)
resource "azurerm_role_assignment" "app_to_adls_reader" {
  scope                = data.azurerm_resources.adls_storage.resources[0].id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

resource "azurerm_role_assignment" "app_to_kv_secrets" {
  scope                = data.azurerm_resources.kv_resources.resources[0].id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app_identity.principal_id
}

# App Service Plan & Linux Web App integration with subnet-appservice-integration (10.2.2.0/24)
resource "azurerm_service_plan" "asp_ai" {
  name                   = "asp-wojtech-ai-${random_string.app_suffix.result}"
  resource_group_name    = data.azurerm_resource_group.rg_spoke_ai.name
  location               = var.location
  os_type                = "Linux"
  sku_name               = var.app_service_sku
  zone_balancing_enabled = false

  tags = {
    Env  = "Spoke-AI"
    Role = "Copilot-Backend-Host"
  }
}

resource "azurerm_linux_web_app" "webapp_copilot_api" {
  name                                           = "app-wojtech-copilot-api-${random_string.app_suffix.result}"
  resource_group_name                            = data.azurerm_resource_group.rg_spoke_ai.name
  location                                       = var.location
  service_plan_id                                = azurerm_service_plan.asp_ai.id
  https_only                                     = true
  public_network_access_enabled                  = false
  virtual_network_subnet_id                      = data.azurerm_subnet.subnet_appservice.id # 10.2.2.0/24 subnet (Project-03)
  client_certificate_enabled                     = true
  client_certificate_mode                        = "Optional"
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.app_identity.id]
  }

  site_config {
    always_on                         = true
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    ftps_state                        = "Disabled"
    vnet_route_all_enabled            = true # Forces outbound traffic via 10.2.2.0/24 to 10.2.1.0/24 Private Endpoints
    health_check_path                 = "/health"
    health_check_eviction_time_in_min = 5
    app_command_line                  = "uvicorn main:app --host 0.0.0.0 --port 8000"

    application_stack {
      python_version = "3.12"
    }
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      file_system {
        retention_in_days = 7
        retention_in_mb   = 35
      }
    }
  }

  app_settings = {
    "AZURE_CLIENT_ID"                = azurerm_user_assigned_identity.app_identity.client_id
    "ADLS_ACCOUNT_NAME"              = data.azurerm_resources.adls_storage.resources[0].name
    "SQL_SERVER_FQDN"                = "${data.azurerm_resources.sql_resources.resources[0].name}.database.windows.net"
    "TARGET_SQL_DB"                  = "sqldb-ai-knowledge"
    "WEBSITE_DNS_SERVER"             = "168.63.129.16"
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
  }

  tags = {
    Env  = "Spoke-AI"
    Role = "Enterprise-Copilot-Connector"
  }
}

# Private Endpoint for the Web App in subnet-private-endpoints (10.2.1.0/24)
resource "azurerm_private_endpoint" "pe_webapp" {
  name                = "pe-webapp-copilot-api"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  subnet_id           = data.azurerm_subnet.subnet_priv_end.id

  private_service_connection {
    name                           = "psc-webapp-copilot-api"
    private_connection_resource_id = azurerm_linux_web_app.webapp_copilot_api.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_webapp.id]
  }
}

# Diagnostic Settings streaming Web App logs -> Microsoft Sentinel (Project-05)
resource "azurerm_monitor_diagnostic_setting" "diag_webapp" {
  name                       = "diag-webapp-to-sentinel"
  target_resource_id         = azurerm_linux_web_app.webapp_copilot_api.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}
