param environmentName string
param fipName string = 'kubernetes-internal'
param defaultDomainPrefix string
param location string = resourceGroup().location
param subnetSpokeId string
param subnetHubId string

resource ilb 'Microsoft.Network/loadBalancers@2021-05-01' existing = {
  name: fipName
  scope: resourceGroup('mc_${defaultDomainPrefix}-rg_${defaultDomainPrefix}_${location}')
}

module pl 'privatelink.bicep' = {
  name: 'privatelink'
  params: {
    loadBalancerFipId: ilb.properties.frontendIPConfigurations[0].id
    location: location
    subnetHubId: subnetHubId
    subnetSpokeId: subnetSpokeId
    resourceSuffix: environmentName
  }
}

output pepNICName string = pl.outputs.pepNICName
