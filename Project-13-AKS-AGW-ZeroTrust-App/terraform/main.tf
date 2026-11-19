data "azurerm_client_config" "current" {}

# Obtain Hub & Spoke Network Resources from Project-03
data "azurerm_resource_group" "rg_hub" {
  name = "rg-network-hub"
}

data "azurerm_virtual_network" "vnet_hub" {
  name                = "vnet-hub"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_subnet" "subnet_appgw" {
  name                 = "subnet-appgw"
  virtual_network_name = data.azurerm_virtual_network.vnet_hub.name
  resource_group_name  = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_network_security_group" "nsg_hub" {
  name                = "nsg-hub-baseline"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

data "azurerm_virtual_network" "vnet_spoke_compute" {
  name                = "vnet-spoke-compute"
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

data "azurerm_subnet" "subnet_web" {
  name                 = "subnet-web"
  virtual_network_name = data.azurerm_virtual_network.vnet_spoke_compute.name
  resource_group_name  = data.azurerm_resource_group.rg_spoke_compute.name
}

data "azurerm_network_security_group" "nsg_spoke_compute" {
  name                = "nsg-spoke-compute-baseline"
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

# Obtain AKS & Private ACR from Project-11
data "azurerm_resources" "aks_clusters" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.ContainerService/managedClusters"
}

data "azurerm_kubernetes_cluster" "aks_compute" {
  name                = data.azurerm_resources.aks_clusters.resources[0].name
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
}

data "azurerm_resources" "acr_compute" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.ContainerRegistry/registries"
}

# NSG Rules Required for Application Gateway v2 & Hub-to-Spoke Traffic
resource "azurerm_network_security_rule" "nsg_agw_gateway_manager" {
  name                        = "Allow-GatewayManager-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg_hub.name
  network_security_group_name = data.azurerm_network_security_group.nsg_hub.name
}

resource "azurerm_network_security_rule" "nsg_agw_http_inbound" {
  name                        = "Allow-Internet-HTTP-Inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg_hub.name
  network_security_group_name = data.azurerm_network_security_group.nsg_hub.name
}

resource "azurerm_network_security_rule" "nsg_spoke_allow_agw" {
  name                        = "Allow-Hub-AppGW-To-AKS-InternalLB"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "30000-32767"]
  source_address_prefix       = "10.1.4.0/24"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = data.azurerm_resource_group.rg_spoke_compute.name
  network_security_group_name = data.azurerm_network_security_group.nsg_spoke_compute.name
}

resource "azurerm_network_security_rule" "nsg_spoke_allow_azure_lb" {
  name                        = "Allow-AzureLoadBalancer-Probes"
  priority                    = 105
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg_spoke_compute.name
  network_security_group_name = data.azurerm_network_security_group.nsg_spoke_compute.name
}

# Azure Application Gateway WAF v2 in Hub VNet (subnet-appgw: 10.1.4.0/24)
resource "azurerm_public_ip" "pip_agw" {
  name                = "pip-agw-hub-central"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  tags = {
    Env  = "Network-Hub"
    Role = "App-Gateway-PIP"
  }
}

resource "azurerm_web_application_firewall_policy" "waf_policy" {
  name                = "wafpol-agw-hub-zerotrust"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
  location            = var.location

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  tags = {
    Env  = "Network-Hub"
    Role = "WAF-Policy"
  }
}

resource "azurerm_application_gateway" "agw_hub" {
  name                = "agw-hub-zerotrust"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
  location            = var.location
  zones               = ["1", "2", "3"]
  firewall_policy_id  = azurerm_web_application_firewall_policy.waf_policy.id

  sku {
    name = var.agw_sku_name
    tier = var.agw_sku_tier
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "agw-ip-configuration"
    subnet_id = data.azurerm_subnet.subnet_appgw.id
  }

  frontend_port {
    name = "port-http-80"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "agw-frontend-pip"
    public_ip_address_id = azurerm_public_ip.pip_agw.id
  }

  backend_address_pool {
    name         = "be-pool-aks-spoke-compute"
    ip_addresses = ["10.3.1.250"]
  }

  backend_http_settings {
    name                  = "http-setting-aks-80"
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
    probe_name            = "probe-aks-health"
  }

  probe {
    name                = "probe-aks-health"
    host                = "127.0.0.1"
    interval            = 30
    timeout             = 30
    unhealthy_threshold = 3
    protocol            = "Http"
    path                = "/healthz"
  }

  http_listener {
    name                           = "listener-http-80"
    frontend_ip_configuration_name = "agw-frontend-pip"
    frontend_port_name             = "port-http-80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "rule-route-to-aks-spoke"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "listener-http-80"
    backend_address_pool_name  = "be-pool-aks-spoke-compute"
    backend_http_settings_name = "http-setting-aks-80"
  }

  tags = {
    Env  = "Network-Hub"
    Role = "Application-Gateway"
  }

  depends_on = [
    azurerm_network_security_rule.nsg_agw_gateway_manager,
    azurerm_network_security_rule.nsg_agw_http_inbound
  ]
}

# Kubernetes Manifests (Deployment + Internal LB in subnet-web + Calico)
resource "kubectl_manifest" "app_deployment" {
  yaml_body = <<-EOT
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: zero-trust-web-deployment
      namespace: ${var.k8s_namespace}
      labels:
        app: zero-trust-web
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: zero-trust-web
      template:
        metadata:
          labels:
            app: zero-trust-web
            azure.workload.identity/use: "true"
        spec:
          serviceAccountName: ${var.k8s_service_account_name}
          containers:
            - name: web-app
              image: "${data.azurerm_resources.acr_compute.resources[0].name}.azurecr.io/zero-trust-web:${var.app_image_tag}"
              ports:
                - containerPort: 80
              securityContext:
                allowPrivilegeEscalation: false
              resources:
                requests:
                  cpu: "100m"
                  memory: "128Mi"
                limits:
                  cpu: "250m"
                  memory: "256Mi"
              volumeMounts:
                - name: secrets-store01-inline
                  mountPath: "/mnt/secrets-store"
                  readOnly: true
          volumes:
            - name: secrets-store01-inline
              csi:
                driver: secrets-store.csi.k8s.io
                readOnly: true
                volumeAttributes:
                  secretProviderClass: "azure-kvname-wi"
  EOT
}

resource "kubectl_manifest" "app_internal_lb_service" {
  yaml_body = <<-EOT
    apiVersion: v1
    kind: Service
    metadata:
      name: zero-trust-web-ilb
      namespace: ${var.k8s_namespace}
      annotations:
        service.beta.kubernetes.io/azure-load-balancer-internal: "true"
        service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "subnet-web"
        service.beta.kubernetes.io/azure-load-balancer-ipv4: "10.3.1.250"
    spec:
      type: LoadBalancer
      selector:
        app: zero-trust-web
      ports:
        - name: http
          protocol: TCP
          port: 80
          targetPort: 80
  EOT

  depends_on = [kubectl_manifest.app_deployment]
}

resource "kubectl_manifest" "calico_network_policy" {
  yaml_body = <<-EOT
    apiVersion: networking.k8s.io/v1
    kind: NetworkPolicy
    metadata:
      name: allow-only-agw-and-internal
      namespace: ${var.k8s_namespace}
    spec:
      podSelector:
        matchLabels:
          app: zero-trust-web
      policyTypes:
        - Ingress
      ingress:
        - from:
            - ipBlock:
                cidr: 10.1.4.0/24
            - ipBlock:
                cidr: 10.3.0.0/16
            - ipBlock:
                cidr: 192.168.0.0/16
            - ipBlock:
                cidr: 168.63.129.16/32
          ports:
            - protocol: TCP
              port: 80
  EOT

  depends_on = [kubectl_manifest.app_deployment]
}
