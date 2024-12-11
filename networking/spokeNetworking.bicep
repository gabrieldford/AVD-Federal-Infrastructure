param fwIPAddress string
param vnetName string
param nsgName string
param nsgSecurityRules array
param deploymentSuffix string
param location string
param hubVnetResourceId string
param vnetAddressPrefix string
param dnsServers array
param subnets array
param routeTableName string
param tagsByResourceType object

var snets = map(subnets, snet => {
  name: snet.name
  properties: {
    addressPrefix: snet.addressPrefix
    routeTable: {
      id: routeTable.id
    }
    networkSecurityGroup: contains(snet.name, 'privateEndpoints') ? null : {
      id: nsg.id
    }
  }
})

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  location: location
  name: nsgName
  properties: {
    securityRules: nsgSecurityRules
  }
  tags: tagsByResourceType[?'Microsoft.Network/networkSecurityGroups'] ?? {}
}

resource routeTable 'Microsoft.Network/routeTables@2023-04-01' = {
  location: location
  name: routeTableName
  properties: {
    routes: [
      {
        name: 'DefaultRoute'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fwIPAddress
        }
      }
    ]
  }
  tags: tagsByResourceType[?'Microsoft.Network/routeTables'] ?? {}
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-03-01' = {
  location: location
  name: vnetName
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    dhcpOptions: empty(dnsServers) ? null : {
      dnsServers: dnsServers
    }
    subnets: snets
  }
  tags: tagsByResourceType[?'Microsoft.Network/virtualNetworks'] ?? {}
}

module localVnetPeering 'virtual-network-peering.bicep' = {
  name: 'localVnetPeering-${deploymentSuffix}'
  params: {
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    localVnetName: vnetName
    remoteVirtualNetworkId: hubVnetResourceId
    useRemoteGateways: false
  }
  dependsOn: [
    vnet
  ] 
}

module remoteVnetPeering 'virtual-network-peering.bicep' = {
  name: 'remoteVnetPeering-${deploymentSuffix}'
  scope: resourceGroup(split(hubVnetResourceId, '/')[4])
  params: {
    allowForwardedTraffic: true
    allowVirtualNetworkAccess: true
    localVnetName: last(split(hubVnetResourceId, '/'))
    remoteVirtualNetworkId: vnet.id
    allowGatewayTransit: false
  }
}

output vnetResourceId string = vnet.id
output subnetResourceIds array = [for snet in snets: '${vnet.id}/subnets/${snet.name}']
