variable "location" {
  description = "Azure region for AI & RAG resources"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed."
  }
}

variable "search_sku" {
  description = "SKU for Azure AI Search (basic for Private Endpoints)"
  type        = string
  default     = "basic"
}

variable "ai_services_sku" {
  description = "SKU for Azure AI Services"
  type        = string
  default     = "S0"
}
