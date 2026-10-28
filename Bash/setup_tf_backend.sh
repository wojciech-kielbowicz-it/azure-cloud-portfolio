#!/bin/bash
set -e

RG_NAME="rg-terraform-state"
LOCATION="swedencentral"
STORAGE_ACCOUNT="sttfstatewojtech2026"
CONTAINER_NAME="tfstate"

echo "Creating a resource group: $RG_NAME in $LOCATION..."
az group create --name $RG_NAME --location $LOCATION --tags Env=GitHub

echo

echo "Creating a storage account: $STORAGE_ACCOUNT..."
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RG_NAME \
    --location $LOCATION \
    --sku Standard_LRS \
    --allow-blob-public-access false

echo

echo "Creating a container: $CONTAINER_NAME..."
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT \
    --auth-mode login

echo

echo "All resources were successfully created"
