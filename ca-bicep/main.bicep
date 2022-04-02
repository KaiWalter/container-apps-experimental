param environmentName string = 'env-${resourceGroup().name}'
param location string = resourceGroup().location
param adminPasswordOrKey string

var deployVm = adminPasswordOrKey != ''

module network 'network.bicep' = {
  name: 'container-app-network'
  params: {
    resourcePrefix: environmentName
    location: location
  }
}

module logging 'logging.bicep' = {
  name: 'container-app-logging'
  params: {
    logAnalyticsWorkspaceName: 'logs-${environmentName}'
    appInsightsName: 'appins-${environmentName}'
    location: location
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

module vmHub 'vm.bicep' = if (deployVm) {
  name: 'vm-hub'
  params: {
    vnetId: network.outputs.vnetHubId
    subnetName: 'jump'
    nsgId: network.outputs.nsgJumpVmId
    vmCustomData: ''
    adminUsername: 'ca'
    adminPasswordOrKey: adminPasswordOrKey
    vmName: '${environmentName}-hub-jump-vm'
    location: location
  }
}

module vmSpoke 'vm.bicep' = if (deployVm) {
  name: 'vm-spoke'
  params: {
    vnetId: network.outputs.vnetSpokeId
    subnetName: 'jump'
    nsgId: network.outputs.nsgJumpVmId
    vmCustomData: ''
    adminUsername: 'ca'
    adminPasswordOrKey: adminPasswordOrKey
    vmName: '${environmentName}-spoke-jump-vm'
    location: location
  }
}

module cr 'cr.bicep' = {
  name: 'cr'
  params: {
    containerRegistryName: replace('${environmentName}cr', '-', '')
    vnetName: network.outputs.vnetSpokeName
    location: location
  }
}

module stg 'storage.bicep' = {
  name: 'stg'
  params: {
    storageAccountName: replace('${environmentName}privatestorage', '-', '')
    vnetName: network.outputs.vnetSpokeName
    location: location
  }
}

module kv 'keyvault.bicep' = {
  name: 'kv'
  params: {
    keyVaultName: 'kv-${environmentName}'
    vnetName: network.outputs.vnetSpokeName
    location: location
  }
}

module sb 'servicebus.bicep' = {
  name: 'sb'
  params: {
    namespaceName: 'sb-${environmentName}'
    vnetName: network.outputs.vnetSpokeName
    location: location
  }
}

module docdb 'docdb.bicep' = {
  name: 'docdb'
  params: {
    accountName: 'db-${environmentName}'
    vnetName: network.outputs.vnetSpokeName
    location: location
  }
}
