#!/bin/bash

RESOURCE_GROUP="ca-kw-2"
LOCATION="northeurope"
CONTAINERAPPS_ENVIRONMENT=$(az resource list -g $RESOURCE_GROUP --resource-type Microsoft.App/managedEnvironments --query [0].name -o tsv)
CONTAINERAPPID=$(az containerapp list -g $RESOURCE_GROUP --query "[0].id" -o tsv)
BACKENDURL=`az containerapp show --id $CONTAINERAPPID --query configuration.ingress.fqdn -o tsv`

VNET_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query "[0].id" -o tsv`
SUBNET_APPGW_ID=`az network vnet show --ids $VNET_ID --query "subnets[?name=='appgw'].id" -o tsv`

WORKSPACE_ID=`az monitor log-analytics workspace list -g $RESOURCE_GROUP --query [0].id -o tsv`
WORKSPACE_NAME=`az monitor log-analytics workspace list -g $RESOURCE_GROUP --query [0].name -o tsv`

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file appgw.bicep \
    --parameters appGwName=$CONTAINERAPPS_ENVIRONMENT \
    backendFqdn=$BACKENDURL \
    logWorkspaceId=$WORKSPACE_ID \
    logName=$WORKSPACE_NAME \
    subnetId=$SUBNET_APPGW_ID
