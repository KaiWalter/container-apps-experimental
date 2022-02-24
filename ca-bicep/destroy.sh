#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw"

if [ $(az group exists --name $RESOURCE_GROUP) = true ]; then

    az group delete --name $RESOURCE_GROUP -y

fi

az keyvault purge --name $(az keyvault list-deleted --query [0].name -o tsv)

SUBSCRIPTION=`az account show --query id -o tsv`
APIM=az rest -u /subscriptions/${SUBSCRIPTION}/providers/Microsoft.ApiManagement/deletedservices?api-version=2021-08-01
APIMNAME=`echo $APIM | jq .value[0].name -r`
APIMLOC=`echo $APIM | jq .value[0].location -r`
echo purging $APIMNAME in $APIMLOC
az rest --method delete -u /subscriptions/${SUBSCRIPTION}/providers/Microsoft.ApiManagement/locations/${APIMLOC}/deletedservices/${APIMNAME}?api-version=2021-08-01