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
  default     = false

  validation {
    condition     = var.purge_protection_enabled == false || var.purge_protection_enabled == true
    error_message = "Purge protection can be true or false"
  }
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention days"
  type        = number
  default     = 7
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Workload Identity pod"
  type        = string
  default     = "default"
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name federated with Managed Identity"
  type        = string
  default     = "sa-zero-trust-app"
}
