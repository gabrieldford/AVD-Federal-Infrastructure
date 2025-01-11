$FolderPath = "$env:Temp\AIB”
New-Item -Path $FolderPath -ItemType Directory -Force

$aibRoleImageCreationUrl="https://raw.githubusercontent.com/shawntmeyer/AVDFedRockstarTraining/master/Azure%20Image%20Builder/aibRoleImageCreation.json"
$aibRoleImageCreationPath = Join-Path -Path $FolderPath -ChildPath "aibRoleImageCreation.json"

# download config
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>', $subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath

$Json = (Get-Content -Path $aibRoleImageCreationPath -Raw) | ConvertFrom-Json
$imageRoleDefName = $Json.Name

# create role definition
New-AzRoleDefinition -InputFile $aibRoleImageCreationPath
While ($null -eq (Get-AzRoleDefinition | Where-Object {$_.Name -eq $imageRoleDefName})) {
	Start-Sleep 5
}
# grant role definition to image builder service principal
New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"
