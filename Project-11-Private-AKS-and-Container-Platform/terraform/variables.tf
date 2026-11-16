variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "acr_sku" {
  description = "Container Registry SKU"
  type        = string
  default     = "Premium"

  validation {
    condition     = var.acr_sku == "Premium"
    error_message = "Premium SKU for Private Endpoints"
  }
}

variable "aks_node_vm_size" {
  description = "VM size for AKS system node pool"
  type        = string
  default     = "Standard_B2s_v2"
}
