param containerRegistryName string
param location string = resourceGroup().location
param vnetName string

resource cr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

module pep 'resourceprivatelink.bicep' = {
  name: 'pep-resource-registry'
  params: {
    resourceId: cr.id
    groupId: 'registry'
    dnsZone: 'privatelink.azurecr.io'
    vnetName: vnetName
    location: location
  }
}
