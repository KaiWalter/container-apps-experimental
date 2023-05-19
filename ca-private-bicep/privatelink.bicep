param subnetSpokeId string
param subnetHubId string
param loadBalancerFipId string
param location string = resourceGroup().location
param resourceSuffix string

resource pl 'Microsoft.Network/privateLinkServices@2021-05-01' = {
  name: 'pl-container-app-env-${resourceSuffix}'
  location: location
  properties: {
    enableProxyProtocol: false
    loadBalancerFrontendIpConfigurations: [
      {
        id: loadBalancerFipId
      }
    ]
    ipConfigurations: [
      {
        name: 'jump-1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          primary: true
          subnet: {
            id: subnetSpokeId
          }
        }
      }
    ]
  }
}

resource pep 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pep-container-app-env-${resourceSuffix}'
  location: location
  properties: {
    subnet: {
      id: subnetHubId
    }
    privateLinkServiceConnections: [
      {
        name: 'pl-container-app-env'
        properties: {
          privateLinkServiceId: pl.id
        }
      }
    ]
  }
}

output pepNICName string = split(pep.properties.networkInterfaces[0].id, '/')[8]
