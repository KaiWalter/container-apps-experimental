#!/bin/bash

set -e

RESOURCE_GROUP="kw-ca"
LOCATION="northeurope"

az deployment sub create -n $RESOURCE_GROUP -f main.bicep -p name=$RESOURCE_GROUP -l $LOCATION
