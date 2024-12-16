param dnsServers array
param domainJoinUserName string
@secure()
param domainJoinUserPassword string
param domainName string
param imagePublisher string
param imageOffer string
param imageSku string
param location string = resourceGroup().location
param subnetResourceId string
param tagsByResourceType object
param vmAdminUserName string
@secure()
param vmAdminPassword string
param vmSize string

var networkInterfaceName = 'nic'
var vmName = 'managementVm-1'
var vmNicName = '${vmName}-${networkInterfaceName}'
var osDiskName = '${vmName}-osdisk'

resource vmNic 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: vmNicName
  location: location
  properties: {
    enableAcceleratedNetworking: false
    dnsSettings: {
      dnsServers: dnsServers
    }
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetResourceId
          }
        }
      }
    ]
  }
  tags: tagsByResourceType[?'Microsoft.Network/networkInterfaces'] ?? {}
}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    licenseType: 'Windows_Client'
    osProfile: {
      computerName: vmName
      adminUsername: vmAdminUserName
      adminPassword: vmAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: 'latest'
      }
      osDisk: {
        name: osDiskName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
  tags: tagsByResourceType[?'Microsoft.Compute/virtualMachines'] ?? {}
}

resource extension_JsonADDomainExtension 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  parent: vm
  name: 'JsonADDomainExtension'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      Name: domainName
      User: domainJoinUserName
      Restart: 'true'
      Options: '3'
    }
    protectedSettings: {
      Password: domainJoinUserPassword
    }
  }
}
