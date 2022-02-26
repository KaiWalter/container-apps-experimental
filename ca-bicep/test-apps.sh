#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw"

IP=$(az vm list-ip-addresses -g $RESOURCE_GROUP --query "[?contains(virtualMachine.name, 'hub')].virtualMachine.network.publicIpAddresses[0].ipAddress" -o tsv)

declare -a apps=("app1" "app2")

for app in "${apps[@]}"
do
    echo "$app"
    fqdn=$(az containerapp show -n $app -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors)
    ssh ca@$IP curl -s https://$fqdn/health
    echo " <<-- check $app own health"
    ssh ca@$IP curl -s https://$fqdn/health-remote
    echo " <<-- check $app remote health"
done
