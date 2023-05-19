param environmentName string
param location string = resourceGroup().location

module network 'network.bicep' = {
  name: 'network'
  params: {
    resourceSuffix: environmentName
    location: location
  }
}

module logging 'logging.bicep' = {
  name: 'logging'
  params: {
    appInsightsName: 'ai-${environmentName}'
    logAnalyticsWorkspaceName: 'la-${environmentName}'
    location: location
  }
}

module stage1 'stage1.bicep' = {
  name: 'stage1'
  params: {
    environmentName: environmentName
    location: location
    logAnalyticsWorkspaceName: logging.outputs.logAnalyticsWorkspaceName
    appInsightsName: logging.outputs.appInsightsName
    subnetComputeId: network.outputs.subnetComputeId
  }
}

module stage2 'stage2.bicep' = {
  name: 'stage2'
  params: {
    environmentName: environmentName
    location: location
    defaultDomainPrefix: split(stage1.outputs.defaultDomain, '.')[0]
    subnetSpokeId: network.outputs.subnetSpokeLinkId
    subnetHubId: network.outputs.subnetHubBackendsId
  }
}

module stage3 'stage3.bicep' = {
  name: 'stage3'
  params: {
    pepNICName: stage2.outputs.pepNICName
    defaultDomain: stage1.outputs.defaultDomain
    vnetHubId: network.outputs.vnetHubId
  }
}
