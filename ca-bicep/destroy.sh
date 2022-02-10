#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw"

if [ $(az group exists --name $RESOURCE_GROUP) = true ]; then

    az group delete --name $RESOURCE_GROUP -y

fi

az keyvault purge --name $(az keyvault list-deleted --query [0].name -o tsv)
