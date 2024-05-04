@description('Admin password')
@secure()
param adminPassword string

@description('Admin username')
param adminUsername string

@description('When deploying the stack N times, define the instance - this will be appended to some resource names to avoid collisions.')
param deploymentNumber string = '1'

@description('The resource Id of the subnet to deploy the domain controllers into')
param subnetResourceId string

param adVMName string = 'AZAD'

@metadata({ Description: 'The region to deploy the resources into' })
param location string

@description('This is the prefix name of the Network interfaces')
param NetworkInterfaceName string = 'NIC'

@description('This is the allowed list of VM sizes')
param vmSize string = 'Standard_D2s_v4'

var imageOffer = 'WindowsServer'
var imagePublisher = 'MicrosoftWindowsServer'
var imageSKU = '2019-Datacenter'

var adNicName = 'ad-${NetworkInterfaceName}${deploymentNumber}'

resource adNic 'Microsoft.Network/networkInterfaces@2019-12-01' = {
  name: adNicName
  location: location
  tags: {
    displayName: 'adNIC'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig${deploymentNumber}'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetResourceId
          }
        }
      }
    ]
  }
}

resource adVM 'Microsoft.Compute/virtualMachines@2019-07-01' = {
  name: adVMName
  location: location
  tags: {
    displayName: 'adVM'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: adVMName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
        version: 'latest'
      }
      osDisk: {
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: adNic.id
        }
      ]
    }
  }
}

output vmIPAddress string = adNic.properties.ipConfigurations[0].properties.privateIPAddress
