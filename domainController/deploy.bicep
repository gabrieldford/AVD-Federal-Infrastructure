@description('This is the location in which all the linked templates are stored.')
param assetLocation string

@description('Username to set for the local User. Cannot be "Administrator", "root" and possibly other such common account names. ')
param adminUsername string

@description('Password for the local administrator account. Cannot be "P@ssw0rd" and possibly other such common passwords. Must be 8 characters long and three of the following complexity requirements: uppercase, lowercase, number, special character')
@secure()
param adminPassword string

@description('IMPORTANT: Two-part internal AD name - short/NB name will be first part (\'contoso\'). The short name will be reused and should be unique when deploying this template in your selected region. If a name is reused, DNS name collisions may occur.')
param adDomainName string

param location string = resourceGroup().location

@description('JSON object array of users that will be loaded into AD once the domain is established.')
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

@description('This needs to be specified in order to have a uniform logon experience within AVD')
param entraIdPrimaryOrCustomDomainName string

@description('Enter the password that will be applied to each user account to be created in AD.')
@secure()
param defaultUserPassword string

@description('Select a VM SKU (please ensure the SKU is available in your selected region).')
param vmSize string

@description('The subnet Resource Id to which the Domain Controller will be attached.')
param subnetResourceId string

param tagsByResourceType object

var networkInterfaceName = 'nic'
var addcVMNameSuffix = 'dc'
var companyNamePrefix = split(adDomainName, '.')[0]
var adVMName = toUpper('${companyNamePrefix}${addcVMNameSuffix}')
var adDSCTemplate = '${assetLocation}DSC/adDSC.zip'
var adDSCConfigurationFunction = 'adDSCConfiguration.ps1\\DomainController'
var imageOffer = 'WindowsServer'
var imagePublisher = 'MicrosoftWindowsServer'
var imageSKU = '2019-Datacenter'

var adNicName = '${adVMName}-${networkInterfaceName}'

resource adNic 'Microsoft.Network/networkInterfaces@2019-12-01' = {
  name: adNicName
  location: location
  properties: {
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

resource adVM 'Microsoft.Compute/virtualMachines@2019-07-01' = {
  name: adVMName
  location: location

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
      modulesUrl: adDSCTemplate
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
