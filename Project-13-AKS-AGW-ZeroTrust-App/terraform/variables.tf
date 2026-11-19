variable "location" {
  description = "Region"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed"
  }
}

variable "agw_sku_name" {
  description = "Application Gateway SKU Name"
  type        = string
  default     = "WAF_v2"
}

variable "agw_sku_tier" {
  description = "Application Gateway SKU Tier"
  type        = string
  default     = "WAF_v2"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace for Zero Trust Web App"
  type        = string
  default     = "default"
}

variable "k8s_service_account_name" {
  description = "ServiceAccount created in Project-12"
  type        = string
  default     = "sa-zero-trust-app"
}

variable "app_image_tag" {
  description = "Docker image tag in private ACR"
  type        = string
  default     = "v1.0.0"
}
