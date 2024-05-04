@description('This is the location in which all the linked templates are stored.')
param assetLocation string = 'https://raw.githubusercontent.com/shawntmeyer/AVDFedRockstarTraining/master/AAD-Hybrid-Lab/'

@description('Username to set for the local User. Cannot be "Administrator", "root" and possibly other such common account names. ')
param adminUsername string = 'ADAdmin'

@description('When deploying the stack N times simultaneously, define the instance - this will be appended to some resource names to avoid collisions.')
@allowed([
  '0'
  '1'
  '2'
  '3'
  '4'
  '5'
  '6'
  '7'
  '8'
  '9'
])
param deploymentNumber string = '1'

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
@allowed([
  'Standard_DS2_v2'
  'Standard_D2_v3'
  'Standard_D2_v4'
  'Standard_D2s_v3'
  'Standard_D2s_v4'
  'Standard_D4_v4'
  'Standard_D4s_v4'
])
param vmSize string = 'Standard_D2s_v4'

@description('The subnet Resource Id to which the Domain Controller will be attached.')
param adSubnetResourceId string

var networkInterfaceName = 'NIC'
var addcVMNameSuffix = 'dc'
var companyNamePrefix = split(adDomainName, '.')[0]
var adVMName = toUpper('${companyNamePrefix}${addcVMNameSuffix}')
var adDSCTemplate = '${assetLocation}DSC/adDSC.zip'
var adDSCConfigurationFunction = 'adDSCConfiguration.ps1\\DomainController'

var virtualNetworkName = split(adSubnetResourceId, '/')[8]

module adVM 'Templates/adDeploy.bicep' = {
  name: 'adVMs'
  params: {
    adminPassword: adminPassword
    adminUsername: adminUsername
    subnetResourceId: adSubnetResourceId
    adVMName: adVMName
    location: location
    NetworkInterfaceName: networkInterfaceName
    vmSize: vmSize
    deploymentNumber: deploymentNumber
  }
}

resource adVMName_Microsoft_Powershell_DSC 'Microsoft.Compute/virtualMachines/extensions@2019-07-01' = {
  name: '${adVMName}/Microsoft.Powershell.DSC'
  location: location
  tags: {
    displayName: 'adDSC'
  }
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
  dependsOn: [
    adVM
  ]
}

module virtualNetworkDNSUpdate 'Templates/deployVNetDNS.bicep' = {
  name: 'virtualNetworkDNSUpdate'
  params: {
    location: location
    virtualNetworkName: virtualNetworkName
    dnsIP: adVM.outputs.vmIPAddress
  }
  dependsOn: [
    adVMName_Microsoft_Powershell_DSC
  ]
}
