param pepIp string
param vnetHubId string
param domain string

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: domain
  location: 'Global'
}

resource privateDnsZoneEntry 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: '*'
  parent: privateDnsZone
  properties: {
    aRecords: [
      {
        ipv4Address: pepIp
      }
    ]
    ttl: 3600
  }
}

resource vnetLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${privateDnsZone.name}/${domain}-hub-link'
  location: 'Global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetHubId
    }
  }
}
