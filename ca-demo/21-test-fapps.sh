#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="centraluseuap"
ENVIRONMENTNAME="ca-kw"
SUBSCRIPTION=`az account show --query id -o tsv`

declare -a apps=("fapp1" "fapp2")

for app in "${apps[@]}"
do
    echo "$app"
    fqdn=`az rest --method get -u /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/$app?api-version=2022-01-01-preview --query properties.configuration.ingress.fqdn -o tsv`
    curl -s https://$fqdn/api/health
    echo " <<-- check API internal status"
done
