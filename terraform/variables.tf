variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "firewall_switch" {
  description = "Switch for firewall deployment"
  type        = bool
  default     = false
}

variable "firewall_sku" {
  description = "Firewall SKU"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku)
    error_message = "Only Standard or Premium is allowed"
  }
}

variable "nsg_rule_zero_trust" {
  description = "Zero Trust NSG rule"
  type = list(object({
    name                       = string
    priority                   = number
    direction                  = string
    access                     = string
    protocol                   = string
    source_port_range          = string
    destination_port_range     = string
    source_address_prefix      = string
    destination_address_prefix = string
  }))
  default = [
    {
      name                       = "Deny-Internet-Inbound"
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }
  ]
}

