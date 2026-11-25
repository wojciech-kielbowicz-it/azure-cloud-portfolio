variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "law_name" {
  description = "Existing central Log Analytics Workspace (Project-05)"
  type        = string
  default     = "law-secops-central-ktdi8h"
}

variable "secops_rg_name" {
  description = "Existing SecOps Resource Group (Project-05)"
  type        = string
  default     = "rg-secops-monitoring"
}
