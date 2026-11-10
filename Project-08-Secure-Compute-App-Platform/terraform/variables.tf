variable "location" {
  description = "Azure region for Compute Spoke App Platform"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed."
  }
}

variable "app_service_sku" {
  description = "SKU for App Service Plan (B1 -> VNet Integration,Private Endpoints)"
  type        = string
  default     = "B1"
}
