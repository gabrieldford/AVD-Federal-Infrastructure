targetScope = 'subscription'

param location string = deployment().location

@description('This is the location in which all the linked templates are stored.')
param assetLocation string = 'https://raw.githubusercontent.com/shawntmeyer/AVDFedRockstarTraining/refs/heads/main/compute/DSC/adDSC.zip'

@description('Username to set for the local User. Cannot be "Administrator", "root" and possibly other such common account names. ')
param adAdminUsername string = 'ADAdmin'

@description('Password for the local administrator account. Cannot be "P@ssw0rd" and possibly other such common passwords. Must be 8 characters long and three of the following complexity requirements: uppercase, lowercase, number, special character')
@secure()
param adAdminPassword string

@description('IMPORTANT: Two-part internal AD name - short/NB name will be first part (\'contoso\'). The short name will be reused and should be unique when deploying this template in your selected region. If a name is reused, DNS name collisions may occur.')
param adDomainName string

@description('An array of availability zones to use for firewall deployment. If not provided, firewall will be deployed in a single zone.')
param availabilityZones array = []

@description('This needs to be specified in order to have a uniform logon experience within AVD')
param entraIdPrimaryOrCustomDomainName string

@description('Enter the password that will be applied to each user account to be created in AD.')
@secure()
param defaultUserPassword string

@description('The tags to apply to each resource by resource type.')
param tagsByResourceType object = {}

@description('Select a VM SKU (please ensure the SKU is available in your selected region).')
param vmSize string = 'Standard_B2ms'

var addsVnetAddressPrefix = '10.0.1.0/24'

var addsServersSnetAddressPrefix = '10.0.1.0/25'

var addsMgmtSnetAddressPrefix = '10.0.1.128/25'

var addsServerAddresses = [
    '10.0.1.4'
]

var addsNsgRules = [
  {
    name: 'DNS-TCP'
    properties: {
      priority: 100
      access: 'Allow'
      description: 'DNS-TCP'
      destinationAddressPrefix: addsServersSnetAddressPrefix
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationPortRange: '53'
      protocol: 'Tcp'
      sourceAddressPrefixes: [
        firewallSnetAddressPrefix
        addsVnetAddressPrefix
      ]
    }
  }
  {
    name: 'DNS-UDP'
    properties: {
      priority: 110
      access: 'Allow'
      description: 'DNS-UDP'
      destinationAddressPrefix: addsServersSnetAddressPrefix
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationPortRange: '53'
      protocol: 'Udp'
      sourceAddressPrefixes: [
        firewallSnetAddressPrefix
        addsVnetAddressPrefix
      ]
    }
  }
  {
    name: 'DomainServices-TCP'
    properties: {
      priority: 120
      access: 'Allow'
      description: 'Domain Services (TCP)'
      destinationAddressPrefix: addsServersSnetAddressPrefix
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationPortRanges: [
        '88'
        '123'
        '135'
        '389'
        '445'
        '636'
        '3268'
        '3269'
        '49152-65535'
      ]
      protocol: 'Tcp'
      sourceAddressPrefixes: [
        addsVnetAddressPrefix
        avdVnetAddressPrefix
      ]
    }
  }
  {
    name: 'DomainServices-UDP'
    properties: {
      priority: 130
      access: 'Allow'
      description: 'Domain Services (UDP)'
      destinationAddressPrefix: addsServersSnetAddressPrefix
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationPortRanges: [
        '88'
        '389'
      ]
      protocol: 'Udp'
      sourceAddressPrefixes: [
        addsVnetAddressPrefix
        avdVnetAddressPrefix
      ]
    }
  }
  {
    name: 'RDP'
    properties: {
      priority: 140
      access: 'Allow'
      description: 'RDP'
      destinationAddressPrefix: addsVnetAddressPrefix
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      protocol: 'Tcp'
      sourceAddressPrefixes: [
        addsVnetAddressPrefix
        bastionSnetAddressPrefix
      ]
    }
  }
  {
    name: 'DenyAllCustomInbound'
    properties: {
      priority: 4000
      access: 'Deny'
      description: 'Deny all inbound traffic not explicitly allowed'
      destinationAddressPrefix: addsVnetAddressPrefix
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationPortRange: '*'
      protocol: '*'
      sourceAddressPrefix: '*'
    }
  }  
]

var addsSubnets = [
  {
    name: 'snet-adds'
    addressPrefix: addsServersSnetAddressPrefix
  }
  {
    name: 'snet-adds-mgmt'
    addressPrefix: addsMgmtSnetAddressPrefix
  }
]

var avdNsgRules = [
  {
    name: 'AVDServiceTraffic'
    properties: {
      priority: 100
      access: 'Allow'
      description: 'Session host traffic to AVD control plane'
      destinationAddressPrefix: 'WindowsVirtualDesktop'
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '443'
      protocol: 'Tcp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AzureCloud'
    properties: {
      priority: 110
      access: 'Allow'
      description: 'Session host traffic to Azure cloud services'
      destinationAddressPrefix: 'AzureCloud'
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '8443'
      protocol: 'Tcp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AzureMonitor'
    properties: {
      priority: 120
      access: 'Allow'
      description: 'Session host traffic to Azure Monitor'
      destinationAddressPrefix: 'AzureMonitor'
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '443'
      protocol: 'Tcp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AzureMarketPlace'
    properties: {
      priority: 130
      access: 'Allow'
      description: 'Session host traffic to Azure Monitor'
      destinationAddressPrefix: 'AzureFrontDoor.Frontend'
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '443'
      protocol: 'Tcp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'WindowsActivationKMS'
    properties: {
      priority: 140
      access: 'Allow'
      description: 'Session host traffic to Windows license activation services'
      destinationAddressPrefixes: [
        '20.118.99.224'
        '40.83.235.53'
        '23.102.135.246'
      ]
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '1688'
      protocol: 'Tcp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AzureInstanceMetadata'
    properties: {
      priority: 150
      access: 'Allow'
      description: 'Session host traffic to Azure instance metadata'
      destinationAddressPrefix: '169.254.169.254'
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '80'
      protocol: 'Tcp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'RDPShortpath'
    properties: {
      priority: 150
      access: 'Allow'
      description: 'Session host traffic to RDP Shortpath Listener'
      destinationAddressPrefix: 'VirtualNetwork'
      direction: 'Inbound'
      sourcePortRange: '*'
      destinationPortRange: '3390'
      protocol: 'Udp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'RDPShortpathTurnStun'
    properties: {
      priority: 160
      access: 'Allow'
      description: 'Session host traffic to RDP shortpath STUN/TURN'
      destinationAddressPrefix: '20.202.0.0/16'
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '3478'
      protocol: 'Udp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'RDPShortpathTurnRelay'
    properties: {
      priority: 170
      access: 'Allow'
      description: 'Session host traffic to RDP shortpath STUN/TURN'
      destinationAddressPrefix: '51.5.0.0/16'
      direction: 'Outbound'
      sourcePortRange: '*'
      destinationPortRange: '3478'
      protocol: 'Udp'
      sourceAddressPrefix: 'VirtualNetwork'
    }
  }
]
var avdVnetAddressPrefix = '10.0.2.0/24'
var avdSubnets = [
  {
    name: 'snet-avd-marketplace-hosts'
    addressPrefix: '10.0.2.0/26'
  }
  {
    name: 'snet-avd-customimage-hosts'
    addressPrefix: '10.0.2.64/26'
  }
  {
    name: 'snet-privateEndpoints'
    addressPrefix: '10.0.2.192/26'
  }
]

var hubVnetAddressPrefix = '10.0.0.0/24'

var firewallSnetAddressPrefix = '10.0.0.0/26'

var bastionSnetAddressPrefix = '10.0.0.64/26'

var gatewaySnetAddressPrefix = '10.0.0.192/26'


var deploymentSuffix = substring(deployment().name, length(deployment().name) - 14, 12)

var locations = (loadJsonContent('data/locations.json'))[environment().name]

var resourceGroups = [
  'rg-security-monitoring-${locations[location].abbreviation}'
  'rg-hub-networking-${locations[location].abbreviation}'
  'rg-adds-${locations[location].abbreviation}'
  'rg-privateDnsZones-${locations[location].abbreviation}'
  'rg-avd-networking-${locations[location].abbreviation}'
  'rg-management-${locations[location].abbreviation}'
]

var mgmtVmImagePublisher = 'MicrosoftWindowsDesktop'
var mgmtVmImageOffer = 'Windows-11'
var mgmtVmImageSku = 'win11-24h2-ent'

resource rgs 'Microsoft.Resources/resourceGroups@2024-03-01' = [for rg in resourceGroups: {
  name: rg
  location: location
  tags: tagsByResourceType[?'Microsoft.Resources/resourceGroups'] ?? {}
}]

module monitoring 'monitoring/monitoring.bicep' = {
  name: 'monitoring-${deploymentSuffix}'
  scope: resourceGroup(resourceGroups[0])
  params: {
    dataCollectionRuleName: 'dcr-security-${locations[location].abbreviation}'
    location: location
    logAnalyticsWorkspaceName: 'log-security-${locations[location].abbreviation}'
    tagsByResourceType: tagsByResourceType
  }
  dependsOn: [
    rgs
  ]
}

module hubNetworking 'networking/hubNetworking.bicep' = {
  scope: resourceGroup(resourceGroups[1])
  name: 'hub-networking-${deploymentSuffix}'
  params: {
    availabilityZones: availabilityZones
    hubVnetAddresses: [hubVnetAddressPrefix]
    addsSubnetAddresses: [addsVnetAddressPrefix]
    avdSubnetAddresses: [avdVnetAddressPrefix]
    bastionName: 'bas-${locations[location].abbreviation}'
    bastionPublicIpName: 'pip-bas-${locations[location].abbreviation}'
    firewallName: 'afw-${locations[location].abbreviation}'
    firewallPolicyName: 'afwp-${locations[location].abbreviation}'
    firewallPublicIpName: 'pip-afw-${locations[location].abbreviation}'
    location: location
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    vnetName: 'vnet-hub-${locations[location].abbreviation}'
    dnsServers: addsServerAddresses
    tagsByResourceType: tagsByResourceType
    bastionSubnetPrefix: bastionSnetAddressPrefix
    firewallSubnetPrefix: firewallSnetAddressPrefix
    gatewaySubnetPrefix: gatewaySnetAddressPrefix
  }
  dependsOn: [
    rgs
  ]
}

module addsNetworking 'networking/spokeNetworking.bicep' = {
  name: 'adds-networking-${deploymentSuffix}'
  scope: resourceGroup(resourceGroups[2])
  params: {
    deploymentSuffix: deploymentSuffix
    dnsServers: []
    fwIPAddress: hubNetworking.outputs.firewallIp
    hubVnetResourceId: hubNetworking.outputs.hubVnetResourceId
    location: location
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceId
    nsgName: 'nsg-adds-${locations[location].abbreviation}'
    nsgSecurityRules: addsNsgRules
    routeTableName: 'rt-adds-${locations[location].abbreviation}'
    subnets: addsSubnets
    tagsByResourceType: tagsByResourceType
    vnetAddresses: [
      addsVnetAddressPrefix
    ]
    vnetName: 'vnet-adds-${locations[location].abbreviation}'
  }
  dependsOn: [
    rgs
  ]
}

module privateDNSZones 'networking/privateDnsZones.bicep' = {
  name: 'Private-DNS-Zones-${deploymentSuffix}'
  scope: resourceGroup(resourceGroups[3])
  params: {
    recoveryServicesGeo: locations[location].recoveryServicesGeo
    tags: tagsByResourceType[?'Microsoft.Network/privateDnsZones'] ?? {}
    vnetId: addsNetworking.outputs.vnetResourceId
  }
  dependsOn: [
    rgs
  ]
}

module avdNetworking 'networking/spokeNetworking.bicep' = {
  name: 'avd-networking-${deploymentSuffix}'
  scope: resourceGroup(resourceGroups[4])
  params: {
    deploymentSuffix: deploymentSuffix
    dnsServers: [
      hubNetworking.outputs.firewallIp
    ]
    fwIPAddress: hubNetworking.outputs.firewallIp
    hubVnetResourceId: hubNetworking.outputs.hubVnetResourceId
    location: location
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceId
    nsgName: 'nsg-avd-${locations[location].abbreviation}'
    nsgSecurityRules: avdNsgRules
    routeTableName: 'rt-avd-${locations[location].abbreviation}'
    subnets: avdSubnets
    tagsByResourceType: tagsByResourceType
    vnetAddresses: [
      avdVnetAddressPrefix
    ]
    vnetName: 'vnet-avd-${locations[location].abbreviation}'
  }
  dependsOn: [
    rgs
  ]
}

module domainController 'compute/domainController.bicep' = {
  name: 'adds-servers-${deploymentSuffix}'
  scope: resourceGroup(resourceGroups[2])
  params: {
    adDomainName: adDomainName
    adminPassword: adAdminPassword
    adminUsername: adAdminUsername
    assetLocation: assetLocation
    defaultUserPassword: defaultUserPassword
    entraIdPrimaryOrCustomDomainName: entraIdPrimaryOrCustomDomainName
    location: location
    subnetResourceId: addsNetworking.outputs.subnetResourceIds[0]
    tagsByResourceType: tagsByResourceType
    vmSize: vmSize
  }
  dependsOn: [
    rgs
  ]
}

module managementVm 'compute/managementVm.bicep' = {
  name: 'management-vm-${deploymentSuffix}'
  scope: resourceGroup(resourceGroups[5])
  params: {
    dnsServers: addsServerAddresses
    domainJoinUserName: '${adAdminUsername}@${adDomainName}'
    domainJoinUserPassword: adAdminPassword
    domainName: adDomainName
    imageOffer: mgmtVmImageOffer
    imagePublisher: mgmtVmImagePublisher
    imageSku: mgmtVmImageSku
    vmAdminPassword: adAdminPassword
    vmAdminUserName: 'vmAdmin'
    subnetResourceId: addsNetworking.outputs.subnetResourceIds[1]
    tagsByResourceType: tagsByResourceType
    vmSize: vmSize
  }
  dependsOn: [
    domainController
  ]
}
