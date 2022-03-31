#!/bin/bash

set -e

RESOURCE_GROUP="ca-kw"
LOCATION="westeurope"
ENVIRONMENTNAME="ca-kw"
PRINCIPALID=`az ad user list --filter "mail eq '$(az account show --query user.name -o tsv)'" --query [].objectId -o tsv`

if [ $(az group exists --name $RESOURCE_GROUP) = false ]; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file main.bicep \
    -p environmentName=$ENVIRONMENTNAME \
    -p principalId=$PRINCIPALID
