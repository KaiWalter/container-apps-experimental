#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"
SUBSCRIPTION=`az account show --query id -o tsv`

declare -a apps=("app1" "app2")

for app in "${apps[@]}"
do
    echo "############# $app #############"
    fqdn=`az containerapp show -g $RESOURCE_GROUP -n $app --query properties.configuration.ingress.fqdn -o tsv --only-show-errors`
    curl -s https://$fqdn/health
    echo " <<-- check $app own health"
    curl -s https://$fqdn/health-remote
    echo " <<-- check $app remote health"
    echo ""

    curl -i -X POST -d '' https://$fqdn/state
    echo "<<-- put state $app"
    curl https://$fqdn/state
    echo " <<-- get state $app"
    echo ""

    if [ $app = 'app1' ]; then
        curl -i -X POST -d '{"message":"This is a published message from app1"}' -H 'Content-Type: application/json' https://$fqdn/pub
        echo "<<-- pub message from $app"
    else
        curl https://$fqdn/message
        echo " <<-- get pub message from $app /message"
    fi
    echo ""

done
