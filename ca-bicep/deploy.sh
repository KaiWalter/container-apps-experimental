#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw"

if [ $(az group exists --name $RESOURCE_GROUP) = false ]; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

SSHPUBKEY=$(cat ~/.ssh/id_rsa.pub) # create with ssh-keygen first

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file main.bicep \
    --parameters "{\"environmentName\": {\"value\": \"$ENVIRONMENTNAME\"},\"adminPasswordOrKey\": {\"value\": \"$SSHPUBKEY\"}}"

ENVIRONMENT_DEFAULT_DOMAIN=`az containerapp env show --name ${ENVIRONMENTNAME} --resource-group ${RESOURCE_GROUP} --query defaultDomain -o tsv --only-show-errors`
ENVIRONMENT_STATIC_IP=`az containerapp env show --name ${ENVIRONMENTNAME} --resource-group ${RESOURCE_GROUP} --query staticIp -o tsv --only-show-errors`
ILB_FIP_ID=`az network lb list --query "[?frontendIpConfigurations[0].privateIpAddress=='${ENVIRONMENT_STATIC_IP}'].frontendIpConfigurations[0].id" -o tsv`

VNET_SPOKE_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query "[?contains(name,'spoke')].id" -o tsv`
VNET_SPOKE_NAME=`az network vnet show --ids ${VNET_SPOKE_ID} --query name --out tsv`
SUBNET_SPOKE_JUMP_ID=`az network vnet show --ids $VNET_SPOKE_ID --query "subnets[?name=='jump'].id" -o tsv`

VNET_HUB_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query "[?contains(name,'hub')].id" -o tsv`
SUBNET_HUB_JUMP_ID=`az network vnet show --ids $VNET_HUB_ID --query "subnets[?name=='jump'].id" -o tsv`

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file privatelink.bicep \
    --parameters "{\"subnetSpokeId\": {\"value\": \"$SUBNET_SPOKE_JUMP_ID\"},\"subnetHubId\": {\"value\": \"$SUBNET_HUB_JUMP_ID\"},\"loadBalancerFipId\": {\"value\": \"$ILB_FIP_ID\"}}"

PEP_NIC_ID=`az network private-endpoint list -g $RESOURCE_GROUP --query [0].networkInterfaces[0].id -o tsv`
PEP_IP=`az network nic show --ids $PEP_NIC_ID --query ipConfigurations[0].privateIpAddress -o tsv`

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file privatedns.bicep \
    --parameters "{\"pepIp\": {\"value\": \"$PEP_IP\"},\"vnetHubId\": {\"value\": \"$VNET_HUB_ID\"},\"domain\": {\"value\": \"$ENVIRONMENT_DEFAULT_DOMAIN\"}}"
