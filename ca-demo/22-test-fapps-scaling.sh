#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="centraluseuap"
ENVIRONMENTNAME="ca-kw"
SUBSCRIPTION=`az account show --query id -o tsv`

fqdn=`az rest --method get -u /subscriptions/$SUBSCRIPTION/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/fapp1?api-version=2022-01-01-preview --query properties.configuration.ingress.fqdn -o tsv`
for i in {{1..500}}; do echo $i; curl -X POST -d 'TEST' https://$fqdn/api/httpingress; done
