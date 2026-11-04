variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "kv_sku" {
  description = "Key Vault SKU"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.kv_sku)
    error_message = "Only standard or premium SKU is allowed"
  }
}

variable "purge_protection_enabled" {
  description = "Purge Protection required by Azure Policy"
  type        = bool
  default     = true

  validation {
    condition     = var.purge_protection_enabled == true
    error_message = "Policy blocks deployment without Purge Protection"
  }
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention days"
  type        = number
  default     = 7
}
