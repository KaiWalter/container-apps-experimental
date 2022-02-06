param resourcePrefix string
var networkSecurityGroupNameJumpVm = '${resourcePrefix}-vm-nsg'

resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-spoke-${resourceGroup().name}'
  location: resourceGroup().location
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
        name: 'jump'
        properties: {
          addressPrefix: '10.0.16.0/24'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-hub-${resourceGroup().name}'
  location: resourceGroup().location
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
          addressPrefix: '10.27.1.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource nsgJumpVm 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: networkSecurityGroupNameJumpVm
  location: resourceGroup().location
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
output vnetHubId string = vnetHub.id
output nsgJumpVmId string = nsgJumpVm.id
