export RESOURCE_GROUP_NAME="ca-with-cli" # All the resources would be deployed in this resource group
export RESOURCE_GROUP_LOCATION="northeurope" # The resource group would be created in this location
export LOG_ANALYTICS_WORKSPACE_NAME="containerappslogs" # Workspace to export application logs
export CONTAINERAPPS_ENVIRONMENT_NAME="containerappsenvironment-$(( $RANDOM % 1000 ))" # Name of the ContainerApps Environment

az group create --name $RESOURCE_GROUP_NAME --location $RESOURCE_GROUP_LOCATION

az network vnet create \
  --name ca-vnet \
  --resource-group $RESOURCE_GROUP_NAME \
  --subnet-name default

export SUBNET_ID=`az network vnet subnet show --vnet-name ca-vnet \
  --resource-group $RESOURCE_GROUP_NAME \
  --n default \
  --query id -o tsv`


az monitor log-analytics workspace create -g $RESOURCE_GROUP_NAME -n $LOG_ANALYTICS_WORKSPACE_NAME
export LOG_ANALYTICS_WORKSPACE_CLIENT_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP_NAME -n $LOG_ANALYTICS_WORKSPACE_NAME --out json | tr -d '"'`
export LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP_NAME -n $LOG_ANALYTICS_WORKSPACE_NAME --out json | tr -d '"'`

az containerapp env create -n $CONTAINERAPPS_ENVIRONMENT_NAME \
    -g $RESOURCE_GROUP_NAME \
    --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_CLIENT_ID \
    --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_CLIENT_SECRET \
    --location $RESOURCE_GROUP_LOCATION \
    --subnet-resource-id $SUBNET_ID \
    --debug
