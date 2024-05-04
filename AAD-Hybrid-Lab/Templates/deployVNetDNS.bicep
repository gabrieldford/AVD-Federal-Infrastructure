param virtualNetworkName string

param dnsIP string

param location string = resourceGroup().location

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-12-01' = {
  name: virtualNetworkName
  location: location
  tags: {
    displayName: 'virtualNetwork'
  }
  properties: {
    dhcpOptions: {
      dnsServers: [
        dnsIP
      ]
    }
  }
}
