#!/bin/bash

RESOURCE_GROUP="ca-kw-2"
LOCATION="northeurope"
# CONTAINERAPPS_ENVIRONMENT=$(az containerapp env list -g $RESOURCE_GROUP --query [0].name -o tsv)
CONTAINERAPPS_ENVIRONMENT=$(az resource list -g $RESOURCE_GROUP --resource-type Microsoft.App/managedEnvironments --query [0].name -o tsv)

az containerapp create \
  --name demo-app \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINERAPPS_ENVIRONMENT \
  --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
  --target-port 80 \
  --ingress 'external' \
  --query properties.configuration.ingress.fqdn
