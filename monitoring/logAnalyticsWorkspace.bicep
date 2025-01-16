param logAnalyticsWorkspaceName string
param location string
param tags object

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: tags
}

output name string = logAnalyticsWorkspace.name
output resourceId string = logAnalyticsWorkspace.id
