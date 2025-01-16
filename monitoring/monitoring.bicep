param dataCollectionRuleName string
param location string
param logAnalyticsWorkspaceName string
param tagsByResourceType object

module logAnalyticsWorkspace './logAnalyticsWorkspace.bicep' = {
  name: 'logAnalyticsWorkspace'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    location: location
    tags: tagsByResourceType[?'Microsoft.OperationalInsights/workspaces'] ?? {}
  }
}

module dataCollectionRule './dataCollectionRule.bicep' = {
  name: 'dataCollectionRule'
  params: {
    dataCollectionRuleName: dataCollectionRuleName
    location: location
    logAnalyticsWorkspaceName: logAnalyticsWorkspace.outputs.name
    tags: tagsByResourceType[?'Microsoft.Insights/dataCollectionRules'] ?? {}
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.resourceId
