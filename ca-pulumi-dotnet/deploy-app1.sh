#!/bin/bash

export RESOURCE_GROUP_NAME="ca-kw" # All the resources would be deployed in this resource group
export RESOURCE_GROUP_LOCATION="northeurope" # The resource group would be created in this location

#export CONTAINERAPPS_ENVIRONMENT=$(az containerapp env list -g $RESOURCE_GROUP_NAME --query [0].name -o tsv)
export CONTAINERAPPS_ENVIRONMENT=$(az resource list -g $RESOURCE_GROUP_NAME --resource-type Microsoft.App/managedEnvironments --query [0].name -o tsv)

STORAGE=$(az storage account list -g $RESOURCE_GROUP_NAME --query [0].name -o tsv)
STORAGEKEY=$(az storage account keys list -g $RESOURCE_GROUP_NAME -n $STORAGE --query [0].value -o tsv)

REGISTRY=$(az acr list -g $RESOURCE_GROUP_NAME --query [0].name -o tsv)
REGISTRYURL=$(az acr list -g $RESOURCE_GROUP_NAME --query [0].loginServer -o tsv)
REGISTRYPWD=$(az acr credential show -n $REGISTRY --query passwords[0].value -o tsv)
REGISTRYUSER=$(az acr credential show -n $REGISTRY --query username -o tsv)

IMAGENAME=app1
TAG=$(az acr repository show-tags -n $REGISTRY --repository $IMAGENAME --top 1 --orderby time_desc --query [0] -o tsv)

echo $IMAGENAME:$TAG

mkdir -p /tmp/components
rm /tmp/components/*

cat <<EOF > /tmp/components/state.yaml
-  name: statestore
   type: state.azure.blobstorage
   version: v1
   metadata:
   - name: accountName
     value: $STORAGE
   - name: accountKey
     value: $STORAGEKEY
   - name: containerName
     value: state
EOF

az containerapp create \
    --name $IMAGENAME \
    --resource-group $RESOURCE_GROUP_NAME \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --registry-login-server $REGISTRYURL \
    --registry-username $REGISTRYUSER \
    --registry-password $REGISTRYPWD \
    --image $REGISTRYURL/$IMAGENAME:$TAG \
    --enable-dapr --dapr-app-port 80 \
    --dapr-app-id $IMAGENAME \
    --dapr-components /tmp/components/state.yaml \
    --target-port 80 \
    --ingress 'external' \
    --query properties.configuration.ingress.fqdn
