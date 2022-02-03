#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
LOG_ANALYTICS_WORKSPACE="ca-kw-logs"
CONTAINERAPPS_ENVIRONMENT="ca-kw-$(( $RANDOM % 1000 ))"
VNET_NAME="ca-kw-vnet"
VM="ca-kw-jump"

az group create --name $RESOURCE_GROUP --location $LOCATION

az network vnet create \
  --resource-group $RESOURCE_GROUP \
  --name $VNET_NAME \
  --location $LOCATION \
  --address-prefix 10.0.0.0/16

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name control-plane \
  --address-prefixes 10.0.0.0/21

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name applications \
  --address-prefixes 10.0.8.0/21

az network vnet subnet create \
  --resource-group $RESOURCE_GROUP \
  --vnet-name $VNET_NAME \
  --name jump \
  --address-prefixes 10.0.16.0/24

APPS_SUBNET_ID=`az network vnet subnet show --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --n applications \
  --query id -o tsv`

CP_SUBNET_ID=`az network vnet subnet show --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --n control-plane \
  --query id -o tsv`

JUMP_SUBNET_ID=`az network vnet subnet show --vnet-name $VNET_NAME \
  --resource-group $RESOURCE_GROUP \
  --n jump \
  --query id -o tsv`

az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_WORKSPACE

LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`

LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE -o tsv | tr -d '[:space:]'`

VNET_RESOURCE_ID=`az network vnet show --resource-group ${RESOURCE_GROUP} --name ${VNET_NAME} --query "id" -o tsv | tr -d '[:space:]'`
CONTROL_PLANE_SUBNET=`az network vnet subnet show --resource-group ${RESOURCE_GROUP} --vnet-name $VNET_NAME --name control-plane --query "id" -o tsv | tr -d '[:space:]'`
APP_SUBNET=`az network vnet subnet show --resource-group ${RESOURCE_GROUP} --vnet-name ${VNET_NAME} --name applications --query "id" -o tsv | tr -d '[:space:]'`

az containerapp env create \
  --name $CONTAINERAPPS_ENVIRONMENT \
  --resource-group $RESOURCE_GROUP \
  --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
  --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
  --location "$LOCATION" \
  --app-subnet-resource-id $APP_SUBNET \
  --controlplane-subnet-resource-id $CONTROL_PLANE_SUBNET \
  --internal-only

ENVIRONMENT_DEFAULT_DOMAIN=`az containerapp env show --name ${CONTAINERAPPS_ENVIRONMENT} --resource-group ${RESOURCE_GROUP} --query defaultDomain --out json | tr -d '"'`
ENVIRONMENT_STATIC_IP=`az containerapp env show --name ${CONTAINERAPPS_ENVIRONMENT} --resource-group ${RESOURCE_GROUP} --query staticIp --out json | tr -d '"'`
VNET_ID=`az network vnet show --resource-group ${RESOURCE_GROUP} --name ${VNET_NAME} --query id --out json | tr -d '"'`

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

az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM \
  --image UbuntuLTS \
  --admin-username azureuser \
  --subnet $JUMP_SUBNET_ID \
  --public-ip-address-dns-name $VM \
  --public-ip-sku Standard \
  --generate-ssh-keys

