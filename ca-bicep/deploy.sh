#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw"

if [ $(az group exists --name $RESOURCE_GROUP) = false ]; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file main.bicep \
    --parameters environmentName=$ENVIRONMENTNAME

ENVIRONMENT_DEFAULT_DOMAIN=`az containerapp env show --name ${ENVIRONMENTNAME} --resource-group ${RESOURCE_GROUP} --query defaultDomain --out json | tr -d '"'`
ENVIRONMENT_STATIC_IP=`az containerapp env show --name ${ENVIRONMENTNAME} --resource-group ${RESOURCE_GROUP} --query staticIp --out json | tr -d '"'`
VNET_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query [0].id --out tsv`
VNET_NAME=`az network vnet show --ids ${VNET_ID} --query name --out tsv`

az network private-dns zone create \
  --resource-group $RESOURCE_GROUP \
  --name $ENVIRONMENT_DEFAULT_DOMAIN

az network private-dns link vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --virtual-network $VNET_ID \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN -e true

az network private-dns record-set a add-record \
  --resource-group $RESOURCE_GROUP \
  --record-set-name "*" \
  --ipv4-address $ENVIRONMENT_STATIC_IP \
  --zone-name $ENVIRONMENT_DEFAULT_DOMAIN
