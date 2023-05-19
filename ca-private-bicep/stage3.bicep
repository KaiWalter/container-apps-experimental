param pepNICName string
param defaultDomain string
param vnetHubId string

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' existing = {
  name: pepNICName
}

module pdns 'privatedns.bicep' = {
  name: 'pdns'
  params: {
    pepIp: nic.properties.ipConfigurations[0].properties.privateIPAddress
    vnetHubId: vnetHubId
    domain: defaultDomain
  }
}
