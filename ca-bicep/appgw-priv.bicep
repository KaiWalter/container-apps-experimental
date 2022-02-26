param appGwName string
param apiGatewayIpAddress string
param apiGatewayHostname string
param logWorkspaceId string
param logName string
param subnetGatewayHubId string
param subnetJumpHubId string
param subnetJumpSpokeId string
param location string = resourceGroup().location
param protocol string = 'Http'
param appGwMinCapacity int = 1
param appGwMaxCapacity int = 10

param serverCert string = ''
@secure()
param serverCertPassword string = ''

var frontendPortConfiguration = {
  http: {
    name: 'default'
    properties: {
      port: 8080
    }
  }
  https: {
    name: 'default'
    properties: {
      port: 443
    }
  }
}

var sslCertificates = {
  http: []
  https: [
    {
      name: 'default'
      properties: {
        data: serverCert
        password: serverCertPassword
      }
    }
  ]
}

var listenerCertConfiguration = {
  http: null
  https: {
    id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', appGwName, 'default')
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${appGwName}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: appGwName
    }
  }
}

resource appgw 'Microsoft.Network/applicationGateways@2021-05-01' = {
  name: appGwName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: appGwMinCapacity
      maxCapacity: appGwMaxCapacity
    }
    sslCertificates: sslCertificates[protocol]
    sslPolicy: {
      policyType: 'Custom'
      minProtocolVersion: 'TLSv1_2'
      cipherSuites: [
        'TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384'
        'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256'
        'TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'
        'TLS_DHE_RSA_WITH_AES_128_GCM_SHA256'
        'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384'
        'TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA'
        'TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA'
      ]
    }
    gatewayIPConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: subnetGatewayHubId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'default'
        properties: {
          publicIPAddress: {
            id: pip.id
          }
          privateIPAllocationMethod:'Dynamic'
          privateLinkConfiguration:{
            id: resourceId('Microsoft.Network/applicationGateways/privateLinkConfigurations', appGwName, 'private')
          }
        }
      }
    ]
    privateLinkConfigurations: [
      {
        name: 'private'
        properties: {
          ipConfigurations: [
            {
              name: 'private-ip'
              properties: {
                privateIPAllocationMethod:'Dynamic'
                subnet: {
                  id: subnetJumpHubId
                }
              }
            }
          ]
        }
      }
    ]
    frontendPorts: [
      frontendPortConfiguration[protocol]
    ]
    httpListeners: [
      {
        name: 'default'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGwName, 'default')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGwName, 'default')
          }
          sslCertificate: listenerCertConfiguration[protocol]
          protocol: protocol
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'api-gateway'
        properties: {
          backendAddresses: [
            {
              fqdn: apiGatewayIpAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'api-gateway'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: apiGatewayHostname
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGwName, 'api-gateway-probe')
          }
        }
      }
    ]
    probes: [
      {
        name: 'api-gateway-probe'
        properties: {
          protocol: 'Https'
          port: 443
          path: '/status-0123456789abcdef'
          interval: 15
          timeout: 15
          host: apiGatewayHostname
          unhealthyThreshold: 3
          match: {
            statusCodes: [
              '200'
            ]
          }
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'api-gateway-rule'
        properties: {
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGwName, 'api-gateway')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGwName, 'api-gateway')
          }
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGwName, 'default')
          }
          ruleType: 'Basic'
        }
      }
    ]
  }
}

resource diagAppGw 'microsoft.insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logName}-appgw'
  scope: appgw
  properties: {
    workspaceId: logWorkspaceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
        retentionPolicy: {
          days: 90
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 10
          enabled: true
        }
      }
    ]
  }
}

resource pep 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pep-priv-gateway'
  location: location
  properties: {
    subnet: {
      id: subnetJumpSpokeId
    }
    privateLinkServiceConnections: [
      {
        properties: {
          privateLinkServiceId: appgw.id
          groupIds: [
            'default'
          ]
        }
        name: 'pep-priv-gateway'
      }
    ]
  }
}
