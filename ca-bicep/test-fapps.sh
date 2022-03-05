#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"

IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP --query "[?contains(virtualMachine.name, 'hub')].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

declare -a apps=("fapp1" "fapp2")

for app in "${apps[@]}"
do
    echo "$app"
    fqdn=$(az containerapp show -n $app -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors)
    ssh ca@$IP curl -s https://$fqdn/api/health
    echo " <<-- check APIM internal status"
    ssh ca@$IP curl -s https://$fqdn/api/apim-status
    echo " <<-- check $app APIM health"
    ssh ca@$IP curl -s https://$fqdn/api/apim-internal-status
    echo " <<-- check $app APIM internal status"
done
