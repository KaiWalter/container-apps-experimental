// based on: https://www.thorsten-hans.com/how-to-deploy-azure-container-apps-with-bicep/

// general Azure Container App settings
param location string = resourceGroup().location
param name string
param environmentName string

// Container Image ref
param containerImage string

// Networking
param useExternalIngress bool = false
param containerPort int = 80

param registry string
param registryUsername string
@secure()
param registryPassword string

param envVars array = []

resource environment 'Microsoft.App/managedEnvironments@2022-01-01-preview' existing = {
  name: environmentName
}

resource containerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: name
  location: location
  identity:{
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      secrets: [
        {
          name: 'container-registry-password'
          value: registryPassword
        }
      ]
      registries: [
        {
          server: registry
          username: registryUsername
          passwordSecretRef: 'container-registry-password'
        }
      ]
      ingress: {
        external: useExternalIngress
        targetPort: containerPort
      }
      dapr: {
        enabled: true
        appId: name
        appPort: containerPort
        appProtocol: 'http'
      }
    }
    template: {
      containers: [
        {
          image: containerImage
          name: name
          env: envVars
        }
      ]
    }
  }
}
