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

@secure()
param serviceBusConnection string
@secure()
param storageConnection string

param envVars array = []

param scaleBy string = 'Http'

resource environment 'Microsoft.App/managedEnvironments@2022-01-01-preview' existing = {
  name: environmentName
}

// see https://www.youtube.com/watch?v=z_QnOKVpbkA
// https://gist.github.com/gbaeke/1e9ad7a62cb6a3347e081fad6dcca4d2
var scalingRules = {
  Queue: {
    minReplicas: 1
    maxReplicas: 10
    rules: [
      {
        name: 'queue-rule'
        custom: {
          type: 'azure-servicebus'
          metadata: {
            queueName: 'queue1'
            messageCount: '2'
          }
        }
        auth: [
          {
            secretRef: 'servicebusconnection'
            triggerParameter: 'connection'
          }
        ]
      }
    ]
  }
  Http: {
    minReplicas: 1
    maxReplicas: 10
    rules: [
      {
        name: 'http-rule'
        http: {
          metadata: {
            concurrentRequests: '5'
          }
        }
      }
    ]
  }
}

resource containerApp 'Microsoft.App/containerApps@2022-01-01-preview' = {
  name: name
  kind: 'containerapp'
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      secrets: [
        {
          name: 'container-registry-password'
          value: registryPassword
        }
        {
          name: 'servicebusconnection'
          value: serviceBusConnection
        }
        {
          name: 'storageconnection'
          value: storageConnection
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
    }
    template: {
      containers: [
        {
          image: containerImage
          name: name
          env: envVars
        }
      ]
      scale: scalingRules[scaleBy]
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
