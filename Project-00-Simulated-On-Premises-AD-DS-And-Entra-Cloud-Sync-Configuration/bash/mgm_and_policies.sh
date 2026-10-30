#!/bin/bash
TENANT_ID=$(az account management-group list --query "[?displayName=='Tenant Root Group'].name" -o tsv)

echo $TENANT_ID

echo "Creating mg-cloud-portfolio..."

az account management-group create --name "mg-cloud-portfolio" --display-name "Cloud Portfolio" --parent $TENANT_ID

echo "Obtaining policy IDs"
POLICY_LOCATIONS=$(az policy definition list --query "[?contains(displayName, 'Allowed locations')].name" -o tsv | head -n 1)
POLICY_VM_SKUS=$(az policy definition list --query "[?contains(displayName, 'Allowed virtual machine size SKUs')].name" -o tsv | head -n 1)

POLICY_STORAGE_HTTPS=$(az policy definition list --query "[?contains(displayName, 'Secure transfer to storage accounts should be enabled')].name" -o tsv | head -n 1)
POLICY_MFA_OWNERS=$(az policy definition list --query "[?contains(displayName, 'MFA should be enabled on accounts with owner')].name" -o tsv | head -n 1)

echo "All IDs were obtained"

SCOPE="/providers/Microsoft.Management/managementGroups/mg-cloud-portfolio"
REGION="swedencentral"

echo "Creating policies at mg-cloud-project scope"

az policy assignment create --name "allowed-locations" --display-name "Allowed Location (Sweden Central)" --policy $POLICY_LOCATIONS --scope $SCOPE --params '{"listOfAllowedLocations": {"value": ["swedencentral"]}}'
az policy assignment create --name "allowed-vm-skus" --display-name "Allowed VM SKUs series" --policy $POLICY_VM_SKUS --scope $SCOPE --params '{"listOfAllowedSKUs": {"value": ["Standard_B2als_v2", "Standard_B2ls_v2", "Standard_B2s_v2"]}}'

az policy assignment create --name "req-secure-transfer" --display-name "Require HTTPS for Storage Accounts" --policy $POLICY_STORAGE_HTTPS --scope $SCOPE
az policy assignment create --name "audit-mfa-owners" --display-name "Require MFA for Owners" --policy $POLICY_MFA_OWNERS --scope $SCOPE


echo "All policies were created"
