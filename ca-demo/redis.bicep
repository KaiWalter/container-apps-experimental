param redisName string
param location string = resourceGroup().location

resource redisCache 'Microsoft.Cache/Redis@2019-07-01' = {
  name: redisName
  location: location
  properties: {
    enableNonSslPort: true
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
  }
}

output redisName string = redisCache.name
