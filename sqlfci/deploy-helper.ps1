Connect-AzAccount -Environmentname AzureUSGovernment

$deploymentName = "deploy-sqlcluster-fci"
$resourceGroupName = "sqlcluster"
$namePrefix = "fm-fci"
$existingDomainName = "contoso.local"
$existingAdminUsername = "fmadmin"
$existingAdminPassword = "!Welcome2023" #Read-Host -MaskInput -Prompt "Enter domain admin password"
$existingSqlServiceAccountUserName = "sqlservice"
$existingSqlServiceAccountPassword = "!Welcome2023" #Read-Host -MaskInput -Prompt "Enter SQL service account password"
$existingSubnetResourceID = "/subscriptions/22d888ba-fc6d-4539-8483-172985f2a28f/resourceGroups/sqlcluster/providers/Microsoft.Network/virtualNetworks/autohav2VNEThef/subnets/sqlSubnet"
$witnessType = "Disk"
$_artifactsLocation = "https://raw.githubusercontent.com/malikfai/sqlcluster/main/sqlfci/"

$templateParameterObject = @{
    "namePrefix" = $namePrefix
    "existingDomainName" = $existingDomainName
    "existingAdminUsername" = $existingAdminUsername
    "existingAdminPassword" = $existingAdminPassword
    "existingSqlServiceAccountUserName" = $existingSqlServiceAccountUserName
    "existingSqlServiceAccountPassword" = $existingSqlServiceAccountPassword
    "existingSubnetResourceID" = $existingSubnetResourceID
    "witnessType" = $witnessType
    "_artifactsLocation" = $_artifactsLocation
}

New-AzResourceGroupDeployment -name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile .\azuredeploy.json -TemplateParameterObject $templateParameterObject -Verbose

