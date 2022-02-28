#!/bin/bash

RESOURCE_GROUP="ca-kw-2"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw-2"

if [ $(az group exists --name $RESOURCE_GROUP) = false ]; then
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file main.bicep \
    --parameters environmentName=$ENVIRONMENTNAME

