#!/bin/bash
TENANT_ID=$(az account management-group list --query "[?displayName=='Tenant Root Group'].name" -o tsv)

echo $TENANT_ID

echo "Creating mg-cloud-portfolio..."

az account management-group create --name "mg-cloud-portfolio" --display-name "Cloud Portfolio" --parent $TENANT_ID

echo "Obtaining policy IDs"
POLICY_LOCATIONS=$(az policy definition list --query "[?contains(displayName, 'Allowed locations')].name" -o tsv | head -n 1)
POLICY_VM_SKUS=$(az policy definition list --query "[?contains(displayName, 'Allowed virtual machine size SKUs')].name" -o tsv | head -n 1)
POLICY_STORAGE_HTTPS=$(az policy definition list --query "[?contains(displayName, 'Secure transfer to storage accounts should be enabled')].name" -o tsv | head -n 1)

POLICY_REQ_RG_TAG=$(az policy definition list --query "[?displayName=='Require a tag on resource groups'].name" -o tsv | head -n 1)
POLICY_KV_DEL_PROT=$(az policy definition list --query "[?displayName=='Key vaults should have deletion protection enabled'].name" -o tsv | head -n 1)
POLICY_INHERIT_TAG=$(az policy definition list --query "[?displayName=='Inherit a tag from the resource group'].name" -o tsv | head -n 1)

echo "All IDs were obtained"

SCOPE="/providers/Microsoft.Management/managementGroups/mg-cloud-portfolio"
REGION="swedencentral"
TAG_NAME="Env"

echo "Creating policies at mg-cloud-project scope"

az policy assignment create --name "allowed-locations" --display-name "Allowed Location (Sweden Central)" --policy $POLICY_LOCATIONS --scope $SCOPE --params '{"listOfAllowedLocations": {"value": ["swedencentral"]}}'
az policy assignment create --name "allowed-vm-skus" --display-name "Allowed VM SKUs series (Standard_D*)" --policy $POLICY_VM_SKUS --scope $SCOPE --params '{"listOfAllowedSKUs": {"value": ["Standard_D2als_v6", "Standard_D2alds_v6", "Standard_D2lds_v6"]}}'
az policy assignment create --name "req-secure-transfer" --display-name "Require HTTPS for Storage Accounts" --policy $POLICY_STORAGE_HTTPS --scope $SCOPE

az policy assignment create --name "req-rg-tag" --display-name "Require an "Env" tag on resource groups" --policy $POLICY_REQ_RG_TAG --scope $SCOPE --params "{\"tagName\": {\"value\": \"$TAG_NAME\"}}"
az policy assignment create --name "kv-deletion-protection" --display-name "Key vaults should have deletion protection enabled" --policy $POLICY_KV_DEL_PROT --scope $SCOPE --params '{"effect": {"value": "Audit"}}'
az policy assignment create --name "inherit-rg-tag" --display-name "Inherit an "Env" tag from the resource group" --policy $POLICY_INHERIT_TAG --scope $SCOPE --params "{\"tagName\": {\"value\": \"$TAG_NAME\"}}" --mi-system-assigned --location $REGION

echo "All policies were created"
