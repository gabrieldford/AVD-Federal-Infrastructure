@description('The address prefixes of the Domain Controller subnet/vnet.')
param addsSubnetAddresses array

@description('The address Prefixes of the AVD Session Hosts.')
param avdSubnetAddresses array

@description('The availability zones available for the resources.')
param availabilityZones array

@description('The DNS servers to use for the virtual network.')
param dnsServers array = []

@description('The address prefix for the virtual network.')
param vnetAddressPrefix string

@description('The name of the Azure Firewall policy.')
param firewallPolicyName string

@description('The address prefix for the Azure Firewall subnet.')
param firewallSubnetPrefix string

@description('The address prefix for the Azure Bastion subnet.')
param bastionSubnetPrefix string

@description('The address prefix for the ExpressRoute Gateway subnet.')
param gatewaySubnetPrefix string

@description('The name of the virtual network.')
param vnetName string

@description('The name of the Azure Firewall.')
param firewallName string

@description('The name of the public IP for the Azure Firewall.')
param firewallPublicIpName string

@description('The name of the Azure Bastion.')
param bastionName string

@description('The name of the public IP for the Azure Bastion.')
param bastionPublicIpName string

@description('The location of the resources.')
param location string = resourceGroup().location

param tagsByResourceType object

resource vnet 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: firewallSubnetPrefix
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: gatewaySubnetPrefix
        }
      }
    ]    
  }
  tags: tagsByResourceType[?'Microsoft.Network/virtualNetworks'] ?? {}
}

resource firewallPublicIp 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: firewallPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tagsByResourceType[?'Microsoft.Network/publicIPAddresses'] ?? {}
  zones: empty(availabilityZones) ? null : availabilityZones
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: bastionPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tagsByResourceType[?'Microsoft.Network/publicIPAddresses'] ?? {}
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2023-02-01' = {
  name: firewallPolicyName
  location: location
  properties: {
    dnsSettings: {
      servers: !empty(dnsServers) ? dnsServers : null
      enableProxy: true
    }
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
  }
  tags: tagsByResourceType[?'Microsoft.Network/firewallPolicies'] ?? {}
}

resource ruleCollectionGroup_AVDCore 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-03-01' = {
  parent: firewallPolicy
  name: 'AVD-Core'
  properties: {
    priority: 10000
    ruleCollections: [
      {
        action: {
          type: 'Allow'
        }
        name: 'NetworkRules_AVD-Core'
        priority: 10100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'AVD Service Traffic'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: [
              'WindowsVirtualDesktop'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Agent Traffic (1)'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: [
              'AzureMonitor'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Agent Traffic (2)'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              'gcs.prod.monitoring.${environment().suffixes.storage}'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure Marketplace'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: [
              'AzureFrontDoor.Frontend'
            ]
            destinationIpGroups: []
            destinationFqdns: []
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Windows activation'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              'kms.${environment().suffixes.storage}'
            ]
            destinationPorts: [
              '1688'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure Windows activation'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              'azkms.${environment().suffixes.storage}'
            ]
            destinationPorts: [
              '1688'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Agent and SXS Stack Updates'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              'mrsglobalsteus2prod.blob.${environment().suffixes.storage}'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure Portal Support'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              'wvdportalstorageblob.blob.${environment().suffixes.storage}'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Certificate CRL OneOCSP'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              'oneocsp.microsoft.com'
            ]
            destinationPorts: [
              '80'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Certificate CRL MicrosoftDotCom'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              'www.microsoft.com'
            ]
            destinationPorts: [
              '80'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Authentication to Microsoft Online Services'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            sourceIpGroups: []
            destinationAddresses: []
            destinationIpGroups: []
            destinationFqdns: [
              replace(replace(environment().authentication.loginEndpoint, 'https://', ''), '/', '')
            ]
            destinationPorts: [
              '443'
            ]
          }
        ]
      }
    ]
  }
}

resource ruleCollectionGroup_AVDOptional 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-03-01' = {
  parent: firewallPolicy
  name: 'AVD-Optional'
  properties: {
    priority: 11000
    ruleCollections: [
      {
        name: 'NetworkRules_AVD-Optional'
        action: {
          type: 'Allow'
        }
        priority: 11100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'NTP'
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationFqdns: [
              'time.windows.com'
            ]
            destinationPorts: [
              '123'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'SigninToMSOL365'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationFqdns: [
              replace(replace(environment().authentication.loginEndpoint, 'https://', ''), '/', '')
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'DetectOSconnectedToInternet'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationFqdns: [
              'www.msftconnecttest.com'
            ]
            destinationPorts: [
              '443'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'RDP Shortpath Server Endpoint'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: [
              '*'
            ]
            destinationPorts: [
              '49152-65535'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'STUN/TURN UDP'
            ipProtocols: [
              'UDP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: [
              '20.202.0.0/16'
            ]
            destinationPorts: [
              '3478'
            ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'STUN/TURN TCP'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: [
              '20.202.0.0/16'
            ]
            destinationPorts: [
              '443'
            ]
          }
        ]
      }
      {
        name: 'ApplicationRules_AVD-Optional'
        action: {
          type: 'Allow'
        }
        priority: 11200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'TelemetryService'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.events.data.microsoft.com'
            ]
            targetUrls: []
            terminateTLS: false
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: []
            sourceIpGroups: []
          }
          {
            ruleType: 'ApplicationRule'
            name: 'WindowsUpdate'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: [
              'WindowsUpdate'
            ]
            terminateTLS: false
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: []
            sourceIpGroups: []
          }
          {
            ruleType: 'ApplicationRule'
            name: 'UpdatesForOneDrive'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.sfx.ms'
            ]
            terminateTLS: false
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: []
            sourceIpGroups: []
          }
          {
            ruleType: 'ApplicationRule'
            name: 'DigicertCRL'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.digicert.com'
            ]
            terminateTLS: false
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: []
            sourceIpGroups: []
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AzureDNSresolution'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*.azure-dns.com'
              '*.azure-dns.net'
            ]
            terminateTLS: false
            sourceAddresses: avdSubnetAddresses
          }
          {
            ruleType: 'ApplicationRule'
            name: 'WindowsDiagnostics'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: [
              'WindowsDiagnostics'
            ]
            webCategories: []
            targetFqdns: []
            targetUrls: []
            terminateTLS: false
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: []
            sourceIpGroups: []
          }
        ]
      }
    ]
  }
  dependsOn: [
    ruleCollectionGroup_AVDCore
  ]
}

resource ruleCollectionGroup_ADDSCore 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-03-01' = {
  name: 'ADDS-Core'
  parent: firewallPolicy
  properties: {
    priority: 5000
    ruleCollections: [
      {
        action: {
          type: 'Allow'
        }
        name: 'NetworkRules_AllowBastionToDC'
        priority: 5100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            name: 'Bastion To DC RDP'
            ruleType: 'NetworkRule'
            sourceAddresses: [bastionSubnetPrefix]
            destinationAddresses: addsSubnetAddresses
            destinationPorts: [
              '3389'
            ]
            ipProtocols: [
              'TCP'
            ]
          }          
        ]
      }
      {
        action: {
          type: 'Allow'
        }
        name: 'NetworkRules_AllowAVDToDC'
        priority: 5200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            name: 'AVD Subnet to DC Subnet TCP'
            ruleType: 'NetworkRule'
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: addsSubnetAddresses
            destinationPorts: [
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
            ipProtocols: [
              'TCP'
            ]
          }
          {
            name: 'AVD Subnet to DC Subnet UDP'
            ruleType: 'NetworkRule'
            sourceAddresses: avdSubnetAddresses
            destinationAddresses: addsSubnetAddresses
            destinationPorts: [
              '88' // Kerberos
              '389' // LDAP
            ]
            ipProtocols: [
              'UDP'
            ]
          }
        ]
      }
    ]
  }
  dependsOn: [
    ruleCollectionGroup_AVDCore
    ruleCollectionGroup_AVDOptional
  ]
}

resource ruleCollectionGroup_ADDSOptional 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-03-01' = {
  name: 'ADDS-Optional'
  parent: firewallPolicy
  properties: {
    priority: 6000
    ruleCollections: [
      {
        name: 'NetworkRules_ADDS-Optional'
        action: {
          type: 'Allow'
        }
        priority: 6100
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'NTP'
            ipProtocols: [
              'TCP'
              'UDP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationFqdns: [
              'time.windows.com'
            ]
            destinationPorts: [
              '123'
            ]
          }          
          {
            ruleType: 'NetworkRule'
            name: 'DetectOSconnectedToInternet'
            ipProtocols: [
              'TCP'
            ]
            sourceAddresses: avdSubnetAddresses
            destinationFqdns: [
              'www.msftconnecttest.com'
            ]
            destinationPorts: [
              '443'
            ]
          }
        ]
      }      
      {
        name: 'ApplicationRules_DCsToInternet'
        action: {
          type: 'Allow'
        }
        priority: 6200
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'Allow all web traffic'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            targetFqdns: [
              '*'
            ]
            terminateTLS: false
            sourceAddresses: addsSubnetAddresses
            destinationAddresses: []
            sourceIpGroups: []
          }          
        ]
      }
    ]
  }
  dependsOn: [
    ruleCollectionGroup_AVDCore
    ruleCollectionGroup_AVDOptional
    ruleCollectionGroup_ADDSCore
  ]
}


resource azureFirewall 'Microsoft.Network/azureFirewalls@2023-02-01' = {
  name: firewallName
  location: location
  properties: {
    sku: {
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPolicy.id
    }
    ipConfigurations: [
      {
        name: 'azureFirewallIpConfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: firewallPublicIp.id
          }
        }
      }
    ]
  }
  tags: tagsByResourceType[?'Microsoft.Network/azureFirewalls'] ?? {}
  zones: empty(availabilityZones) ? null : availabilityZones
  dependsOn: [
    ruleCollectionGroup_ADDSCore
    ruleCollectionGroup_AVDCore
    ruleCollectionGroup_AVDOptional
    ruleCollectionGroup_ADDSOptional
  ]
}

resource azureBastion 'Microsoft.Network/bastionHosts@2023-02-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[1].id
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
  tags: tagsByResourceType[?'Microsoft.Network/bastionHosts'] ?? {}
}

output hubVnetResourceId string = vnet.id
output firewallIp string = azureFirewall.properties.ipConfigurations[0].properties.privateIPAddress
