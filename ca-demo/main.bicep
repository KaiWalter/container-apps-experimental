param environmentName string = 'env-${resourceGroup().name}'
param location string = resourceGroup().location

module logging 'logging.bicep' = {
  name: 'container-app-logging'
  params: {
    logAnalyticsWorkspaceName: 'logs-${environmentName}'
    appInsightsName: 'appins-${environmentName}'
    location: location
  }
}

module redis 'redis.bicep' = {
  name: 'container-app-redis'
  params: {
    redisName: 'rds-${environmentName}'
    location: location
  }
}

module environment 'environment.bicep' = {
  name: 'container-app-environment'
  params: {
    environmentName: environmentName
    location: location
    logAnalyticsCustomerId: logging.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: logging.outputs.logAnalyticsSharedKey
    appInsightsInstrumentationKey: logging.outputs.appInsightsInstrumentationKey
    // redisHost: redis.outputs.redisHost
    // redisPassword: redis.outputs.redisPassword
    // storageAccountName: stg.outputs.name
    // storageContainerName: stg.outputs.containerName
    // storageAccountKey: stg.outputs.key
  }
}

module cr 'cr.bicep' = {
  name: 'cr'
  params: {
    containerRegistryName: replace('${environmentName}cr', '-', '')
    location: location
  }
}

// module sb 'servicebus.bicep' = {
//   name: 'sb'
//   params: {
//     namespaceName: 'sb-${environmentName}'
//     location: location
//   }
// }

// module stg 'storage.bicep' = {
//   name: 'stg'
//   params: {
//     storageAccountName: replace(environmentName, '-', '')
//     location: location
//   }
// }
