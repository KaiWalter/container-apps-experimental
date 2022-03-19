param storageAccountName string
param location string = resourceGroup().location

resource stg 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }
}
