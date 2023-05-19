param environmentName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param appInsightsName string
param subnetComputeId string

module environment 'environment.bicep' = {
  name: 'container-app-environment'
  params: {
    environmentName: environmentName
    location: location
    subnetComputeId: subnetComputeId
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    appInsightsName: appInsightsName
  }
}

output defaultDomain string = environment.outputs.defaultDomain
