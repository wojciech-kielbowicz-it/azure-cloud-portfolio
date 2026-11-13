variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "dc01_private_ip" {
  description = "Static Private IP of vm-dc01 from Project-01"
  type        = string
  default     = "10.0.1.10"

  validation {
    condition     = var.dc01_private_ip == "10.0.1.10"
    error_message = "Must match vm-dc01 private IP (10.0.1.10)"
  }
}

variable "fw_rule_priority" {
  description = "Firewall Rule Collection Group priority"
  type        = number
  default     = 500

  validation {
    condition     = var.fw_rule_priority >= 100 && var.fw_rule_priority <= 65000
    error_message = "Priority must be between 100 and 65000"
  }
}
