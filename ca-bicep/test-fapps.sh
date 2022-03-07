#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"
SUBSCRIPTION=`az account show --query id -o tsv`

IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP --query "[?contains(virtualMachine.name, 'hub')].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

declare -a apps=("fapp1" "fapp2")

for app in "${apps[@]}"
do
    echo "$app"
    fqdn=`az rest --method get -u /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/$app?api-version=2022-01-01-preview --query properties.configuration.ingress.fqdn -o tsv`
    # fqdn=$(az containerapp show -n $app -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors)
    ssh ca@$IP curl -s https://$fqdn/api/health
    echo " <<-- check APIM internal status"
    ssh ca@$IP curl -s https://$fqdn/api/apim-status
    echo " <<-- check $app APIM health"
    ssh ca@$IP curl -s https://$fqdn/api/apim-internal-status
    echo " <<-- check $app APIM internal status"
done
