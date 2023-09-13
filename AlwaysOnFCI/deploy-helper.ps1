Connect-AzAccount -Environmentname AzureUSGovernment

$deploymentName = "deploy-sqlcluster-fci"
$resourceGroupName = "sqlcluster"
$namePrefix = "fmfci"
$existingDomainName = "contoso.local"
$existingAdminUsername = "fmadmin"
$existingAdminPassword = "!Welcome2023" #Read-Host -MaskInput -Prompt "Enter domain admin password"
$existingSqlServiceAccountUserName = "sqlservice"
$existingSqlServiceAccountPassword = "!Welcome2023" #Read-Host -MaskInput -Prompt "Enter SQL service account password"
$existingSqlSubnetName = "sqlSubnet"
$existingVirtualNetworkName = "autohav2VNEThef"
$witnessType = "Cloud"
$sqlMsdtcIPAddress = "10.0.1.19"
$_artifactsLocation = "https://raw.githubusercontent.com/malikfai/sqlcluster/main/AlwaysOnFCI/"

$templateParameterObject = @{
    "namePrefix" = $namePrefix
    "existingDomainName" = $existingDomainName
    "existingAdminUsername" = $existingAdminUsername
    "existingAdminPassword" = $existingAdminPassword
    "existingSqlServiceAccountUserName" = $existingSqlServiceAccountUserName
    "existingSqlServiceAccountPassword" = $existingSqlServiceAccountPassword
    "existingSqlSubnetName" = $existingSqlSubnetName
    "existingVirtualNetworkName" = $existingVirtualNetworkName
    "witnessType" = $witnessType
    "sqlMsdtcIPAddress" = $sqlMsdtcIPAddress
    "_artifactsLocation" = $_artifactsLocation
}

New-AzResourceGroupDeployment -name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile .\azuredeploy.json -TemplateParameterObject $templateParameterObject -Verbose

