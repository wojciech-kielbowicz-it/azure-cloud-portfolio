variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "vm_admin_password" {
  description = "Admin password (GitHub secrets)"
  type        = string
  sensitive   = true
}
