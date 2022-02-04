param environmentName string
param location string = resourceGroup().location
param vnetId string
param logAnalyticsCustomerId string
param logAnalyticsSharedKey string
param appInsightsInstrumentationKey string

resource environment 'Microsoft.Web/kubeEnvironments@2021-03-01' = {
  name: environmentName
  location: location
  properties: {
    type: 'managed'
    internalLoadBalancerEnabled: true
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    containerAppsConfiguration: {
      daprAIInstrumentationKey: appInsightsInstrumentationKey
      controlPlaneSubnetResourceId: '${vnetId}/subnets/cp'
      appSubnetResourceId: '${vnetId}/subnets/apps'
      internalOnly: true
    }
  }
}

output location string = location
output environmentId string = environment.id
