#!/bin/bash

RESOURCE_GROUP="ca-kw-2"
LOCATION="northeurope"

CONTAINERAPPS_ENVIRONMENT=$(az resource list -g $RESOURCE_GROUP --resource-type Microsoft.App/managedEnvironments --query [0].name -o tsv)
ENVIRONMENT_DEFAULT_DOMAIN=`az containerapp env show --name ${CONTAINERAPPS_ENVIRONMENT} --resource-group ${RESOURCE_GROUP} --query defaultDomain -o tsv --only-show-errors`
ENVIRONMENT_STATIC_IP=`az containerapp env show --name ${CONTAINERAPPS_ENVIRONMENT} --resource-group ${RESOURCE_GROUP} --query staticIp -o tsv --only-show-errors`

VNET_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query "[0].id" -o tsv`

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file privatedns.bicep \
    --parameters "{\"pepIp\": {\"value\": \"$ENVIRONMENT_STATIC_IP\"},\"vnetId\": {\"value\": \"$VNET_ID\"},\"domain\": {\"value\": \"$ENVIRONMENT_DEFAULT_DOMAIN\"}}"
