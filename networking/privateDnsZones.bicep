param privateDnsZoneNames array
param vnetId string
param tags object

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2020-06-01' = [for (name, i) in privateDnsZoneNames: {
  name: name
  location: 'global'
  tags: tags[?'Microsoft.Network/privateDnsZones'] ?? {}
}]

resource virtualNetworkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = [for (name, i) in privateDnsZoneNames : {
  name: last(split(vnetId, '/'))
  parent: privateDnsZones[i]
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}]
