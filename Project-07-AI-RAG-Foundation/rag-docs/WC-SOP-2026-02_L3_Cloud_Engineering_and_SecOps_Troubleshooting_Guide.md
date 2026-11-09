# WOJTECH-CLOUD SOLUTIONS: L3 CLOUD ENGINEERING & SECOPS TROUBLESHOOTING RUNBOOK
**Document ID:** WC-SOP-2026-02  
**Owner:** Wojciech Kielbowicz – Principal Cloud Architect  
**Target Audience:** L2/L3 Cloud Operations, SecOps Analysts & AI Copilot Assistants  

---

## 1. Purpose
This technical runbook defines standardized L3 remediation procedures for recurring infrastructure, networking, identity, database, and FinOps incidents across Wojtech-Cloud's managed enterprise client environments.

---

## 2. Standard Remediation Playbooks by Incident Category

### 2.1 Playbook `NET-DNS-01`: Private Endpoint `NXDOMAIN` Resolution Failures in Spoke VNets
* **Related Error Signature:** `NameResolutionFailure: privatelink.*.core.windows.net NXDOMAIN` or `privatelink.database.windows.net NXDOMAIN`.
* **Typical Scenario:** Workloads deployed in a client's Compute Spoke (`vnet-spoke-compute`) or AI Spoke (`vnet-spoke-ai-data`) fail to resolve the private IP (`10.2.1.x`) of a newly provisioned ADLS Gen2 Storage Account, Key Vault, or Azure SQL Server.
* **Root Cause:** The centralized Private DNS Zone in `rg-network-hub` is missing an active **Virtual Network Link (`azurerm_private_dns_zone_virtual_network_link`)** to the affected spoke VNet, or the client VNet is using custom DNS servers without conditional forwarding to Azure DNS (`168.63.129.16`).
* **Mandatory L3 Fix:**
  1. Never create duplicate Private DNS Zones inside spoke resource groups (prevents split-brain DNS).
  2. Update the Terraform `locals { vnets = ... }` map in the client's GitOps repository to ensure `for_each` links the Hub Private DNS Zone to all spoke VNets (`hub`, `spokeai`, `compute`).
  3. Run the GitHub Actions `apply` pipeline and verify `A` record resolution via `nslookup` from the spoke subnet.

---

### 2.2 Playbook `SEC-KV-02`: Unauthorized Public IP Access Attempts on Key Vault / Storage (`HTTP 403`)
* **Related Error Signature:** `Sentinel Alert: HTTP 403 Forbidden Surge on Production Key Vault` or `AuthorizationFailure` in `AzureDiagnostics`.
* **Root Cause:** Developers or external contractors attempting to access Zero Trust PaaS resources (`public_network_access_enabled = false`) directly from home/office public IPs instead of routing through the approved VNet Bastion / Private Endpoint path.
* **Mandatory L3 Fix:**
  1. Query `AzureDiagnostics` in the client's Microsoft Sentinel workspace to extract `CallerIPAddress` and `identity_claim_upn_s`.
  2. **Never enable permanent public network access** to satisfy developer convenience.
  3. Revoke any standing `Key Vault Administrator` or `Storage Blob Data Contributor` privileges granted outside of **Entra ID Privileged Identity Management (PIM)** and instruct the user to connect via the peered VNet jumpbox.

---

### 2.3 Playbook `DB-AUTH-03`: Legacy SQL Login Failures (`SQL Error 18456` for User `sa`)
* **Related Error Signature:** `SQL Error 18456: Login failed for user 'sa' (SQL Authentication Disabled)`.
* **Root Cause:** All Azure SQL Servers deployed by Wojtech-Cloud enforce `azuread_authentication_only = true` to comply with Zero Trust and Checkov security baselines. Legacy applications attempting password-based connection strings are rejected immediately.
* **Mandatory L3 Fix:**
  1. Enable a **System-Assigned Managed Identity** on the client's App Service, Function App, or AKS workload identity.
  2. Connect to the Azure SQL Database using the **EntraAdmin-OIDC** identity and execute:
     ```sql
     CREATE USER [<App-Managed-Identity-Name>] FROM EXTERNAL PROVIDER;
     ALTER ROLE db_datareader ADD MEMBER [<App-Managed-Identity-Name>];
     ALTER ROLE db_datawriter ADD MEMBER [<App-Managed-Identity-Name>];
     ```
  3. Update the application connection string to `Authentication=Active Directory Managed Identity;`.

---

### 2.4 Playbook `FIN-LOG-04`: Log Analytics / Microsoft Sentinel Daily Ingestion Spikes
* **Related Error Signature:** `Azure Cost Management Alert: Daily Spend Spike >100% on Log Analytics`.
* **Root Cause:** Client engineering teams routing high-verbosity application debug logs (`ContainerLogV2`, verbose HTTP trace logs) into the primary **Microsoft Sentinel (`PerGB2018`)** workspace, incurring ~$2.76–$4.30 per GB ingested.
* **Mandatory L3 Fix:**
  1. Immediately apply a Workspace **Daily Cap** if runaway ingestion threatens the monthly budget.
  2. Configure **Data Collection Rules (DCR)** with KQL ingestion-time transformations to drop `Debug` and `Verbose` severity events before they hit the billing pipeline.
  3. Route non-security application telemetry to a separate **Basic Logs** table or cold ADLS Gen2 storage, preserving the central Sentinel workspace strictly for `SecurityEvent`, `AzureDiagnostics` (Key Vault, SQL, NSG), and `SigninLogs`.

---

### 2.5 Playbook `IAM-SYNC-05`: Hybrid Entra Cloud Sync Heartbeat Timeout (`vm-dc01`)
* **Related Error Signature:** `Entra Cloud Sync Quarantine: PasswordHashSync Heartbeat Timeout`.
* **Root Cause:** Outbound TLS 1.2 traffic on port `443` from the on-premises Windows Server Domain Controller (`vm-dc01`) to `*.msappproxy.net` and `*.servicebus.windows.net` is blocked by an NSG or perimeter firewall change.
* **Mandatory L3 Fix:**
  1. Verify that the Windows service **Microsoft Azure AD Connect Provisioning Agent** is running on `vm-dc01`.
  2. Inspect the `nsg-dc01` outbound security rules to ensure port `443` to the `AzureActiveDirectory` and `AzureCloud` service tags is permitted.
  3. Restart the provisioning agent and confirm sync status returns to `Healthy` in the Microsoft Entra admin center within 15 minutes.