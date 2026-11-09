# WOJTECH-CLOUD SOLUTIONS: MANAGED CLOUD SERVICES SLA, PRICING & GOVERNANCE PLAYBOOK
**Document ID:** WC-POL-2026-01  
**Version:** 4.0 (2026 Commercial Baseline)  
**Company:** Wojtech-Cloud Solutions (Enterprise Azure & AI Architecture Consultancy)  
**Managing Principal & Founder:** Wojciech Kielbowicz  
**Classification:** Internal Confidential – Sales, Delivery & Cloud Ops  

---

## 1. Company Overview & Mission
**Wojtech-Cloud Solutions** is a specialized Managed Cloud Service Provider (MSP) and Azure Architecture Consultancy delivering high-security **Zero Trust Landing Zones**, **24/7 Microsoft Sentinel SecOps**, and **Private Enterprise AI (RAG / Copilot Studio)** platforms across Europe. Our engineering standards mandate 100% Infrastructure-as-Code (Terraform + GitHub Actions OIDC) and strict compliance with **DORA**, **NIS2**, **ISO/IEC 27001**, and **PCI-DSS v4.0**.

---

## 2. Managed Support Tiers, SLA Response Times & Penalty Credits
Every managed client onboarded to Wojtech-Cloud is assigned one of three support tiers. Initial response time is measured from ticket creation in our ITSM portal or automated Microsoft Sentinel alert generation to active triage by an L2/L3 Cloud Engineer.

| Support Tier | P1-Critical Response | P2-High Response | Minimum Monthly Retainer | SLA Breach Service Credit Penalty |
| :--- | :--- | :--- | :--- | :--- |
| **Mission-Critical-24x7** | **15 Minutes** (24/7/365) | **30 Minutes** | **15,000 EUR / month** | **5.0% credit** of Monthly Retainer per breached P1/P2 incident (capped at 25% monthly) |
| **Business-Pro** | **60 Minutes** (Business Hours) | **120 Minutes** | **8,000 EUR / month** | **2.5% credit** of Monthly Retainer per breached P1/P2 incident (capped at 10% monthly) |
| **Developer-Standard** | **240 Minutes** (8x5) | **Next Business Day** | **4,000 EUR / month** | Best-effort resolution; no financial penalty credits |

### 2.1 SLA Breach Handling Protocol (`SLABreached = 1`)
If a ticket's `ResponseTimeMinutes` exceeds the client's `GuaranteedResponseMinutes` (for example, responding in 75 minutes to a **Business-Pro** client whose SLA guarantees 60 minutes), the assigned engineer must:
1. Flag `SLABreached = 1` in the `SupportEscalationTickets` database.
2. Notify the **Lead Cloud Architect** within 2 hours.
3. Automatically apply the corresponding **Service Credit Penalty** (e.g., **2.5% of Monthly Retainer** for Business-Pro) to the client's next monthly invoice alongside a formal Root Cause Analysis (RCA) document.

---

## 3. Commercial Pricing, Margin Floors & Project Change Requests

### 3.1 Fixed-Price Architecture Packages
All fixed-price consulting packages in the `CloudServiceCatalog` (such as `WC-SVC-LZ01` Enterprise Landing Zone or `WC-SVC-AI03` Private RAG Accelerator) must maintain a minimum target gross margin of **40.0%**.
* **Discount Authority:** Lead Cloud Architects may approve up to a **10% bundle discount** when a client signs a 24-month **Mission-Critical-24x7** retainer alongside an implementation project.

### 3.2 Handling Client-Induced Project Delays (`Delayed-Client-Blocker`)
When an active engagement in `CloudMigrationProjects` enters **`Delayed-Client-Blocker`** status for more than **10 calendar days** (for instance, due to legacy client applications requiring static IP whitelisting instead of Azure Private Endpoints):
1. Wojtech-Cloud pauses the fixed-price project burn rate and places the engineering pod on standby.
2. A **Standby Retainer Fee of 1,500 EUR per week** is billed after day 10 until the client resolves the legacy dependency, OR a **Change Request (CR)** is signed to refactor the legacy component into a compliant Private Link architecture.

---

## 4. FinOps Managed Governance Guarantee
For clients purchasing the **FinOps Cloud Cost Optimization Audit (`WC-SVC-FIN05`)**, Wojtech-Cloud guarantees identifying at least **20% in annual Azure compute/database savings** through:
* Migrating bursty development and AI SQL workloads to **Azure SQL Serverless (`GP_S_Gen5`)** with a **60-minute auto-pause delay**.
* Enforcing automated **Deallocation schedules** on non-production and hybrid lab virtual machines outside business hours.
* Splitting high-volume application debug logs away from security-critical **Microsoft Sentinel (`PerGB2018`)** workspaces into low-cost Basic Logs or Azure Storage archive tiers.