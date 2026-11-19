output "application_gateway_public_ip" {
  description = "Public IP address of the Hub Application Gateway WAF v2"
  value       = azurerm_public_ip.pip_agw.ip_address
}

output "aks_internal_lb_ip" {
  description = "Private IP of AKS Internal Load Balancer in subnet-web"
  value       = "10.3.1.250"
}
