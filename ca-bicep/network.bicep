param resourcePrefix string
param location string = resourceGroup().location
var networkSecurityGroupNameJumpVm = '${resourcePrefix}-vm-nsg'

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-spoke-${resourceGroup().name}'
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
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'jump'
        properties: {
          addressPrefix: '10.0.16.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-hub-${resourceGroup().name}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.27.1.0/24'
      ]
    }
    subnets: [
      {
        name: 'jump'
        properties: {
          addressPrefix: '10.27.1.0/26'
          privateEndpointNetworkPolicies: 'Disabled'
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

resource nsgJumpVm 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: networkSecurityGroupNameJumpVm
  location: location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

output vnetSpokeId string = vnetSpoke.id
output vnetSpokeName string = vnetSpoke.name
output vnetHubId string = vnetHub.id
output vnetHubName string = vnetHub.name
output nsgJumpVmId string = nsgJumpVm.id
