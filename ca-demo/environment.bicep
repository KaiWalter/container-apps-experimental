param environmentName string
param location string = resourceGroup().location
param logAnalyticsCustomerId string
param logAnalyticsSharedKey string
param appInsightsInstrumentationKey string
param redisName string
param namespaceName string

resource sb 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' existing = {
  name: namespaceName
}

var serviceBusEndpoint = '${sb.id}/AuthorizationRules/RootManageSharedAccessKey'
var serviceBusConnectionString = listKeys(serviceBusEndpoint, sb.apiVersion).primaryConnectionString

resource environment 'Microsoft.App/managedEnvironments@2022-01-01-preview' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    daprAIInstrumentationKey: appInsightsInstrumentationKey
  }
}

resource redisCache 'Microsoft.Cache/Redis@2019-07-01' existing = {
  name: redisName
}

resource daprRedisState 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
  name: 'state'
  parent: environment
  properties: {
    componentType: 'state.redis'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '60s'
    secrets: [
      {
        name: 'redis-key'
        value: redisCache.listKeys().primaryKey
      }
    ]
    metadata: [
      {
        name: 'redisHost'
        value: '${redisCache.properties.hostName}:6379'
      }
      {
        name: 'redisPassword'
        secretRef: 'redis-key'
      }
    ]
    scopes: [
      'app1'
      'app2'
    ]
  }
}

resource daprSBPubSub 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
  name: 'pubsub'
  parent: environment
  properties: {
    componentType: 'pubsub.azure.servicebus'
    version: 'v1'
    ignoreErrors: false
    initTimeout: '60s'
    secrets: [
      {
        name: 'servicebus-connection-string'
        value: serviceBusConnectionString
      }
    ]
    metadata: [
      {
        name: 'connectionString'
        secretRef: 'servicebus-connection-string'
      }
    ]
    scopes: [
      'app1'
      'app2'
    ]
  }
}
