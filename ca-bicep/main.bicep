// based on https://github.com/denniszielke/blue-green-with-containerapps

param location string = resourceGroup().location
param environmentName string = 'env-${resourceGroup().name}'

// // container app environment
module environment 'environment.bicep' = {
  name: 'container-app-environment'
  params: {
    environmentName: environmentName
    location: location
  }
}
