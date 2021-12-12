export RESOURCE_GROUP_NAME="ca-with-cli" # All the resources would be deployed in this resource group
export RESOURCE_GROUP_LOCATION="northeurope" # The resource group would be created in this location

export STORAGE_ACCOUNT=$(az storage account list -g $RESOURCE_GROUP_NAME --query [0].name -o tsv)
if [ $STORAGE_ACCOUNT ]
then
    echo "found $STORAGE_ACCOUNT"
else
    export STORAGE_ACCOUNT="ca$(echo $RANDOM | md5sum | head -c 20; echo)"

    az storage account create \
        --name $STORAGE_ACCOUNT \
        --resource-group $RESOURCE_GROUP_NAME \
        --location "$RESOURCE_GROUP_LOCATION" \
        --sku Standard_RAGRS \
        --kind StorageV2
fi

STORAGE_ACCOUNT_KEY=`az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT --query '[0].value' --out tsv`

cat > components.yaml <<EOL
- name: statestore
  type: state.azure.blobstorage
  version: v1
  metadata:
  # Note that in a production scenario, account keys and secrets 
  # should be securely stored. For more information, see
  # https://docs.dapr.io/operations/components/component-secrets
  - name: accountName
    value: $STORAGE_ACCOUNT
  - name: accountKey
    value: $STORAGE_ACCOUNT_KEY
  - name: containerName
    value: state
EOL

export CONTAINERAPPS_ENVIRONMENT=$(az containerapp env list -g $RESOURCE_GROUP_NAME --query [0].name -o tsv)

az containerapp create \
    --name nodeapp \
    --resource-group $RESOURCE_GROUP_NAME \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --image dapriosamples/hello-k8s-node:latest \
    --target-port 3000 \
    --ingress 'external' \
    --min-replicas 1 \
    --max-replicas 1 \
    --enable-dapr \
    --dapr-app-port 3000 \
    --dapr-app-id nodeapp \
    --dapr-components ./components.yaml

az containerapp create \
    --name pythonapp \
    --resource-group $RESOURCE_GROUP_NAME \
    --environment $CONTAINERAPPS_ENVIRONMENT \
    --image dapriosamples/hello-k8s-python:latest \
    --min-replicas 1 \
    --max-replicas 1 \
    --enable-dapr \
    --dapr-app-id pythonapp
