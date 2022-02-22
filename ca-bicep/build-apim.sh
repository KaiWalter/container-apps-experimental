#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
APIMNAME="ca-kw"
APPINSIGHTNAME="appins-ca-kw"

fapp1Fqdn=`az containerapp show -n fapp1 -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors`
fapp2Fqdn=`az containerapp show -n fapp2 -g $RESOURCE_GROUP --query configuration.ingress.fqdn -o tsv --only-show-errors`
echo $fapp1Fqdn
echo $fapp2Fqdn

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file apim.bicep \
    --parameters apimName=$APIMNAME \
    appInsightsName=$APPINSIGHTNAME \
    fapp1Fqdn=$fapp1Fqdn \
    fapp2Fqdn=$fapp2Fqdn
