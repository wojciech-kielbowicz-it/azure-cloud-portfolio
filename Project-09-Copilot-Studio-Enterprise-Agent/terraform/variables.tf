variable "location" {
  description = "Azure region for AI Model Deployments"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed."
  }
}
