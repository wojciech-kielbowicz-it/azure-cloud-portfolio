# Obtain data from Project-03
data "azurerm_resource_group" "rg_hub" {
  name = "rg-network-hub"
}

data "azurerm_resource_group" "rg_spoke_ai" {
  name = "rg-spoke-ai-data"
}

data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

data "azurerm_network_security_group" "nsg_hub" {
  name                = "nsg-hub-baseline"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_network_security_group" "nsg_spoke_ai" {
  name                = "nsg-spoke-ai-baseline"
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
}

data "azurerm_network_security_group" "nsg_spoke_compute" {
  name                = "nsg-spoke-compute-baseline"
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

# Resource Group (SecOps & Monitoring)
resource "azurerm_resource_group" "rg_secops" {
  name     = "rg-secops-monitoring"
  location = var.location

  tags = {
    Env  = "SecOps"
    Role = "SIEM-Monitoring"
  }
}

resource "random_string" "law_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Central Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law_central" {
  name                = "law-secops-central-${random_string.law_suffix.result}"
  location            = azurerm_resource_group.rg_secops.location
  resource_group_name = azurerm_resource_group.rg_secops.name
  sku                 = var.law_sku
  retention_in_days   = var.retention_in_days

  tags = {
    Env  = "SecOps"
    Role = "Logs"
  }
}

# Microsoft Sentinel (SIEM <-> Log Analytics)
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "sentinel" {
  workspace_id                 = azurerm_log_analytics_workspace.law_central.id
  customer_managed_key_enabled = false
}

# Diagnostic Settings for All NSGs (from Hub & Spoke) (All logs)
resource "azurerm_monitor_diagnostic_setting" "diag_nsg_hub" {
  name                       = "diag-nsg-hub-to-law"
  target_resource_id         = data.azurerm_network_security_group.nsg_hub.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law_central.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_nsg_spoke_ai" {
  name                       = "diag-nsg-spoke-ai-to-law"
  target_resource_id         = data.azurerm_network_security_group.nsg_spoke_ai.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law_central.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_nsg_spoke_compute" {
  name                       = "diag-nsg-spoke-compute-to-law"
  target_resource_id         = data.azurerm_network_security_group.nsg_spoke_compute.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law_central.id

  enabled_log {
    category_group = "allLogs"
  }
}
