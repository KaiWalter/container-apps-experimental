param environmentName string = 'env-${resourceGroup().name}'
param location string = resourceGroup().location
param principalId string

var alternateLocation = location == 'centraluseuap' ? 'centralus' : location
var alternateLocationLoadTesting = location == 'centraluseuap' ? 'southcentralus' : location

module logging 'logging.bicep' = {
  name: 'container-app-logging'
  params: {
    logAnalyticsWorkspaceName: 'logs-${environmentName}'
    appInsightsName: 'appins-${environmentName}'
    location: alternateLocation
  }
}

module redis 'redis.bicep' = {
  name: 'container-app-redis'
  params: {
    redisName: 'rds-${environmentName}'
    location: location
  }
}

module sb 'servicebus.bicep' = {
  name: 'sb'
  params: {
    namespaceName: 'sb-${environmentName}'
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
    redisName: redis.outputs.redisName
    namespaceName: sb.outputs.namespaceName
  }
}

module stg 'storage.bicep' = {
  name: 'stg'
  params: {
    storageAccountName: replace(environmentName, '-', '')
    location: location
  }
}

module cr 'cr.bicep' = {
  name: 'cr'
  params: {
    containerRegistryName: replace('${environmentName}cr', '-', '')
    location: alternateLocation
  }
}

module lt 'loadtesting.bicep' = {
  name: 'lt'
  params: {
    loadTestingName: 'lt-${environmentName}'
    principalId: principalId
    location: alternateLocationLoadTesting
  }
}
