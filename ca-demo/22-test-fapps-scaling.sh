#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"
SUBSCRIPTION=`az account show --query id -o tsv`
app="fapp1"

fqdn=`az containerapp show -g $RESOURCE_GROUP -n $app --query properties.configuration.ingress.fqdn -o tsv --only-show-errors`
echo "address for load testing resource (parameter ingress_url): $fqdn"
read -p "start local test loop"
for i in {{1..500}}; do echo $i; curl -X POST -d 'TEST' https://$fqdn/api/httpingress; done
