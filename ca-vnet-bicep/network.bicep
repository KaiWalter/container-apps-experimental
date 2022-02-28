param resourcePrefix string
param location string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-${resourceGroup().name}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/19'
      ]
    }
    subnets: [
      {
        name: 'cp'
        properties: {
          addressPrefix: '10.0.0.0/21'
        }
      }
      {
        name: 'apps'
        properties: {
          addressPrefix: '10.0.8.0/21'
        }
      }
      {
        name: 'appgw'
        properties: {
          addressPrefix: '10.0.16.0/24'
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
