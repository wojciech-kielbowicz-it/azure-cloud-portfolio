import os
import socket
from fastapi import FastAPI, HTTPException
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

app = FastAPI(
    title="Wojtech-Cloud Enterprise Zero Trust & Copilot API",
    description="Cross-Spoke Microservice hosted in vnet-spoke-compute communicating privately with vnet-spoke-ai-data via Private Endpoints & Managed Identity.",
    version="1.0.0"
)

# Read environment variables injected by Terraform
CLIENT_ID = os.getenv("AZURE_CLIENT_ID")
STORAGE_ACCOUNT_NAME = os.getenv("ADLS_ACCOUNT_NAME", "")
SQL_SERVER_FQDN = os.getenv("SQL_SERVER_FQDN", "")

@app.get("/health", tags=["System Health"])
def health_check():
    return {
        "status": "Healthy",
        "service": "Wojtech-Cloud Copilot Backend API",
        "spoke_network": "vnet-spoke-compute (10.3.2.0/24)",
        "auth_mode": "User-Assigned Managed Identity (Passwordless)",
        "managed_identity_client_id": CLIENT_ID
    }

@app.get("/api/v1/network-diagnostics", tags=["Zero Trust DNS & Routing Verification"])
def verify_private_dns_resolution():
    """
    Resolves PaaS FQDNs from inside the Compute Spoke VNet to prove that traffic 
    routes via Hub Private DNS Zones to Private Endpoints (10.2.1.x) in the AI Spoke.
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
        "cross_spoke_resolutions": results
    }

@app.get("/api/v1/datalake-documents", tags=["AI Knowledge Base (ADLS Gen2)"])
def list_knowledge_documents(container_name: str = "ai-knowledge-docs"):
    """
    Connects to ADLS Gen2 in vnet-spoke-ai-data using Managed Identity (no storage keys)
    and lists enterprise markdown documents used for Copilot Studio RAG.
    """
    if not STORAGE_ACCOUNT_NAME:
        raise HTTPException(status_code=500, detail="ADLS_ACCOUNT_NAME environment variable not set.")

    try:
        credential = DefaultAzureCredential(managed_identity_client_id=CLIENT_ID)
        account_url = f"https://{STORAGE_ACCOUNT_NAME}.blob.core.windows.net"
        blob_service_client = BlobServiceClient(account_url=account_url, credential=credential)
        container_client = blob_service_client.get_container_client(container_name)

        blobs = []
        for blob in container_client.list_blobs():
            blobs.append({
                "document_name": blob.name,
                "size_bytes": blob.size,
                "last_modified": str(blob.last_modified)
            })

        return {
            "storage_account": STORAGE_ACCOUNT_NAME,
            "container": container_name,
            "authentication": "Entra ID Managed Identity (RBAC: Storage Blob Data Reader)",
            "documents_found": blobs
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Zero Trust Data Lake connection error: {str(e)}")