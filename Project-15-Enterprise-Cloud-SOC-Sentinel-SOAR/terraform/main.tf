data "azurerm_client_config" "current" {}

# Obtain Central SecOps & Sentinel Resources from Project-05
data "azurerm_resource_group" "rg_secops" {
  name = var.secops_rg_name
}

data "azurerm_log_analytics_workspace" "law" {
  name                = var.law_name
  resource_group_name = data.azurerm_resource_group.rg_secops.name
}

# Obtain Hub & Spoke Resource Groups from Project-03
data "azurerm_resource_group" "rg_hub" {
  name = "rg-network-hub"
}

data "azurerm_resource_group" "rg_spoke_compute" {
  name = "rg-spoke-compute"
}

# Obtain Hub Resources from Project-03 & Project-13
data "azurerm_application_gateway" "agw_hub" {
  name                = "agw-hub-zerotrust"
  resource_group_name = data.azurerm_resource_group.rg_hub.name
}

data "azurerm_resources" "fw_hub" {
  resource_group_name = data.azurerm_resource_group.rg_hub.name
  type                = "Microsoft.Network/azureFirewalls"
}

# Obtain Spoke Compute Resources from Project-11 & Project-12
data "azurerm_resources" "kv_compute" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.KeyVault/vaults"
}

data "azurerm_resources" "aks_compute" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.ContainerService/managedClusters"
}

data "azurerm_resources" "acr_compute" {
  resource_group_name = data.azurerm_resource_group.rg_spoke_compute.name
  type                = "Microsoft.ContainerRegistry/registries"
}

# Diagnostic Settings -> Central Microsoft Sentinel (Hub & Spoke Compute)
resource "azurerm_monitor_diagnostic_setting" "diag_agw_hub" {
  name                       = "diag-agw-hub-to-sentinel"
  target_resource_id         = data.azurerm_application_gateway.agw_hub.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_kv_compute" {
  count                      = length(data.azurerm_resources.kv_compute.resources) > 0 ? 1 : 0
  name                       = "diag-kv-spoke-compute-to-sentinel"
  target_resource_id         = data.azurerm_resources.kv_compute.resources[0].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "audit"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_aks_compute" {
  count                      = length(data.azurerm_resources.aks_compute.resources) > 0 ? 1 : 0
  name                       = "diag-aks-compute-to-sentinel"
  target_resource_id         = data.azurerm_resources.aks_compute.resources[0].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "kube-audit"
  }

  enabled_log {
    category = "kube-audit-admin"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_acr_compute" {
  count                      = length(data.azurerm_resources.acr_compute.resources) > 0 ? 1 : 0
  name                       = "diag-acr-compute-to-sentinel"
  target_resource_id         = data.azurerm_resources.acr_compute.resources[0].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "diag_fw_hub" {
  count                      = length(data.azurerm_resources.fw_hub.resources) > 0 ? 1 : 0
  name                       = "diag-afw-hub-to-sentinel"
  target_resource_id         = data.azurerm_resources.fw_hub.resources[0].id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id

  enabled_log {
    category_group = "allLogs"
  }
}

# Sentinel Alert Rule: Application Gateway WAF v2 Attack Detection (SQLi / XSS / OWASP)
resource "azurerm_sentinel_alert_rule_scheduled" "waf_attack_detection" {
  name                       = "rule-waf-owasp-attack-detection-p15"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  display_name               = "WAF v2 - Blocked Web Attack (SQLi/XSS/OWASP)"
  description                = "Detects blocked HTTP/OWASP attacks on Hub Application Gateway WAF v2 (Project-13)."
  severity                   = "High"
  enabled                    = true
  query_frequency            = "PT5M"
  query_period               = "PT5M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["InitialAccess"]
  techniques                 = ["T1190"]

  query = <<-EOT
    AzureDiagnostics
    | where ResourceType == "APPLICATIONGATEWAYS"
    | where Category == "ApplicationGatewayFirewallLog"
    | extend Action = column_ifexists("action_s", ""),
             ClientIP = column_ifexists("clientIp_s", ""),
             RuleId = column_ifexists("ruleId_s", ""),
             RequestUri = column_ifexists("requestUri_s", "")
    | where Action == "Blocked"
    | summarize AttackCount = count(), Rules = make_set(RuleId), URIs = make_set(RequestUri) by ClientIP, Resource
  EOT

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "ClientIP"
    }
  }
}

# Sentinel Alert Rule: Key Vault Unauthorized Access (Spoke-AI & Spoke-Compute)
resource "azurerm_sentinel_alert_rule_scheduled" "kv_unauthorized_access" {
  name                       = "rule-kv-unauthorized-access-p15"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  display_name               = "Key Vault - Unauthorized Access Attempt (401/403)"
  description                = "Detects failed authentication or forbidden secret access on Spoke-AI and Spoke-Compute Key Vaults."
  severity                   = "Medium"
  enabled                    = true
  query_frequency            = "PT10M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["CredentialAccess"]
  techniques                 = ["T1552"]

  query = <<-EOT
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | where httpStatusCode_d in (401, 403)
    | summarize FailedAttempts = count(), Operations = make_set(OperationName) by CallerIPAddress, identity_claim_upn_s, Resource
  EOT

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CallerIPAddress"
    }
  }
}

# Sentinel Alert Rule: AKS Suspicious Activity (Pod Exec, NetworkPolicy or ArgoCD Tampering)
resource "azurerm_sentinel_alert_rule_scheduled" "aks_suspicious_activity" {
  name                       = "rule-aks-suspicious-activity-p15"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  display_name               = "AKS - Suspicious Pod Exec or GitOps/NetworkPolicy Tampering"
  description                = "Detects interactive kubectl exec, NetworkPolicy deletion, or manual tampering with ArgoCD/GitOps workloads (Project-11/14)."
  severity                   = "High"
  enabled                    = true
  query_frequency            = "PT5M"
  query_period               = "PT5M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["Execution", "DefenseEvasion", "Impact"]
  techniques                 = ["T1609", "T1562"]

  query = <<-EOT
    AzureDiagnostics
    | where Category in ("kube-audit", "kube-audit-admin")
    | extend audit = parse_json(column_ifexists("log_s", "{}"))
    | extend Verb = tostring(audit.verb),
             User = tostring(audit.user.username),
             Namespace = tostring(audit.objectRef.namespace),
             ResourceName = tostring(audit.objectRef.name),
             Subresource = tostring(audit.objectRef.subresource)
    | where User !startswith "system:serviceaccount:argocd:"
    | where (Verb == "create" and Subresource == "exec")
       or (Verb in ("delete", "patch", "update") and ResourceName in ("zero-trust-web-deployment", "zero-trust-web-ilb", "allow-only-agw-and-internal", "zero-trust-web-gitops"))
       or (Verb == "delete" and Namespace == "argocd")
    | project TimeGenerated, Verb, User, Namespace, ResourceName, Subresource
  EOT
}

# Sentinel Alert Rule: Data Platform Unauthorized Access (ADLS Gen2 / SQL from Project-06)
resource "azurerm_sentinel_alert_rule_scheduled" "data_platform_anomaly" {
  name                       = "rule-data-platform-unauthorized-access-p15"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  display_name               = "Data Platform - Failed SQL or ADLS Gen2 Access"
  description                = "Monitors ADLS Gen2 and SQL logs (ingested in Project-06) for failed access attempts."
  severity                   = "Medium"
  enabled                    = true
  query_frequency            = "PT10M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["Collection", "Exfiltration"]

  query = <<-EOT
    StorageBlobLogs
    | where StatusCode in (401, 403)
    | summarize FailedCount = count(), Operations = make_set(OperationName) by CallerIpAddress, AccountName
  EOT

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CallerIpAddress"
    }
  }
}

# Sentinel Alert Rule: Copilot API Web App Unauthorized Access / 5xx Anomaly (Project-08)
resource "azurerm_sentinel_alert_rule_scheduled" "copilot_api_anomaly" {
  name                       = "rule-copilot-api-http-anomaly-p15"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  display_name               = "Copilot API Web App - Unauthorized Access or Server Errors"
  description                = "Monitors Private Copilot API Web App (Project-08) for 401/403/5xx spikes."
  severity                   = "Medium"
  enabled                    = true
  query_frequency            = "PT10M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["InitialAccess", "Impact"]
  techniques                 = ["T1190"]

  query = <<-EOT
    AppServiceHTTPLogs
    | where ScStatus in (401, 403, 500, 502, 503)
    | summarize ErrorCount = count(), Paths = make_set(CsUriStem) by CIp, _ResourceId
    | where ErrorCount >= 3
  EOT

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CIp"
    }
  }
}

# Sentinel Alert Rule: Azure AI Services / OpenAI Unauthorized Access or Quota Abuse (Project-09)
resource "azurerm_sentinel_alert_rule_scheduled" "ai_services_anomaly" {
  name                       = "rule-ai-services-unauthorized-abuse-p15"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  display_name               = "Azure AI Services - Unauthorized API Calls or Throttling Spike"
  description                = "Detects 401/403 unauthorized attempts or 429 abuse spikes on OpenAI/AI Services (Project-09)."
  severity                   = "Medium"
  enabled                    = true
  query_frequency            = "PT10M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  tactics                    = ["InitialAccess", "Impact"]
  techniques                 = ["T1190"]

  query = <<-EOT
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
    | where Category in ("Audit", "RequestResponse")
    | where ResultSignature in ("401", "403", "429")
    | summarize EventCount = count(), Operations = make_set(OperationName) by CallerIPAddress, Resource
    | where EventCount >= 3
  EOT

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CallerIPAddress"
    }
  }
}

# SOAR Playbook (Azure Logic App with Managed Identity)
resource "azurerm_logic_app_workflow" "soc_playbook" {
  name                = "playbook-soc-incident-triage"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg_secops.name

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Env  = "SecOps"
    Role = "SOAR-Playbook"
  }
}

resource "azurerm_role_assignment" "playbook_sentinel_responder" {
  scope                = data.azurerm_resource_group.rg_secops.id
  role_definition_name = "Microsoft Sentinel Responder"
  principal_id         = azurerm_logic_app_workflow.soc_playbook.identity[0].principal_id
}

# Sentinel Automation Rule (Auto-Triage SOC Incidents)
resource "azurerm_sentinel_automation_rule" "auto_triage_high" {
  name                       = "b5e8f2a1-4c3d-4e5f-9a1b-2c3d4e5f6a7b"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.law.id
  display_name               = "Auto-Triage Enterprise SOC Incidents"
  order                      = 1
  enabled                    = true

  action_incident {
    order  = 1
    status = "Active"
    labels = ["Auto-Triaged", "Project-15-SOC"]
  }

  depends_on = [azurerm_role_assignment.playbook_sentinel_responder]
}

