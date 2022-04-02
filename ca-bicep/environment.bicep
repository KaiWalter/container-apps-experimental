param environmentName string
param location string = resourceGroup().location
param vnetId string
param logAnalyticsCustomerId string
param logAnalyticsSharedKey string
param appInsightsInstrumentationKey string

// https://github.com/Azure/azure-rest-api-specs/blob/Microsoft.App-2022-01-01-preview/specification/app/resource-manager/Microsoft.App/preview/2022-01-01-preview/ManagedEnvironments.json

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
    vnetConfiguration: {
      infrastructureSubnetId: '${vnetId}/subnets/cp'
      runtimeSubnetId: '${vnetId}/subnets/apps'
      internal: true
    }
  }
}
