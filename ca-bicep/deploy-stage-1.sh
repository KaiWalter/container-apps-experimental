#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"

if [ $(az group exists --name $RESOURCE_GROUP) = false ]; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

if [ "$1" == "" ]; then
    SSHPUBKEY=$(cat ~/.ssh/id_rsa.pub) # create with ssh-keygen first
else
    SSHPUBKEY=
fi

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file main.bicep \
    --parameters environmentName=$ENVIRONMENTNAME \
    adminPasswordOrKey="$SSHPUBKEY" \
    --query properties.outputs

ENVIRONMENT_STATIC_IP=`az containerapp env show -n $ENVIRONMENTNAME -g $RESOURCE_GROUP --only-show-errors --query properties.staticIp -o tsv`
ENVIRONMENT_DEFAULT_DOMAIN=`az containerapp env show -n $ENVIRONMENTNAME -g $RESOURCE_GROUP --only-show-errors --query properties.defaultDomain -o tsv`
ENVIRONMENT_CODE=`echo $ENVIRONMENT_DEFAULT_DOMAIN | grep -oP "^[a-z0-9\-]{1,25}"`

echo $ENVIRONMENT_STATIC_IP $ENVIRONMENT_DEFAULT_DOMAIN $ENVIRONMENT_CODE

CLUSTER_RG=`az group list --query "[?contains(name, '$ENVIRONMENT_CODE')].name" -o tsv`
ILB_FIP_ID=`az network lb show -g $CLUSTER_RG -n kubernetes-internal --query "frontendIpConfigurations[0].id" -o tsv`

echo $CLUSTER_RG $ILB_FIP_ID

VNET_SPOKE_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query "[?contains(name,'spoke')].id" -o tsv`
SUBNET_SPOKE_JUMP_ID=`az network vnet show --ids $VNET_SPOKE_ID --query "subnets[?name=='jump'].id" -o tsv`

echo $VNET_SPOKE_ID $SUBNET_SPOKE_JUMP_ID

VNET_HUB_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query "[?contains(name,'hub')].id" -o tsv`
SUBNET_HUB_JUMP_ID=`az network vnet show --ids $VNET_HUB_ID --query "subnets[?name=='jump'].id" -o tsv`

echo $VNET_HUB_ID $SUBNET_HUB_JUMP_ID

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file privatelink.bicep \
    --parameters "{\"subnetSpokeId\": {\"value\": \"$SUBNET_SPOKE_JUMP_ID\"},\"subnetHubId\": {\"value\": \"$SUBNET_HUB_JUMP_ID\"},\"loadBalancerFipId\": {\"value\": \"$ILB_FIP_ID\"}}"

PEP_NIC_ID=`az network private-endpoint list -g $RESOURCE_GROUP --query "[?name=='pep-container-app-env'].networkInterfaces[0].id" -o tsv`
PEP_IP=`az network nic show --ids $PEP_NIC_ID --query ipConfigurations[0].privateIpAddress -o tsv`

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file privatedns.bicep \
    --parameters "{\"pepIp\": {\"value\": \"$PEP_IP\"},\"vnetHubId\": {\"value\": \"$VNET_HUB_ID\"},\"domain\": {\"value\": \"$ENVIRONMENT_DEFAULT_DOMAIN\"}}"
