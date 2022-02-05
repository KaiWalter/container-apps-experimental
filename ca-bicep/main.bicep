param location string = resourceGroup().location
param environmentName string = 'env-${resourceGroup().name}'
param adminPasswordOrKey string
<<<<<<< HEAD
param deployVm bool = true
=======
>>>>>>> ba47358fefadd28e22b9185a4a6f16587813c998

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
    vnetId: network.outputs.vnetSpokeId
    logAnalyticsCustomerId: logging.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: logging.outputs.logAnalyticsSharedKey
    appInsightsInstrumentationKey: logging.outputs.appInsightsInstrumentationKey
  }
}

<<<<<<< HEAD
module vm 'vm.bicep' = if (deployVm) {
  name: 'vm'
  params: {
    vnetId: network.outputs.vnetHubId
=======
module vm 'vm.bicep' = {
  name: 'vm'
  params: {
    vnetId: network.outputs.vnetId
>>>>>>> ba47358fefadd28e22b9185a4a6f16587813c998
    subnetName: 'jump'
    nsgId: network.outputs.nsgJumpVmId
    vmCustomData: ''
    adminUsername: 'ca'
    adminPasswordOrKey: adminPasswordOrKey
    vmName: '${environmentName}-jump-vm'
<<<<<<< HEAD
  }
}

module cr 'cr.bicep' = {
  name: 'cr'
  params: {
    containerRegistryName: replace('${environmentName}cr', '-', '')
=======
>>>>>>> ba47358fefadd28e22b9185a4a6f16587813c998
  }
}
