#!/usr/bin/env bash
set -euo pipefail

AGW_IP=$(az network public-ip show -g rg-network-hub -n pip-agw-hub-central --query ipAddress -o tsv)
KV_COMPUTE=$(az keyvault list -g rg-spoke-compute --query "[0].name" -o tsv)


echo " ATTACK SIMULATION -> TARGETING ZERO TRUST ARCHITECTURE "


echo ""
echo "[1/4] Baseline check (legitimate traffic to App Gateway: http://${AGW_IP})"
curl -s -o /dev/null -w "HTTP Status (Expected 200): %{http_code}\n" "http://${AGW_IP}/"

echo ""
echo "[2/4] Attack 1: SQL Injection & XSS against Hub Application Gateway WAF v2 (MITRE T1190)"
curl -s -o /dev/null -w "SQLi Payload -> HTTP Status (Expected 403): %{http_code}\n" \
  "http://${AGW_IP}/?id=1%27%20OR%20%271%27=%271"
curl -s -o /dev/null -w "XSS Payload  -> HTTP Status (Expected 403): %{http_code}\n" \
  "http://${AGW_IP}/?q=<script>alert(1)</script>"
curl -s -o /dev/null -w "Path Trav.   -> HTTP Status (Expected 404): %{http_code}\n" \
  "http://${AGW_IP}/../../etc/passwd"

echo ""
echo "[3/4] Attack 2: Unauthorized Secret Enumeration on Spoke-Compute Key Vault (MITRE T1552)"
curl -s -o /dev/null -w "Key Vault unauthenticated request -> HTTP Status (Expected 401): %{http_code}\n" \
  "https://${KV_COMPUTE}.vault.azure.net/secrets/DatabaseConnectionString?api-version=7.4"

echo ""
echo "[4/4] Attack 3: Manual GitOps / Zero Trust Tampering on AKS (MITRE T1609 / T1562)"
echo "Attempting to delete Calico NetworkPolicy 'allow-only-agw-and-internal'..."
kubectl delete networkpolicy allow-only-agw-and-internal -n default --ignore-not-found

echo ""
echo " Simulation finished! "

