#!/bin/bash

RESOURCE_GROUP="ca-kw"

if [ $(az group exists --name $RESOURCE_GROUP) = true ]; then

    az group delete --name $RESOURCE_GROUP -y

fi
