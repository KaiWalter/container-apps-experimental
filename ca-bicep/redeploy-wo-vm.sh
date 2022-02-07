#!/bin/bash

RESOURCE_GROUP="ca-kw"
LOCATION="northeurope"
ENVIRONMENTNAME="ca-kw"

SSHPUBKEY=$(cat ~/.ssh/id_rsa.pub) # create with ssh-keygen first

az deployment group create --resource-group $RESOURCE_GROUP \
    --template-file main.bicep \
    --parameters "{\"environmentName\": {\"value\": \"$ENVIRONMENTNAME\"},\"adminPasswordOrKey\": {\"value\": \"$SSHPUBKEY\"},\"deployVm\": {\"value\": false}}"

