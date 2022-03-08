#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
SUBSCRIPTION=`az account show --query id -o tsv`
APIMNAME="ca-kw"
APPINSIGHTNAME="appins-ca-kw"
LOGANALYTICSNAME="logs-ca-kw"

# fapp1Fqdn=`az containerapp show -n fapp1 -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors`
# fapp2Fqdn=`az containerapp show -n fapp2 -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors`
fapp1Fqdn=`az rest --method get -u /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/fapp1?api-version=2022-01-01-preview --query properties.configuration.ingress.fqdn -o tsv`
fapp2Fqdn=`az rest --method get -u /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/fapp2?api-version=2022-01-01-preview --query properties.configuration.ingress.fqdn -o tsv`

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file apim.bicep \
    --parameters apimName=$APIMNAME \
    appInsightsName=$APPINSIGHTNAME \
    logAnalyticsWorkspaceName=$LOGANALYTICSNAME \
    fapp1Fqdn=$fapp1Fqdn \
    fapp2Fqdn=$fapp2Fqdn

VNET_SPOKE_ID=`az network vnet list --resource-group ${RESOURCE_GROUP} --query "[?contains(name,'spoke')].id" -o tsv`
PEP_NIC_ID=`az network private-endpoint list -g $RESOURCE_GROUP --query "[?name=='pep-priv-gateway'].networkInterfaces[0].id" -o tsv`
PEP_IP=`az network nic show --ids $PEP_NIC_ID --query ipConfigurations[0].privateIpAddress -o tsv`

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file appgw-priv-dns.bicep \
    --parameters "{\"pepIp\": {\"value\": \"$PEP_IP\"},\"vnetSpokeId\": {\"value\": \"$VNET_SPOKE_ID\"},\"apiName\": {\"value\": \"$APIMNAME\"}}"