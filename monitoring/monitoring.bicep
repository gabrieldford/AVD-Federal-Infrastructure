param dataCollectionRuleName string
param location string
param logAnalyticsWorkspaceName string
param tagsByResourceType object

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: tagsByResourceType[?'Microsoft.OperationalInsights/workspaces'] ?? {}
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dataCollectionRuleName
  location: location
  tags: tagsByResourceType[?'Microsoft.Insights/dataCollectionRules'] ?? {}
  kind: 'Windows'
  properties: {
    dataSources: {
      windowsEventLogs: [
        {
          streams: [
            'Microsoft-Event'
          ]
          xPathQueries: [
            'Security!*[System[(band(Keywords,13510798882111488))]]'
          ]
          name: 'eventLogsDataSource'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Event'
        ]
        destinations: [
          logAnalyticsWorkspace.name
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-Event'
      }
    ]
    destinations: {
      logAnalytics: [
        {
          name: logAnalyticsWorkspace.name
          workspaceResourceId: logAnalyticsWorkspace.id
        }
      ]
    }
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
