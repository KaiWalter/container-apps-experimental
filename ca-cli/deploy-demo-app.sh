#!/bin/bash

export RESOURCE_GROUP_NAME="ca-with-cli" # All the resources would be deployed in this resource group
export RESOURCE_GROUP_LOCATION="northeurope" # The resource group would be created in this location

export CONTAINERAPPS_ENVIRONMENT=$(az containerapp env list -g $RESOURCE_GROUP_NAME --query [0].name -o tsv)

az containerapp create \
  --name my-container-app \
  --resource-group $RESOURCE_GROUP_NAME \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --target-port 80 \
  --ingress 'internal' \
  --query configuration.ingress.fqdn
