# Obtain data from Project-01 resources (On-Premises)
data "azurerm_resource_group" "rg_onprem" {
  name = "rg-onpremises"
}

data "azurerm_virtual_network" "vnet_onprem" {
  name                = "vnet-onpremises"
  resource_group_name = data.azurerm_resource_group.rg_onprem.name
}

data "azurerm_subnet" "subnet_onprem" {
  name                 = "subnet-onpremises"
  virtual_network_name = data.azurerm_virtual_network.vnet_onprem.name
  resource_group_name  = data.azurerm_resource_group.rg_onprem.name
}

# Obtain data from Project-03 resources (Hub, Firewall, and Spokes)
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

data "azurerm_subnet" "subnet_appservice" {
  name                 = "subnet-appservice-integration"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_ai.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_ai.name
}

data "azurerm_firewall" "fw_hub" {
  name                = "afw-hub-central"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_firewall_policy" "fw_policy" {
  name                = "afwp-hub-default"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

# Obtain data from Project-04 and Project-06 resources (Private DNS Zones)
data "azurerm_private_dns_zone" "dns_kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_private_dns_zone" "dns_sql" {
  name                = "privatelink.database.windows.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_private_dns_zone" "dns_blob" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_private_dns_zone" "dns_dfs" {
  name                = "privatelink.dfs.core.windows.net"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

# VNet Peering (On-Premises <-> Hub)
resource "azurerm_virtual_network_peering" "onprem_to_hub" {
  name                      = "peer-onprem-to-hub"
  resource_group_name       = data.azurerm_resource_group.rg_onprem.name
  virtual_network_name      = data.azurerm_virtual_network.vnet_onprem.name
  remote_virtual_network_id = data.azurerm_virtual_network.vnet_hub.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "hub_to_onprem" {
  name                      = "peer-hub-to-onprem"
  resource_group_name       = data.azurerm_resource_group.rg_hub.name
  virtual_network_name      = data.azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id = data.azurerm_virtual_network.vnet_onprem.id
  allow_forwarded_traffic   = true
}

# Private DNS connection to On-Premises VNet
resource "azurerm_private_dns_zone_virtual_network_link" "link_kv_onprem" {
  name                = "link-dns-kv-to-onprem"
  private_dns_zone_id = data.azurerm_private_dns_zone.dns_kv.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_onprem.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_sql_onprem" {
  name                = "link-dns-sql-to-onprem"
  private_dns_zone_id = data.azurerm_private_dns_zone.dns_sql.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_onprem.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_blob_onprem" {
  name                = "link-dns-blob-to-onprem"
  private_dns_zone_id = data.azurerm_private_dns_zone.dns_blob.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_onprem.id
}

resource "azurerm_private_dns_zone_virtual_network_link" "link_dfs_onprem" {
  name                = "link-dns-dfs-to-onprem"
  private_dns_zone_id = data.azurerm_private_dns_zone.dns_dfs.id
  virtual_network_id  = data.azurerm_virtual_network.vnet_onprem.id
}

# Route Tables (Zero Trust UDR via Central Firewall)
resource "azurerm_route_table" "rt_onprem" {
  name                          = "rt-onprem-zero-trust"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.rg_onprem.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "route-to-spoke-ai"
    address_prefix         = "10.2.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = data.azurerm_firewall.fw_hub.ip_configuration[0].private_ip_address
  }

  route {
    name                   = "route-to-spoke-compute"
    address_prefix         = "10.3.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = data.azurerm_firewall.fw_hub.ip_configuration[0].private_ip_address
  }

  tags = {
    Env  = "On-Prem"
    Role = "Routing"
  }
}

resource "azurerm_subnet_route_table_association" "assoc_rt_onprem" {
  subnet_id      = data.azurerm_subnet.subnet_onprem.id
  route_table_id = azurerm_route_table.rt_onprem.id
}

resource "azurerm_route_table" "rt_spoke_ai" {
  name                          = "rt-spoke-ai-zero-trust"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.rg_spoke_ai.name
  bgp_route_propagation_enabled = false

  route {
    name                   = "route-to-onprem"
    address_prefix         = "10.0.0.0/16"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = data.azurerm_firewall.fw_hub.ip_configuration[0].private_ip_address
  }

  tags = {
    Env  = "Spoke-AI"
    Role = "Routing"
  }
}

resource "azurerm_subnet_route_table_association" "assoc_rt_priv_end" {
  subnet_id      = data.azurerm_subnet.subnet_priv_end.id
  route_table_id = azurerm_route_table.rt_spoke_ai.id
}

resource "azurerm_subnet_route_table_association" "assoc_rt_appservice" {
  subnet_id      = data.azurerm_subnet.subnet_appservice.id
  route_table_id = azurerm_route_table.rt_spoke_ai.id
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "rcg_hybrid" {
  name               = "rcg-hybrid-zero-trust"
  firewall_policy_id = data.azurerm_firewall_policy.fw_policy.id
  priority           = var.fw_rule_priority

  network_rule_collection {
    name     = "net-allow-onprem-to-spoke-ai"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "Allow-DC01-to-Private-PaaS"
      protocols             = ["TCP"]
      source_addresses      = [var.dc01_private_ip]
      destination_addresses = ["10.2.1.0/24", "10.2.2.0/24"]
      destination_ports     = ["443", "1433"]
    }
  }

  application_rule_collection {
    name     = "app-allow-onprem-entra-sync"
    priority = 200
    action   = "Allow"

    rule {
      name = "Allow-Entra-Cloud-Sync-TCK-WC-705"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses = [var.dc01_private_ip]
      destination_fqdns = [
        "*.login.microsoftonline.com",
        "*.msappproxy.net",
        "*.servicebus.windows.net",
        "*.azurewebsites.net"
      ]
    }
  }
}
