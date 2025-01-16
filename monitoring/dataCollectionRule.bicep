param dataCollectionRuleName string
param location string
param logAnalyticsWorkspaceName string
param tags object

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: dataCollectionRuleName
  location: location
  tags: tags
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
