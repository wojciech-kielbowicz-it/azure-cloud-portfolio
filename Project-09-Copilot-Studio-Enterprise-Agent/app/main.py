import os
import socket
import struct
import time
import pyodbc
from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

app = FastAPI(
    title="Wojtech-Cloud Enterprise Zero Trust & Copilot Studio API",
    description="Live Cross-Subsystem Microservice in vnet-spoke-ai-data (10.2.2.0/24) querying Azure SQL & ADLS Gen2 over Private Endpoints (10.2.1.x) via Managed Identity.",
    version="2.1.0",
    servers=[{"url": "https://app-wojtech-copilot-api-34iut3.azurewebsites.net", "description": "Production Zero Trust Endpoint"}]
)

CLIENT_ID = os.getenv("AZURE_CLIENT_ID")
STORAGE_ACCOUNT_NAME = os.getenv("ADLS_ACCOUNT_NAME", "")
SQL_SERVER_FQDN = os.getenv("SQL_SERVER_FQDN", "")
TARGET_SQL_DB = os.getenv("TARGET_SQL_DB", "sqldb-ai-knowledge")

def get_sql_connection():
    """
    Establishes a passwordless connection to Azure SQL Database using an Entra ID OAuth2 access token
    injected into ODBC Driver 18 via SQL_COPT_SS_ACCESS_TOKEN (1256).
    Includes retry logic in case Serverless SQL is waking up from Auto-Pause.
    """
    if not SQL_SERVER_FQDN:
        raise HTTPException(status_code=500, detail="SQL_SERVER_FQDN environment variable is not set.")

    credential = DefaultAzureCredential(managed_identity_client_id=CLIENT_ID)
    token_Object = credential.get_token("https://database.windows.net/.default")
    token_bytes = token_Object.token.encode("UTF-16-LE")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

    # SQL_COPT_SS_ACCESS_TOKEN = 1256
    SQL_COPT_SS_ACCESS_TOKEN = 1256
    conn_str = (
        f"Driver={{ODBC Driver 18 for SQL Server}};"
        f"Server=tcp:{SQL_SERVER_FQDN},1433;"
        f"Database={TARGET_SQL_DB};"
        f"Encrypt=yes;"
        f"TrustServerCertificate=no;"
        f"Connection Timeout=30;"
    )

    last_error = None
    for attempt in range(3):
        try:
            return pyodbc.connect(conn_str, attrs_before={SQL_COPT_SS_ACCESS_TOKEN: token_struct})
        except Exception as e:
            last_error = e
            time.sleep(3)

    raise HTTPException(status_code=500, detail=f"Zero Trust SQL connection failed: {str(last_error)}")


@app.get("/", include_in_schema=False)
def root_redirect():
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["1. System Health"])
def health_check():
    return {
        "status": "Healthy",
        "service": "Wojtech-Cloud Copilot Backend API",
        "vnet_integration_subnet": "vnet-spoke-ai-data / subnet-appservice-integration (10.2.2.0/24)",
        "auth_mode": "User-Assigned Managed Identity (Passwordless)",
        "managed_identity_client_id": CLIENT_ID
    }


@app.get("/api/v1/network-diagnostics", operation_id="GetZeroTrustNetworkDiagnostics", tags=["2. Zero Trust DNS & Routing Verification"])
def verify_private_dns_resolution():
    """
    Resolves PaaS FQDNs from inside the VNet to prove that traffic routes via Hub Private DNS Zones
    to Private Endpoints (10.2.1.x) in the AI Spoke.
    """
    targets = {}
    if STORAGE_ACCOUNT_NAME:
        targets["ADLS_Gen2_Blob"] = f"{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
        targets["ADLS_Gen2_DFS"] = f"{STORAGE_ACCOUNT_NAME}.dfs.core.windows.net"
    if SQL_SERVER_FQDN:
        targets["Azure_SQL_Server"] = SQL_SERVER_FQDN

    results = {}
    for label, fqdn in targets.items():
        try:
            resolved_ip = socket.gethostbyname(fqdn)
            is_private = resolved_ip.startswith("10.")
            results[label] = {
                "fqdn": fqdn,
                "resolved_ip": resolved_ip,
                "zero_trust_private_link_active": is_private
            }
        except Exception as e:
            results[label] = {"fqdn": fqdn, "error": str(e)}

    return {
        "dns_server_used": os.getenv("WEBSITE_DNS_SERVER", "Default"),
        "private_link_resolutions": results
    }


@app.get("/api/v1/datalake-documents", operation_id="ListDataLakeKnowledgeDocs", tags=["3. AI Knowledge Base (ADLS Gen2)"])
def list_knowledge_documents(container_name: str = "ai-knowledge-docs"):
    """
    Connects to ADLS Gen2 using Managed Identity (no storage keys) and lists enterprise markdown documents.
    """
    if not STORAGE_ACCOUNT_NAME:
        raise HTTPException(status_code=500, detail="ADLS_ACCOUNT_NAME environment variable not set.")

    try:
        credential = DefaultAzureCredential(managed_identity_client_id=CLIENT_ID)
        account_url = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
        blob_service_client = BlobServiceClient(account_url=account_url, credential=credential)
        container_client = blob_service_client.get_container_client(container_name)

        blobs = [
            {
                "document_name": blob.name,
                "size_bytes": blob.size,
                "last_modified": str(blob.last_modified)
            }
            for blob in container_client.list_blobs()
        ]

        return {
            "storage_account": STORAGE_ACCOUNT_NAME,
            "container": container_name,
            "authentication": "Entra ID Managed Identity (RBAC: Storage Blob Data Reader)",
            "documents_found": blobs
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Zero Trust Data Lake connection error: {str(e)}")


@app.get("/api/v1/datalake-documents/read", operation_id="ReadDataLakeDocumentContent", tags=["3. AI Knowledge Base (ADLS Gen2)"])
def read_document_content(
    document_name: str = "WC-POL-2026-01_Wojtech_Cloud_MSP_SLA_and_Commercial_Playbook.md",
    container_name: str = "ai-knowledge-docs"
):
    """
    Reads the full Markdown text of a policy or runbook document directly from ADLS Gen2 over Private Endpoint.
    """
    try:
        credential = DefaultAzureCredential(managed_identity_client_id=CLIENT_ID)
        account_url = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
        blob_service_client = BlobServiceClient(account_url=account_url, credential=credential)
        blob_client = blob_service_client.get_blob_client(container=container_name, blob=document_name)
        content = blob_client.download_blob().readall().decode("utf-8")
        return {
            "document_name": document_name,
            "source": f"abfss://{container_name}@{STORAGE_ACCOUNT_NAME}.dfs.core.windows.net/{document_name}",
            "content": content
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to read document from Private Data Lake: {str(e)}")


@app.get("/api/v1/copilot/operations-summary", operation_id="GetWojtechCloudOperations", tags=["4. Live Azure SQL Database Connector (Zero Trust)"])
def get_live_operations_summary():
    """
    Executes live SQL SELECT queries against sqldb-ai-knowledge over Private Endpoint (10.2.1.x)
    using an Entra ID Managed Identity OAuth2 token. Returns real-time Support Tickets and Cloud Migration Projects.
    """
    conn = get_sql_connection()
    try:
        cursor = conn.cursor()

        # Live query <-> vw_WojtechCloudOperations view
        cursor.execute("""
            SELECT TicketNumber, CompanyName, SupportTier, TicketPriority, TicketStatus,
                   ResponseTimeMinutes, GuaranteedResponseMinutes, SLABreached,
                   CAST(MonthlyRetainerEUR AS FLOAT) AS MonthlyRetainerEUR,
                   LeadCloudArchitect, ErrorSignatureOrAlert, RootCauseSummary, ResolutionSteps
            FROM vw_WojtechCloudOperations
            ORDER BY TicketNumber
        """)
        ticket_cols = [col[0] for col in cursor.description]
        tickets = [dict(zip(ticket_cols, row)) for row in cursor.fetchall()]

        # Live query <-> CloudMigrationProjects (joined with ManagedClients & CloudServiceCatalog)
        cursor.execute("""
            SELECT p.ProjectCode, c.CompanyName AS ClientName, s.ServiceName,
                   p.ProjectStatus, p.CompletionPercent,
                   CAST(p.ContractedBudgetEUR AS FLOAT) AS ContractedBudgetEUR,
                   CAST(p.ActualSpendToDateEUR AS FLOAT) AS ActualSpendToDateEUR,
                   CAST(p.TargetGoLiveDate AS VARCHAR(20)) AS TargetGoLiveDate,
                   p.TechnicalRiskNotes
            FROM CloudMigrationProjects p
            INNER JOIN ManagedClients c ON p.ClientID = c.ClientID
            INNER JOIN CloudServiceCatalog s ON p.ServiceID = s.ServiceID
            ORDER BY p.ProjectCode
        """)
        proj_cols = [col[0] for col in cursor.description]
        projects = [dict(zip(proj_cols, row)) for row in cursor.fetchall()]

        resolved_sql_ip = socket.gethostbyname(SQL_SERVER_FQDN)

        return {
            "live_sql_server_fqdn": SQL_SERVER_FQDN,
            "resolved_private_endpoint_ip": resolved_sql_ip,
            "database_name": TARGET_SQL_DB,
            "authentication_used": "Entra ID OAuth2 Token (SQL_COPT_SS_ACCESS_TOKEN / id-wojtech-copilot-api)",
            "live_migration_projects": projects,
            "live_support_escalation_tickets": tickets
        }
    finally:
        conn.close()