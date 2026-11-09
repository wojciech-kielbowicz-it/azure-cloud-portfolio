-- WOJTECH-CLOUD SOLUTIONS (IT & CLOUD MSP) - ENTERPRISE CRM, PROJECTS & OPS SEED SCRIPT
-- Target Database: sqldb-ai-knowledge



SET NOCOUNT ON;

-- Clean up existing tables/views if re-running the script
IF OBJECT_ID('vw_WojtechCloudOperations', 'V') IS NOT NULL DROP VIEW vw_WojtechCloudOperations;
IF OBJECT_ID('SupportEscalationTickets', 'U') IS NOT NULL DROP TABLE SupportEscalationTickets;
IF OBJECT_ID('CloudMigrationProjects', 'U') IS NOT NULL DROP TABLE CloudMigrationProjects;
IF OBJECT_ID('CloudServiceCatalog', 'U') IS NOT NULL DROP TABLE CloudServiceCatalog;
IF OBJECT_ID('ManagedClients', 'U') IS NOT NULL DROP TABLE ManagedClients;


-- TABLE: ManagedClients (Enterprise IT Clients of Wojtech-Cloud)

CREATE TABLE ManagedClients (
    ClientID INT PRIMARY KEY IDENTITY(100,1),
    ClientCode VARCHAR(20) NOT NULL UNIQUE,
    CompanyName VARCHAR(120) NOT NULL,
    IndustryVertical VARCHAR(60) NOT NULL,
    Country VARCHAR(50) NOT NULL,
    SupportTier VARCHAR(30) NOT NULL, -- Mission-Critical-24x7, Business-Pro, Developer-Standard
    GuaranteedResponseMinutes INT NOT NULL,
    MonthlyRetainerEUR DECIMAL(10,2) NOT NULL,
    MonthlyAzureSpendEUR DECIMAL(12,2) NOT NULL,
    ComplianceFramework VARCHAR(80) NOT NULL, -- DORA / ISO27001, HIPAA / GDPR, SOC2 Type II
    LeadCloudArchitect VARCHAR(80) NOT NULL,
    ContractExpirationDate DATE NOT NULL
);

INSERT INTO ManagedClients (
    ClientCode, CompanyName, IndustryVertical, Country, SupportTier, GuaranteedResponseMinutes,
    MonthlyRetainerEUR, MonthlyAzureSpendEUR, ComplianceFramework, LeadCloudArchitect, ContractExpirationDate
)
VALUES
('WC-CLT-101', 'PayFlow FinTech Bank S.A.', 'Financial Services & Banking', 'Poland', 'Mission-Critical-24x7', 15, 18500.00, 64000.00, 'DORA & ISO/IEC 27001', 'Wojciech Kielbowicz', '2028-06-30'),
('WC-CLT-102', 'NordicMed Diagnostics AB', 'Healthcare & MedTech', 'Sweden', 'Mission-Critical-24x7', 15, 22000.00, 81500.00, 'GDPR & ISO 27799 Health', 'Wojciech Kielbowicz', '2027-12-31'),
('WC-CLT-103', 'OmniCart E-Commerce GmbH', 'Retail & High-Traffic E-Commerce', 'Germany', 'Business-Pro', 60, 9500.00, 42000.00, 'PCI-DSS v4.0 & SOC2', 'Kamil Wisniewski', '2027-05-15'),
('WC-CLT-104', 'LogiTrack Supply SaaS B.V.', 'Logistics & Fleet SaaS', 'Netherlands', 'Business-Pro', 60, 11200.00, 35800.00, 'SOC2 Type II', 'Anna Nowakowska', '2027-09-30'),
('WC-CLT-105', 'PixelForge Game Studios Ltd.', 'Gaming & Digital Media', 'United Kingdom', 'Developer-Standard', 240, 4500.00, 19200.00, 'Standard GDPR', 'Kamil Wisniewski', '2026-12-31'),
('WC-CLT-106', 'AeroSpace Telemetry Corp.', 'Defense & Aviation Software', 'Poland', 'Mission-Critical-24x7', 15, 26000.00, 95000.00, 'NIS2 Directive & ISO 27001', 'Wojciech Kielbowicz', '2028-11-30');


-- TABLE: CloudServiceCatalog (Wojtech-Cloud Managed Services & Architecture Packages)

CREATE TABLE CloudServiceCatalog (
    ServiceID INT PRIMARY KEY IDENTITY(200,1),
    ServiceSKU VARCHAR(30) NOT NULL UNIQUE,
    ServiceName VARCHAR(120) NOT NULL,
    PracticeArea VARCHAR(60) NOT NULL,
    DeliveryCostEUR DECIMAL(10,2) NOT NULL,
    StandardPriceEUR DECIMAL(10,2) NOT NULL,
    TargetMarginPercent DECIMAL(5,2) NOT NULL,
    BillingModel VARCHAR(40) NOT NULL, -- Fixed-Price Project, Monthly Managed Service
    EstimatedDeliveryWeeks INT NOT NULL,
    TechStackScope VARCHAR(200) NOT NULL
);

INSERT INTO CloudServiceCatalog (
    ServiceSKU, ServiceName, PracticeArea, DeliveryCostEUR, StandardPriceEUR, TargetMarginPercent,
    BillingModel, EstimatedDeliveryWeeks, TechStackScope
)
VALUES
('WC-SVC-LZ01', 'Enterprise Azure Landing Zone (CAF + Terraform GitOps)', 'Cloud Infrastructure & IaC', 14000.00, 25000.00, 44.00, 'Fixed-Price Project', 4, 'Hub-and-Spoke VNet, Private DNS, OIDC GitHub Actions, Checkov Policy-as-Code'),
('WC-SVC-SOC02', '24/7 Managed SecOps & Microsoft Sentinel SIEM', 'Cybersecurity & SecOps', 4200.00, 8500.00, 50.59, 'Monthly Managed Service', 2, 'Log Analytics, KQL Analytics Rules, Defender for Cloud XDR, Automated Playbooks'),
('WC-SVC-AI03', 'Private Enterprise RAG & Copilot Studio Accelerator', 'Data & AI Engineering', 18000.00, 32000.00, 43.75, 'Fixed-Price Project', 6, 'ADLS Gen2, Azure SQL Serverless, Azure AI Search, Private Endpoints, Copilot Studio'),
('WC-SVC-ID04', 'Zero Trust Identity & Hybrid AD Modernization', 'Identity & Access (IAM)', 8500.00, 15000.00, 43.33, 'Fixed-Price Project', 3, 'Entra ID, Conditional Access, Privileged Identity Management (PIM), Entra Cloud Sync'),
('WC-SVC-FIN05', 'FinOps Cloud Cost Optimization & Governance Audit', 'Cloud FinOps', 3000.00, 6500.00, 53.85, 'Fixed-Price Project', 2, 'Azure Reservations, Savings Plans, SQL Auto-Pause, Orphaned Resource Cleanup'),
('WC-SVC-AKS06', 'Production Kubernetes (AKS) Zero Trust Platform', 'Cloud Native & Containers', 16000.00, 28000.00, 42.86, 'Fixed-Price Project', 5, 'Private AKS Cluster, Azure CNI Overlay, Key Vault CSI Driver, Defender for Containers');


-- TABLE: CloudMigrationProjects (Active Consulting & Engineering Engagements)

CREATE TABLE CloudMigrationProjects (
    ProjectID INT PRIMARY KEY IDENTITY(500,1),
    ProjectCode VARCHAR(30) NOT NULL UNIQUE,
    ClientID INT NOT NULL FOREIGN KEY REFERENCES ManagedClients(ClientID),
    ServiceID INT NOT NULL FOREIGN KEY REFERENCES CloudServiceCatalog(ServiceID),
    ProjectStatus VARCHAR(40) NOT NULL, -- On-Track, Delayed-Client-Blocker, In-UAT-Testing, Completed
    CompletionPercent INT NOT NULL,
    ContractedBudgetEUR DECIMAL(12,2) NOT NULL,
    ActualSpendToDateEUR DECIMAL(12,2) NOT NULL,
    StartDate DATE NOT NULL,
    TargetGoLiveDate DATE NOT NULL,
    TechnicalRiskNotes VARCHAR(450) NOT NULL
);

INSERT INTO CloudMigrationProjects (
    ProjectCode, ClientID, ServiceID, ProjectStatus, CompletionPercent, ContractedBudgetEUR,
    ActualSpendToDateEUR, StartDate, TargetGoLiveDate, TechnicalRiskNotes
)
VALUES
('PRJ-WC-2026-01', 100, 200, 'Completed', 100, 25000.00, 23400.00, '2026-06-01', '2026-07-05', 'Successfully migrated PayFlow core banking workloads into Sweden Central Hub-and-Spoke Landing Zone with 100% Checkov compliance.'),
('PRJ-WC-2026-02', 101, 202, 'In-UAT-Testing', 85, 32000.00, 27800.00, '2026-09-15', '2026-11-20', 'Private RAG pipeline indexing clinical trial PDFs in ADLS Gen2; final semantic ranker tuning in progress for Copilot Studio agent.'),
('PRJ-WC-2026-03', 102, 205, 'Delayed-Client-Blocker', 60, 28000.00, 21500.00, '2026-08-10', '2026-11-30', 'Delayed by 14 days because OmniCart legacy payment gateway still relies on hardcoded static IP whitelisting instead of Private Link.'),
('PRJ-WC-2026-04', 105, 201, 'On-Track', 75, 17000.00, 12100.00, '2026-10-01', '2026-11-25', 'Onboarding AeroSpace NSG flow logs and Key Vault audit trails into Microsoft Sentinel workspace to meet NIS2 directive requirements.'),
('PRJ-WC-2026-05', 103, 204, 'On-Track', 90, 6500.00, 5800.00, '2026-10-20', '2026-11-15', 'Identified 38% monthly savings ($14,200/yr) by converting idle development SQL databases to GP_S_Gen5 Serverless with 60-minute auto-pause.'),
('PRJ-WC-2026-06', 104, 203, 'On-Track', 40, 15000.00, 6200.00, '2026-10-25', '2026-12-10', 'Decommissioning legacy ADFS servers and migrating hybrid identity sync to Microsoft Entra Cloud Sync with FIDO2 MFA enforcement.');


-- TABLE: SupportEscalationTickets (L2/L3 Cloud Ops, SecOps & FinOps Incidents)

CREATE TABLE SupportEscalationTickets (
    TicketID INT PRIMARY KEY IDENTITY(9000,1),
    TicketNumber VARCHAR(30) NOT NULL UNIQUE,
    ClientID INT NOT NULL FOREIGN KEY REFERENCES ManagedClients(ClientID),
    Category VARCHAR(50) NOT NULL, -- SecOps-Alert, Networking-DNS, FinOps-Anomaly, Database-Auth, Identity-Sync
    Priority VARCHAR(20) NOT NULL, -- P1-Critical, P2-High, P3-Medium, P4-Low
    Status VARCHAR(30) NOT NULL,   -- Open-Investigating, Mitigated, Resolved-Permanent, Closed-RCA-Sent
    ResponseTimeMinutes INT NOT NULL,
    SLABreached BIT NOT NULL,
    AssignedEngineer VARCHAR(80) NOT NULL,
    ErrorSignatureOrAlert VARCHAR(120) NOT NULL,
    RootCauseSummary VARCHAR(500) NOT NULL,
    ResolutionSteps VARCHAR(500) NOT NULL,
    CreatedAtUTC DATETIME NOT NULL
);

INSERT INTO SupportEscalationTickets (
    TicketNumber, ClientID, Category, Priority, Status, ResponseTimeMinutes, SLABreached,
    AssignedEngineer, ErrorSignatureOrAlert, RootCauseSummary, ResolutionSteps, CreatedAtUTC
)
VALUES
('TCK-WC-701', 100, 'SecOps-Alert', 'P1-Critical', 'Closed-RCA-Sent', 8, 0, 'Wojciech Kielbowicz',
 'Sentinel Alert: HTTP 403 Forbidden Surge on Production Key Vault',
 'An external contractor attempted to run a local Python script from an unapproved home IP address to pull database secrets from PayFlow production Key Vault.',
 'Key Vault firewall (public_network_access_enabled = false) blocked all requests automatically. Revoked contractor temporary RBAC role and enforced Bastion jumpbox policy.',
 DATEADD(DAY, -10, GETUTCDATE())),

('TCK-WC-702', 101, 'Networking-DNS', 'P2-High', 'Resolved-Permanent', 12, 0, 'Wojciech Kielbowicz',
 'NameResolutionFailure: privatelink.dfs.core.windows.net NXDOMAIN',
 'Data scientists in NordicMed Compute Spoke VNet could not resolve the new ADLS Gen2 Private Endpoint hostname during AI model training.',
 'Added missing azurerm_private_dns_zone_virtual_network_link between privatelink.dfs.core.windows.net in the Hub RG and vnet-spoke-compute via Terraform GitOps pipeline.',
 DATEADD(DAY, -6, GETUTCDATE())),

('TCK-WC-703', 102, 'FinOps-Anomaly', 'P2-High', 'Resolved-Permanent', 75, 1, 'Kamil Wisniewski',
 'Azure Cost Management Alert: Daily Spend Spike +240% on Log Analytics',
 'OmniCart development team enabled verbose debug tracing on 14 microservices, ingesting 480 GB/day of non-security telemetry into the central Sentinel workspace.',
 'Separated application performance logs into Basic-tier Container Insights and restricted central Sentinel workspace to security-critical AuditEvent and NSG logs.',
 DATEADD(DAY, -4, GETUTCDATE())),

('TCK-WC-704', 103, 'Database-Auth', 'P3-Medium', 'Resolved-Permanent', 25, 0, 'Anna Nowakowska',
 'SQL Error 18456: Login failed for user sa (SQL Authentication Disabled)',
 'LogiTrack legacy reporting service failed to connect after database migration because Microsoft Entra-only authentication was enforced on the target Azure SQL Server.',
 'Configured System-Assigned Managed Identity for the reporting App Service and granted db_datareader permissions in Azure SQL using Entra ID token authentication.',
 DATEADD(DAY, -2, GETUTCDATE())),

('TCK-WC-705', 105, 'Identity-Sync', 'P1-Critical', 'Open-Investigating', 11, 0, 'Wojciech Kielbowicz',
 'Entra Cloud Sync Quarantine: PasswordHashSync Heartbeat Timeout',
 'On-premises domain controller vm-dc01 in AeroSpace hybrid enclave lost outbound HTTPS (port 443) connectivity to Microsoft Entra endpoints after local firewall update.',
 'Emergency bridge call active with client network team; whitelisting required Azure AD Hybrid service tags on perimeter firewall.',
 DATEADD(HOUR, -5, GETUTCDATE()));


-- VIEW: vw_WojtechCloudOperations (Unified View for Azure AI Search & Copilot Studio)

GO
CREATE VIEW vw_WojtechCloudOperations AS
SELECT 
    t.TicketNumber,
    t.Category AS TicketCategory,
    t.Priority AS TicketPriority,
    t.Status AS TicketStatus,
    t.ResponseTimeMinutes,
    t.SLABreached,
    t.AssignedEngineer,
    t.ErrorSignatureOrAlert,
    t.RootCauseSummary,
    t.ResolutionSteps,
    c.ClientCode,
    c.CompanyName,
    c.IndustryVertical,
    c.Country,
    c.SupportTier,
    c.GuaranteedResponseMinutes,
    c.MonthlyRetainerEUR,
    c.MonthlyAzureSpendEUR,
    c.ComplianceFramework,
    c.LeadCloudArchitect
FROM SupportEscalationTickets t
INNER JOIN ManagedClients c ON t.ClientID = c.ClientID;
GO


SELECT * FROM ManagedClients ORDER BY MonthlyRetainerEUR DESC;
SELECT * FROM CloudServiceCatalog;
SELECT * FROM CloudMigrationProjects;
SELECT * FROM vw_WojtechCloudOperations;