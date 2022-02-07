param environmentName string = 'env-${resourceGroup().name}'
param location string = resourceGroup().location
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
    vnetId: network.outputs.vnetSpokeId
    logAnalyticsCustomerId: logging.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: logging.outputs.logAnalyticsSharedKey
    appInsightsInstrumentationKey: logging.outputs.appInsightsInstrumentationKey
  }
}

module vm 'vm.bicep' = if (deployVm) {
  name: 'vm'
  params: {
    vnetId: network.outputs.vnetHubId
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
    vnetName: network.outputs.vnetSpokeName
  }
}

module stg 'storage.bicep' = {
  name: 'stg'
  params: {
    storageAccountName: replace('${environmentName}privatestorage', '-', '')
    vnetName: network.outputs.vnetSpokeName
  }
}

module kv 'keyvault.bicep' = {
  name: 'kv'
  params: {
    keyVaultName: 'kv-${environmentName}'
    vnetName: network.outputs.vnetSpokeName
  }
}

module sb 'servicebus.bicep' = {
  name: 'sb'
  params: {
    namespaceName: 'sb-${environmentName}'
    vnetName: network.outputs.vnetSpokeName
  }
}

module docdb 'docdb.bicep' = {
  name:'docdb'
  params: {
    accountName: 'db-${environmentName}'
    vnetName: network.outputs.vnetSpokeName
  }
}

output env object = az.environment().suffixes
