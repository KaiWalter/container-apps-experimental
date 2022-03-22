param namespaceName string
param location string = resourceGroup().location

resource sb 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Premium'
    capacity: 1
    tier: 'Premium'
  }
  properties: {}
}

resource queue1 'Microsoft.ServiceBus/namespaces/queues@2021-06-01-preview' = {
  name: 'queue1'
  parent: sb
  properties: {}
}

resource topic1 'Microsoft.ServiceBus/namespaces/topics@2021-06-01-preview' = {
  name: 'topic1'
  parent: sb
  properties: {}
}

output namespaceName string = sb.name
