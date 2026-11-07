variable "location" {
  description = "Azure region for Data Platform resources"
  type        = string
  default     = "swedencentral"

  validation {
    condition     = var.location == "swedencentral"
    error_message = "Only Sweden Central is allowed."
  }
}

variable "storage_replication_type" {
  description = "Replication type for ADLS Gen2"
  type        = string
  default     = "LRS"
}

variable "sql_sku_name" {
  description = "SKU for Azure SQL Database (Serverless tier)"
  type        = string
  default     = "GP_S_Gen5_1"
}
