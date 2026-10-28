# Resource groups
resource "azurerm_resource_group" "rg_hub" {
  name     = "rg-network-hub"
  location = var.location

  tags = {
    Env  = "Network"
    Role = "Hub"
  }
}

resource "azurerm_resource_group" "rg_spoke_ai" {
  name     = "rg-spoke-ai-data"
  location = var.location

  tags = {
    Env  = "Network"
    Role = "Spoke"
  }
}

resource "azurerm_resource_group" "rg_spoke_compute" {
  name     = "rg-spoke-compute"
  location = var.location

  tags = {
    Env  = "Network"
    Role = "Spoke"
  }
}

# Hub
resource "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  address_space       = ["10.1.0.0/16"]
}
## Subnets (Firewall, Bastion, VPN Gateway, App Gateway)
resource "azurerm_subnet" "subnet_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.1.1.0/26"]
}


resource "azurerm_subnet" "subnet_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.1.2.0/26"]
}

resource "azurerm_subnet" "subnet_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.1.3.0/27"]
}

resource "azurerm_subnet" "subnet_appgw" {
  name                 = "subnet-appgw"
  resource_group_name  = azurerm_resource_group.rg_hub.name
  virtual_network_name = azurerm_virtual_network.vnet_hub.name
  address_prefixes     = ["10.1.4.0/24"]

}

## NSG + Association

resource "azurerm_network_security_group" "nsg_hub" {
  name                = "nsg-hub-baseline"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
}

resource "azurerm_subnet_network_security_group_association" "assoc_appgw" {
  subnet_id                 = azurerm_subnet.subnet_appgw.id
  network_security_group_id = azurerm_network_security_group.nsg_hub.id
}

# Spoke 1 (AI & Data)
resource "azurerm_virtual_network" "vnet_spoke_ai" {
  name                = "vnet-spoke-ai-data"
  location            = azurerm_resource_group.rg_spoke_ai.location
  resource_group_name = azurerm_resource_group.rg_spoke_ai.name
  address_space       = ["10.2.0.0/16"]
}

## Subnets (Private Endpoints, App Service)
resource "azurerm_subnet" "subnet_priv_end" {
  name                              = "subnet-private-endpoints"
  resource_group_name               = azurerm_resource_group.rg_spoke_ai.name
  virtual_network_name              = azurerm_virtual_network.vnet_spoke_ai.name
  address_prefixes                  = ["10.2.1.0/24"]
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "subnet_appservice" {
  name                 = "subnet-appservice-integration"
  resource_group_name  = azurerm_resource_group.rg_spoke_ai.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke_ai.name
  address_prefixes     = ["10.2.2.0/24"]

  delegation {
    name = "appservice-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

}

## NSGs + Associations
resource "azurerm_network_security_group" "nsg_spoke_ai" {
  name                = "nsg-spoke-ai-baseline"
  location            = azurerm_resource_group.rg_spoke_ai.location
  resource_group_name = azurerm_resource_group.rg_spoke_ai.name

  dynamic "security_rule" {
    for_each = var.nsg_rule_zero_trust
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc_priv_end" {
  subnet_id                 = azurerm_subnet.subnet_priv_end.id
  network_security_group_id = azurerm_network_security_group.nsg_spoke_ai.id
}

resource "azurerm_subnet_network_security_group_association" "assoc_appservice" {
  subnet_id                 = azurerm_subnet.subnet_appservice.id
  network_security_group_id = azurerm_network_security_group.nsg_spoke_ai.id
}

## VNet Peering 

resource "azurerm_virtual_network_peering" "hub_to_ai" {
  name                      = "peer-hub-to-spoke-ai"
  resource_group_name       = azurerm_resource_group.rg_hub.name
  virtual_network_name      = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_spoke_ai.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "ai_to_hub" {
  name                      = "peer-spoke-ai-to-hub"
  resource_group_name       = azurerm_resource_group.rg_spoke_ai.name
  virtual_network_name      = azurerm_virtual_network.vnet_spoke_ai.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_hub.id
  allow_forwarded_traffic   = true
}


# Spoke 2 (Compute & AKS)
resource "azurerm_virtual_network" "vnet_spoke_compute" {
  name                = "vnet-spoke-compute"
  location            = azurerm_resource_group.rg_spoke_compute.location
  resource_group_name = azurerm_resource_group.rg_spoke_compute.name
  address_space       = ["10.3.0.0/16"]
}

## Subnets (Web, API, DB)
resource "azurerm_subnet" "subnet_web" {
  name                 = "subnet-web"
  resource_group_name  = azurerm_resource_group.rg_spoke_compute.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke_compute.name
  address_prefixes     = ["10.3.1.0/24"]
}

resource "azurerm_subnet" "subnet_api" {
  name                 = "subnet-api"
  resource_group_name  = azurerm_resource_group.rg_spoke_compute.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke_compute.name
  address_prefixes     = ["10.3.2.0/24"]

}

resource "azurerm_subnet" "subnet_db" {
  name                 = "subnet-db"
  resource_group_name  = azurerm_resource_group.rg_spoke_compute.name
  virtual_network_name = azurerm_virtual_network.vnet_spoke_compute.name
  address_prefixes     = ["10.3.3.0/24"]

}

## NSGs + Associations
resource "azurerm_network_security_group" "nsg_spoke_compute" {
  name                = "nsg-spoke-compute-baseline"
  location            = azurerm_resource_group.rg_spoke_compute.location
  resource_group_name = azurerm_resource_group.rg_spoke_compute.name

  dynamic "security_rule" {
    for_each = var.nsg_rule_zero_trust
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "assoc_web" {
  subnet_id                 = azurerm_subnet.subnet_web.id
  network_security_group_id = azurerm_network_security_group.nsg_spoke_compute.id
}

resource "azurerm_subnet_network_security_group_association" "assoc_api" {
  subnet_id                 = azurerm_subnet.subnet_api.id
  network_security_group_id = azurerm_network_security_group.nsg_spoke_compute.id
}

resource "azurerm_subnet_network_security_group_association" "assoc_db" {
  subnet_id                 = azurerm_subnet.subnet_db.id
  network_security_group_id = azurerm_network_security_group.nsg_spoke_compute.id
}

## VNet Peering

resource "azurerm_virtual_network_peering" "hub_to_compute" {
  name                      = "peer-hub-to-spoke-compute"
  resource_group_name       = azurerm_resource_group.rg_hub.name
  virtual_network_name      = azurerm_virtual_network.vnet_hub.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_spoke_compute.id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "compute_to_hub" {
  name                      = "peer-spoke-compute-to-hub"
  resource_group_name       = azurerm_resource_group.rg_spoke_compute.name
  virtual_network_name      = azurerm_virtual_network.vnet_spoke_compute.name
  remote_virtual_network_id = azurerm_virtual_network.vnet_hub.id
  allow_forwarded_traffic   = true
}

# Firewall
resource "azurerm_public_ip" "pip_fw" {
  count               = var.firewall_switch ? 1 : 0
  name                = "pip-azure-firewall"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}


resource "azurerm_firewall_policy" "fw_policy" {
  count               = var.firewall_switch ? 1 : 0
  name                = "afwp-hub-default"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  sku                 = var.firewall_sku

  intrusion_detection {
    mode = "Deny"
  }

}

resource "azurerm_firewall" "fw_hub" {
  count               = var.firewall_switch ? 1 : 0
  name                = "afw-hub-central"
  location            = azurerm_resource_group.rg_hub.location
  resource_group_name = azurerm_resource_group.rg_hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku

  firewall_policy_id = var.firewall_switch ? azurerm_firewall_policy.fw_policy[0].id : null

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.subnet_firewall.id
    public_ip_address_id = var.firewall_switch ? azurerm_public_ip.pip_fw[0].id : null
  }
}
