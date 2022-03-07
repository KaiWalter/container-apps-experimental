#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"
SUBSCRIPTION=`az account show --query id -o tsv`

IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP --query "[?contains(virtualMachine.name, 'hub')].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

declare -a apps=("app1" "app2")

for app in "${apps[@]}"
do
    echo "$app"
    fqdn=`az rest --method get -u /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/$app?api-version=2022-01-01-preview --query properties.configuration.ingress.fqdn -o tsv`
    # fqdn=$(az containerapp show -n $app -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors)
    ssh ca@$IP curl -s https://$fqdn/health
    echo " <<-- check $app own health"
    ssh ca@$IP curl -s https://$fqdn/health-remote
    echo " <<-- check $app remote health"
done
