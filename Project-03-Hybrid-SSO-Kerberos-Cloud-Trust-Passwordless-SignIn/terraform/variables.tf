variable "location" {
  type    = string
  default = "swedencentral"
}

variable "onprem_rg" {
  description = "On-Premises resource group"
  type        = string
  default     = "rg-onpremises"
}

variable "onprem_vnet" {
  description = "On-Premises VNet"
  type        = string
  default     = "vnet-onpremises"
}

variable "onprem_subnet" {
  description = "AD DC Subnet"
  type        = string
  default     = "subnet-onpremises"
}

variable "ad_dc_ip_address" {
  description = "AD DC private IP"
  type        = string
  default     = "10.0.1.10"
}

variable "vm_admin_username" {
  type    = string
  default = "bg_account"
}

variable "vm_admin_password" {
  description = "admin account password from GitHub secrets"
  type        = string
  sensitive   = true
}
