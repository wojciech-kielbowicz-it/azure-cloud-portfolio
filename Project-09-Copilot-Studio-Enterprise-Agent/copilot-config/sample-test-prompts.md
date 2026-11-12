# Copilot Agent – Test Queries

Test prompts used to verify RAG (ADLS Gen2 docs) and live SQL API integration (`sqldb-ai-knowledge`[cite: 3]).

## 1. SLA breach & service credit calculation
**Prompt:**
`Check active support tickets in the database. Did we breach SLA for any client? Calculate the exact EUR penalty based on our SLA policy.`

**Expected result:**
- Pulls `TCK-WC-703` (**OmniCart E-Commerce GmbH**, `Business-Pro` tier, 9,500 EUR/mo retainer) from SQL.
- Response time was 75 min vs 60 min SLA (`SLABreached = 1`).
- Matches `Business-Pro` penalty in `WC-POL-2026-01`[cite: 3] (2.5% of monthly retainer) -> **237.50 EUR** credit.

## 2. Delayed migration project & standby fee
**Prompt:**
`Which migration project is currently blocked by the client? What is the technical blocker and what fee applies per our commercial policy?`

**Expected result:**
- Pulls `PRJ-WC-2026-03` (OmniCart AKS migration) with status `Delayed-Client-Blocker` (14 days delay due to legacy static IP whitelisting).
- Matches section 3.2 in `WC-POL-2026-01`[cite: 3] (>10 days delay) -> **1,500 EUR/week** standby fee or Change Request for Private Link.

## 3. SQL auth troubleshooting (Error 18456)
**Prompt:**
`How was ticket TCK-WC-704 resolved, and what SQL commands does our L3 runbook require for Error 18456?`

**Expected result:**
- Identifies `TCK-WC-704` (LogiTrack Supply SaaS – `sa` login disabled due to Entra-only auth).
- Pulls T-SQL fix from `WC-SOP-2026-02`[cite: 3] (`DB-AUTH-03`):
  `CREATE USER [<App-MI>] FROM EXTERNAL PROVIDER;` and `ALTER ROLE db_datareader ADD MEMBER [<App-MI>];`.

## 4. Open P1 incident triage
**Prompt:**
`Are there any open P1 tickets right now? Give me the root cause from SQL and remediation steps from the SOP.`

**Expected result:**
- Finds `TCK-WC-705` (AeroSpace Telemetry Corp, `Open-Investigating`, assigned to Wojciech Kielbowicz).
- Issue: `vm-dc01` lost outbound 443 connectivity for Entra Cloud Sync.
- Pulls steps from `WC-SOP-2026-02`[cite: 3] (`IAM-SYNC-05`): check provisioning agent service and allow port 443 to `AzureActiveDirectory` service tag.

## 5. Private DNS & VNet diagnostics
**Prompt:**
`Run network diagnostics from the backend API and check if Storage and SQL resolve to private IPs.`

**Expected result:**
- Calls `/api/v1/network-diagnostics`[cite: 4].
- Confirms `blob`, `dfs`, and `database` endpoints resolve to `10.2.1.x`[cite: 1, 3] via `168.63.129.16`[cite: 3].