# Resource Group
resource "azurerm_resource_group" "rg_onprem" {
  name     = "rg-onpremises"
  location = var.location
  tags = {
    Env = "On-Prem"
  }
}

# Local Network
resource "azurerm_virtual_network" "vnet_onprem" {
  name                = "vnet-onpremises"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet_onprem" {
  name                 = "subnet-onpremises"
  resource_group_name  = azurerm_resource_group.rg_onprem.name
  virtual_network_name = azurerm_virtual_network.vnet_onprem.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP 
resource "azurerm_public_ip" "public_ip_onprem" {
  name                = "pip-dc01"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# NIC + Static Private IP + Static Public IP
resource "azurerm_network_interface" "nic_onprem" {
  name                = "nic-dc01"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = var.location
  ip_configuration {
    name                          = "pip-dc01"
    subnet_id                     = azurerm_subnet.subnet_onprem.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.10"
    public_ip_address_id          = azurerm_public_ip.public_ip_onprem.id
  }
}

# NSG
resource "azurerm_network_security_group" "nsg_dc01" {
  name                = "nsg-dc01"
  resource_group_name = azurerm_resource_group.rg_onprem.name
  location            = var.location
}

resource "azurerm_network_interface_security_group_association" "nsg_assoc_dc01" {
  network_interface_id      = azurerm_network_interface.nic_onprem.id
  network_security_group_id = azurerm_network_security_group.nsg_dc01.id
}

resource "azurerm_network_security_rule" "Allow-RDP-Inbound" {
  name                        = "Allow-RDP-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg_onprem.name
  network_security_group_name = azurerm_network_security_group.nsg_dc01.name
}

# Virtual Machine
resource "azurerm_windows_virtual_machine" "vm_dc01" {
  name                       = "vm-dc01"
  resource_group_name        = azurerm_resource_group.rg_onprem.name
  location                   = var.location
  size                       = "Standard_D2als_v6"
  admin_username             = "bg_account"
  admin_password             = var.vm_admin_password
  network_interface_ids      = [azurerm_network_interface.nic_onprem.id]
  encryption_at_host_enabled = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2025-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }
}
