param resourcePrefix string
var networkSecurityGroupNameJumpVm = '${resourcePrefix}-vm-nsg'

<<<<<<< HEAD
resource vnetSpoke 'Microsoft.Network/virtualNetworks@2021-05-01' = {
=======
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
>>>>>>> ba47358fefadd28e22b9185a4a6f16587813c998
  name: 'vnet-${resourceGroup().name}'
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
        }
      }
    ]
  }
}

<<<<<<< HEAD
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
        }
      }
    ]
  }
}

=======
>>>>>>> ba47358fefadd28e22b9185a4a6f16587813c998
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
