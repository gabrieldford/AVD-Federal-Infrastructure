param assetLocation string
param adminUsername string
@secure()
param adminPassword string
param adDomainName string
@secure()
param defaultUserPassword string
param entraIdPrimaryOrCustomDomainName string
param location string = resourceGroup().location
param subnetResourceId string
param tagsByResourceType object
param usersArray array = [
  {
    FName: 'Bob'
    LName: 'Jones'
    SAM: 'bjones'
  }
  {
    FName: 'Bill'
    LName: 'Smith'
    SAM: 'bsmith'
  }
  {
    FName: 'Mary'
    LName: 'Phillips'
    SAM: 'mphillips'
  }
  {
    FName: 'Sue'
    LName: 'Jackson'
    SAM: 'sjackson'
  }
  {
    FName: 'Jack'
    LName: 'Petersen'
    SAM: 'jpetersen'
  }
  {
    FName: 'Julia'
    LName: 'Williams'
    SAM: 'jwilliams'
  }
]
param vmSize string

var networkInterfaceName = 'nic'
var addcVMNameSuffix = '-dc1'
var companyNamePrefix = split(adDomainName, '.')[0]
var adVMName = toUpper('${companyNamePrefix}${addcVMNameSuffix}')
var adDSCConfigurationFunction = 'adDSCConfiguration.ps1\\DomainController'
var imageOffer = 'WindowsServer'
var imagePublisher = 'MicrosoftWindowsServer'
var imageSKU = '2022-datacenter-azure-edition'

var adNicName = '${adVMName}-${networkInterfaceName}'
var osDiskName = '${adVMName}-osdisk'

resource adNic 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: adNicName
  location: location
  properties: {
    enableAcceleratedNetworking: false
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

resource adVM 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: adVMName
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
    licenseType: 'Windows_Server'
    osProfile: {
      computerName: adVMName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSKU
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
          id: adNic.id
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

resource adVMName_Microsoft_Powershell_DSC 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  name: 'Microsoft.Powershell.DSC'
  parent: adVM
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.21'
    forceUpdateTag: '1.02'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: assetLocation
      configurationFunction: adDSCConfigurationFunction
      properties: [
        {
          Name: 'adDomainName'
          Value: adDomainName
          TypeName: 'System.Object'
        }
        {
          Name: 'customupnsuffix'
          Value: entraIdPrimaryOrCustomDomainName
          TypeName: 'System.Object'
        }
        {
          Name: 'AdminCreds'
          Value: {
            UserName: adminUsername
            Password: 'PrivateSettingsRef:AdminPassword'
          }
          TypeName: 'System.Management.Automation.PSCredential'
        }
        {
          Name: 'usersArray'
          Value: usersArray
          TypeName: 'System.Object'
        }
        {
          Name: 'UserCreds'
          Value: {
            UserName: 'user'
            Password: 'PrivateSettingsRef:UserPassword'
          }
          TypeName: 'System.Management.Automation.PSCredential'
        }
      ]
    }
    protectedSettings: {
      Items: {
        AdminPassword: adminPassword
        UserPassword: defaultUserPassword
      }
    }
  }
}
