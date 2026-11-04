data "azurerm_client_config" "current" {}

# Obtain data from Project-03 resources
data "azurerm_resource_group" "rg_hub" {
  name = "rg-network-hub"
}

data "azurerm_resource_group" "rg_spoke_ai" {
  name = "rg-spoke-ai-data"
}

data "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_virtual_network" "vnet_spoke_ai" {
  name                = "vnet-spoke-ai-data"
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
}

data "azurerm_subnet" "subnet_priv_end" {
  name                 = "subnet-private-endpoints"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_ai.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_ai.name
}

data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

data "azurerm_virtual_network" "vnet_spoke_compute" {
  name                = "vnet-spoke-compute"
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

# Private DNS Zone for Key Vault
resource "azurerm_private_dns_zone" "dns_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name

  tags = {
    Env  = "Network"
    Role = "DNS"
  }
}

# Private DNS connection to all VNets
resource "azurerm_private_dns_zone_virtual_network_link" "link_hub" {
  name                = "link-dns-kv-to-hub"
  private_dns_zone_id = azurerm_private_dns_zone.dns_kv.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_hub.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_spoke_ai" {
  name                = "link-dns-kv-to-spoke-ai"
  private_dns_zone_id = azurerm_private_dns_zone.dns_kv.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_spoke_ai.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_spoke_compute" {
  name                = "link-dns-kv-to-spoke-compute"
  private_dns_zone_id = azurerm_private_dns_zone.dns_kv.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_spoke_compute.id
}


resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Key Vault (Purge Protection, No Public Access)
resource "azurerm_key_vault" "kv_ai" {
  name                          = "kv-spoke-ai-${random_string.kv_suffix.result}"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.rg_spoke_ai.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = var.kv_sku
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  rbac_authorization_enabled    = true
  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = {
    Env  = "Spoke-AI"
    Role = "Secrets"
  }
}

# Key Vault Private Endpoint 
resource "azurerm_private_endpoint" "pe_kv" {
  name                = "pe-kv-spoke-ai"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_spoke_ai.name
  subnet_id           = data.azurerm_subnet.subnet_priv_end.id

  private_service_connection {
    name                           = "psc-kv-spoke-ai"
    private_connection_resource_id = azurerm_key_vault.kv_ai.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_kv.id]
  }
}
