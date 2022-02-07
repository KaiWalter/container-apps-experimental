param keyVaultName string
param location string = resourceGroup().location
param vnetName string

resource kv 'Microsoft.KeyVault/vaults@2021-06-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
    accessPolicies:[
    ]
  }
}

module pep 'resourceprivatelink.bicep' = {
  name: 'pep-resource-vault'
  params: {
    resourceId: kv.id
    groupId: 'vault'
    dnsZone: 'privatelink.vaultcore.azure.net'
    vnetName: vnetName
  }
}
