#!/bin/bash

export ENVIRONMENTNAME=ca-kw
export LOCATION=northeurope
export RESOURCEGROUPNAME=$ENVIRONMENTNAME

if [ $(az group exists --name $RESOURCEGROUPNAME) = true ]; then
    az group delete --name $RESOURCEGROUPNAME -y
fi
