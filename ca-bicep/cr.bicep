param containerRegistryName string

resource cr 'Microsoft.ContainerRegistry/registries@2021-09-01' = {
  name: containerRegistryName
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}
