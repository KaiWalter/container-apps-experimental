export RESOURCE_GROUP_NAME="ca-with-cli" # All the resources would be deployed in this resource group

az group delete -n $RESOURCE_GROUP_NAME -y
