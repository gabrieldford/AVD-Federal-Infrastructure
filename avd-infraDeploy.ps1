# Variables
$location = "usgovvirginia" # Replace with your desired Azure Government region
$templateFile = "c:\AVD-Federal\AVD-Federal-Infrastructure\deploy.bicep" # Path to your Bicep file
$deploymentName = "avdFederalDeployment" # Unique name for the deployment
$parameters = @{
    location = $location
}

# Log in to Azure Government
Connect-AzAccount -Environment AzureUSGovernment

# Deploy the Bicep template
New-AzSubscriptionDeployment `
    -Name $deploymentName `
    -Location $location `
    -TemplateFile $templateFile `
    -TemplateParameterObject $parameters