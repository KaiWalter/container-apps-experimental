param resourceSuffix string
param location string = resourceGroup().location

param spokeBaseAdress string = '10.0.0.0/19'
param hubBaseAddress string = '10.42.10.0/24'

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-spoke-${resourceSuffix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        spokeBaseAdress
      ]
    }
    subnets: [
      {
        name: 'cp'
        properties: {
          addressPrefix: cidrSubnet(spokeBaseAdress,21,0)
        }
      }
      {
        name: 'link'
        properties: {
          addressPrefix: cidrSubnet(cidrSubnet(spokeBaseAdress,21,1),26,0) // 1st /26 range in 2nd /21 range block
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'jump'
        properties: {
          addressPrefix: cidrSubnet(cidrSubnet(spokeBaseAdress,21,1),26,1) // 2nd /26 range in 2nd /21 range block
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
        hubBaseAddress
      ]
    }
    subnets: [
      {
        name: 'backends'
        properties: {
          addressPrefix: cidrSubnet(hubBaseAddress,26,0)
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'jump'
        properties: {
          addressPrefix: cidrSubnet(hubBaseAddress,26,1)
        }
      }
      {
        name: 'apim'
        properties: {
          addressPrefix: cidrSubnet(hubBaseAddress,26,2)
        }
      }
      {
        name: 'appgw'
        properties: {
          addressPrefix: cidrSubnet(hubBaseAddress,26,3)
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
