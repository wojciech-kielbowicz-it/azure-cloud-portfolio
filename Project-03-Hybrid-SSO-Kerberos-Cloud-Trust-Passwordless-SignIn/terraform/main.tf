data "azurerm_resource_group" "rg" {
  name = var.onprem_rg
}

data "azurerm_subnet" "subnet" {
  name                 = var.onprem_subnet
  virtual_network_name = var.onprem_vnet
  resource_group_name  = var.onprem_rg
}

# NIC + DNS 
resource "azurerm_network_interface" "nic_win11" {
  name                = "nic-vm-win11-host"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  dns_servers = [var.ad_dc_ip_address, "168.63.129.16"]

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Virtual Machine
resource "azurerm_windows_virtual_machine" "vm_win11" {
  name                = "vm-win11-host"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  size                = "Standard_D2als_v6"
  admin_username      = var.vm_admin_username
  admin_password      = var.vm_admin_password

  network_interface_ids = [
    azurerm_network_interface.nic_win11.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-23h2-ent"
    version   = "latest"
  }
}
