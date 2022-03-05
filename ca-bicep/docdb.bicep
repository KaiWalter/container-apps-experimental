param accountName string
param location string = resourceGroup().location
param vnetName string
param defaultConsistencyLevel string = 'Session'
param maxStalenessPrefix int = 100000
param maxIntervalInSeconds int = 300

// https://docs.microsoft.com/en-us/azure/cosmos-db/sql/manage-with-bicep

var consistencyPolicy = {
  Eventual: {
    defaultConsistencyLevel: 'Eventual'
  }
  ConsistentPrefix: {
    defaultConsistencyLevel: 'ConsistentPrefix'
  }
  Session: {
    defaultConsistencyLevel: 'Session'
  }
  BoundedStaleness: {
    defaultConsistencyLevel: 'BoundedStaleness'
    maxStalenessPrefix: maxStalenessPrefix
    maxIntervalInSeconds: maxIntervalInSeconds
  }
  Strong: {
    defaultConsistencyLevel: 'Strong'
  }
}

var locations = [
  {
    locationName: location
    failoverPriority: 0
    isZoneRedundant: false
  }
]

resource docdb 'Microsoft.DocumentDB/databaseAccounts@2021-10-15' = {
  name: accountName
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    locations: locations
    consistencyPolicy: consistencyPolicy[defaultConsistencyLevel]
    databaseAccountOfferType: 'Standard'
    publicNetworkAccess: 'Disabled'
  }
}

module pep 'resourceprivatelink.bicep' = {
  name: 'pep-resource-Sql'
  params: {
    resourceId: docdb.id
    groupId: 'Sql'
    dnsZone: 'privatelink.documents.azure.com'
    vnetName: vnetName
    location: location
  }
}
