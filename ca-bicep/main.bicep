param location string = resourceGroup().location
param environmentName string = 'env-${resourceGroup().name}'
param adminPasswordOrKey string
param deployVm bool = true

module network 'network.bicep' = {
  name: 'container-app-network'
  params: {
    resourcePrefix: environmentName
  }
}

module logging 'logging.bicep' = {
  name: 'container-app-logging'
  params: {
    logAnalyticsWorkspaceName: 'logs-${environmentName}'
    appInsightsName: 'appins-${environmentName}'
  }
}

module environment 'environment.bicep' = {
  name: 'container-app-environment'
  params: {
    environmentName: environmentName
    location: location
    vnetId: network.outputs.vnetId
    logAnalyticsCustomerId: logging.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: logging.outputs.logAnalyticsSharedKey
    appInsightsInstrumentationKey: logging.outputs.appInsightsInstrumentationKey
  }
}

module vm 'vm.bicep' = if (deployVm) {
  name: 'vm'
  params: {
    vnetId: network.outputs.vnetId
    subnetName: 'jump'
    nsgId: network.outputs.nsgJumpVmId
    vmCustomData: ''
    adminUsername: 'ca'
    adminPasswordOrKey: adminPasswordOrKey
    vmName: '${environmentName}-jump-vm'
  }
}

module cr 'cr.bicep' = {
  name: 'cr'
  params: {
    containerRegistryName: replace('${environmentName}cr', '-', '')
  }
}
