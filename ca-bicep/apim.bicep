param apimName string
param appInsightsName string
param location string = resourceGroup().location
param fapp1Fqdn string = ''
param fapp2Fqdn string = ''

resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name: 'vnet-hub-${resourceGroup().name}'
}

resource apimSubnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' existing = {
  name: 'apim'
  parent: vnetHub
}

resource apim 'Microsoft.ApiManagement/service@2021-08-01' = {
  name: apimName
  location: location
  sku: {
    capacity: 1
    name: 'Developer'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: 'dummy@dummy.com'
    publisherName: 'kw'
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnet.id
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' existing = {
  name: appInsightsName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2019-12-01' = {
  name: 'logger'
  parent: apim
  properties: {
    resourceId: '${appInsights.id}'
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: '${appInsights.properties.InstrumentationKey}'
    }
  }
}

resource apimProduct 'Microsoft.ApiManagement/service/products@2019-12-01' = {
  name: 'test'
  parent: apim
  properties: {
    approvalRequired: true
    subscriptionRequired: true
    displayName: 'Test product'
    state: 'published'
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2019-12-01' = {
  name: 'test-subscription'
  parent: apim
  properties: {
    displayName: 'Test Subscription'
    primaryKey: 'test-primary-key-${uniqueString(resourceGroup().id)}'
    secondaryKey: 'test-secondary-key-${uniqueString(resourceGroup().id)}'
    state: 'active'
    scope: '/products/${apimProduct.id}'
  }
}

resource apimTestApi 'Microsoft.ApiManagement/service/apis@2021-08-01' = {
  name: 'test'
  parent: apim
  properties: {
    path: '/test'
    displayName: 'Test API'
    protocols: [
      'https'
    ]
  }
}

resource apimProductApi 'Microsoft.ApiManagement/service/products/apis@2021-08-01' = {
  name: apimTestApi.name
  parent: apimProduct
}

resource apimTestOp1 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  name: 'health-fapp1'
  parent: apimTestApi
  properties: {
    displayName: 'Health fapp1'
    method: 'GET'
    urlTemplate: 'fapp1'
  }
}

var policyOp1 = '''
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="fapp1" />
        <rewrite-uri template="/api/health" copy-unmatched-params="false" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'''

resource apimTestOp1Pol 'Microsoft.ApiManagement/service/apis/operations/policies@2021-08-01' = {
  name: 'policy'
  parent: apimTestOp1
  properties: {
    value: policyOp1
  }
}

resource apimTestOp2 'Microsoft.ApiManagement/service/apis/operations@2021-08-01' = {
  name: 'health-fapp2'
  parent: apimTestApi
  properties: {
    displayName: 'Health fapp2'
    method: 'GET'
    urlTemplate: 'fapp2'
  }
}

var policyOp2 = '''
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="fapp2" />
        <rewrite-uri template="/api/health" copy-unmatched-params="false" />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
'''

resource apimTestOp2Pol 'Microsoft.ApiManagement/service/apis/operations/policies@2021-08-01' = {
  name: 'policy'
  parent: apimTestOp2
  properties: {
    value: policyOp2
  }
}

resource backendFApp1 'Microsoft.ApiManagement/service/backends@2021-08-01' = if (fapp1Fqdn != '') {
  name: 'fapp1'
  parent: apim
  properties: {
    protocol: 'http'
    url: 'https://${fapp1Fqdn}'
  }
}

resource backendFApp2 'Microsoft.ApiManagement/service/backends@2021-08-01' = if (fapp2Fqdn != '') {
  name: 'fapp2'
  parent: apim
  properties: {
    protocol: 'http'
    url: 'https://${fapp2Fqdn}'
  }
}

