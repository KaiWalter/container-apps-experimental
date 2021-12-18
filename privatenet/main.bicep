// based on https://github.com/denniszielke/blue-green-with-containerapps

param location string = resourceGroup().location
param environmentName string = 'env-${resourceGroup().name}'

var vnetName = 'vnet-${resourceGroup().name}'
var subnetBackendName = 'backend'

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetBackendName
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

// container app environment
module environment 'environment.bicep' = {
  name: 'container-app-environment'
  params: {
    environmentName: environmentName
    location: location
  }
}
