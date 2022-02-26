param vnetSpokeId string
param apiName string
param pepIp string

var privateDNSZoneName = 'internal-api.net'

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDNSZoneName
  location: 'global'
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${privateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetSpokeId
    }
  }
}

resource privateDnsZoneEntry 'Microsoft.Network/privateDnsZones/A@2020-06-01' = {
  name: apiName
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

