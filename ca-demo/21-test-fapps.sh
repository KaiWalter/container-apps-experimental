#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"
SUBSCRIPTION=`az account show --query id -o tsv`

declare -a apps=("fapp1" "fapp2")

for app in "${apps[@]}"
do
    echo "############# $app #############"
    echo "$app"
    fqdn=`az containerapp show -g $RESOURCE_GROUP -n $app --query properties.configuration.ingress.fqdn -o tsv --only-show-errors`
    curl -s https://$fqdn/api/health
    echo " <<-- check API internal status"
    echo ""
done
