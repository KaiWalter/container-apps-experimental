#!/bin/bash

export ENVIRONMENTNAME=ca-kw
export LOCATION=northeurope
export RESOURCEGROUPNAME=$ENVIRONMENTNAME

if [ $(az group exists --name $RESOURCEGROUPNAME) = false ]; then
    az group create --name $RESOURCEGROUPNAME --location $LOCATION
fi

az deployment group create --resource-group $RESOURCEGROUPNAME \
    --template-file main.bicep \
    --parameters environmentName=$ENVIRONMENTNAME