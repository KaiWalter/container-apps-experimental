param namespaceName string
param location string = resourceGroup().location
param vnetName string

resource sb 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Premium'
    capacity: 1
    tier: 'Premium'
  }
  properties: {}
}

module pep 'resourceprivatelink.bicep' = {
  name: 'pep-resource-namespace'
  params: {
    resourceId: sb.id
    groupId: 'namespace'
    dnsZone: 'privatelink.servicebus.windows.net'
    vnetName: vnetName
  }
}
