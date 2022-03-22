param environmentName string
param location string = resourceGroup().location
param logAnalyticsCustomerId string
param logAnalyticsSharedKey string
param appInsightsInstrumentationKey string
// param storageAccountName string
// param storageContainerName string
// param storageAccountKey string
// param redisHost string
// param redisPassword string

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

// resource daprState 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
//   name: 'statestore'
//   parent: environment
//   properties: {
//     componentType: 'state.azure.blobstorage'
//     version: 'v1'
//     ignoreErrors: false
//     initTimeout: '60s'
//     secrets:[
//       {
//         name: 'storage-key'
//         value: storageAccountKey
//       }
//     ]
//     metadata: [
//       {
//         name: 'accountName'
//         value: storageAccountName
//       }
//       {
//         name: 'accountKey'
//         secretRef: 'storage-key'
//       }
//       {
//         name: 'containerName'
//         value: storageContainerName
//       }
//     ]
//     scopes:[
//       'app1'
//       'app2'
//     ]
//   }
// }

// resource daprPubSub 'Microsoft.App/managedEnvironments/daprComponents@2022-01-01-preview' = {
//   name: 'pubsub'
//   parent: environment
//   properties: {
//     componentType: 'pubsub.azure.servicebus'
//     version: 'v1'
//     metadata: [
//       {
//         name: 'connectionString'
//         secretRef: 'servicebus-connectionstring'
//       }
//     ]
//     scopes: [
//       'app1'
//       'app2'
//     ]
//   }
// }
