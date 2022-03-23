param loadTestingName string
param principalId string
param location string = resourceGroup().location

resource lt 'Microsoft.LoadTestService/loadTests@2021-12-01-preview' = {
  name: loadTestingName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    description: 'Load testing for Container Apps scaling'
  }
}

resource rd 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  name: '45bb0b16-2f0c-4e78-afaa-a07599b003f6' // load test owner
  scope: subscription()
}

resource ra 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(subscription().id)
  scope: resourceGroup()
  properties: {
    roleDefinitionId: rd.id
    principalType: 'User'
    principalId: principalId
  }
}
