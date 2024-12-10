param name string = '${localVnetName}-${last(split(remoteVirtualNetworkId, '/'))}'
param localVnetName string
param remoteVirtualNetworkId string
param allowForwardedTraffic bool = true
param allowGatewayTransit bool = false
param allowVirtualNetworkAccess bool = true
param doNotVerifyRemoteGateways bool = true
param useRemoteGateways bool = false

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: localVnetName
}

resource virtualNetworkPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-04-01' = {
  name: name
  parent: virtualNetwork
  properties: {
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    allowVirtualNetworkAccess: allowVirtualNetworkAccess
    doNotVerifyRemoteGateways: doNotVerifyRemoteGateways
    useRemoteGateways: useRemoteGateways
    remoteVirtualNetwork: {
      id: remoteVirtualNetworkId
    }
  }
}
