param resourceSuffix string
param location string = resourceGroup().location

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-spoke-${resourceSuffix}'
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
        name: 'link'
        properties: {
          addressPrefix: '10.0.8.0/21'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'jump'
        properties: {
          addressPrefix: '10.0.16.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-hub-${resourceSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.27.1.0/24'
      ]
    }
    subnets: [
      {
        name: 'backends'
        properties: {
          addressPrefix: '10.27.1.0/26'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'apim'
        properties: {
          addressPrefix: '10.27.1.64/26'
        }
      }
      {
        name: 'appgw'
        properties: {
          addressPrefix: '10.27.1.128/26'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output vnetHubId string = vnetHub.id
output subnetSpokeLinkId string = resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetSpoke.name, 'link')
output subnetHubBackendsId string = resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetHub.name, 'backends')
output subnetComputeId string = resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetSpoke.name, 'cp')
