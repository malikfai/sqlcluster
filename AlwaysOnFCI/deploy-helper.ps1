Connect-AzAccount -Environmentname AzureUSGovernment

$deploymentName = "deploy-sqlcluster-fci"
$resourceGroupName = "sqlcluster"
$namePrefix = "fm-fci"
$localAdminUsername = "local-admin"
$localAdminPassword = Read-Host -MaskInput -Prompt "Enter local admin password"
$domainName = "contoso.local"
$domainAdminUsername = "fmadmin"
$domainAdminPassword = Read-Host -MaskInput -Prompt "Enter domain admin password"
$sqlServiceUserName = "sqlservice"
$sqlServicePassword = Read-Host -MaskInput -Prompt "Enter SQL service account password"
$existingSqlSubnetName = "sqlSubnet"
$existingVirtualNetworkName = "autohav2VNEThef"
$sqlDiskSize = 1024
$sqlLBIPAddress = "10.0.1.10"
$windowsImagePublisher = "MicrosoftSQLServer"
$windowsImageOffer = "SQL2014SP2-WS2012R2"
$windowsImageSKU = "Enterprise"
$windowsImageVersion = "latest"
$_artifactsLocation = "https://raw.githubusercontent.com/malikfai/sqlcluster/main/AlwaysOnFCI/"

$templateParameterObject = @{
    "namePrefix" = $namePrefix
    "localAdminUsername" = $localAdminUsername
    "localAdminPassword" = $localAdminPassword
    "domainName" = $domainName
    "domainAdminUsername" = $domainAdminUsername
    "domainAdminPassword" = $domainAdminPassword
    "sqlServiceUserName" = $sqlServiceUserName
    "sqlServicePassword" = $sqlServicePassword
    "existingSqlSubnetName" = $existingSqlSubnetName
    "existingVirtualNetworkName" = $existingVirtualNetworkName
    "sqlLBIPAddress" = $sqlLBIPAddress
    "sqlDiskSize" = $sqlDiskSize
    "windowsImagePublisher" = $windowsImagePublisher
    "windowsImageOffer" = $windowsImageOffer
    "windowsImageSKU" = $windowsImageSKU
    "windowsImageVersion" = $windowsImageVersion
    "_artifactsLocation" = $_artifactsLocation
}

New-AzResourceGroupDeployment -name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile .\azuredeploy.json -TemplateParameterObject $templateParameterObject -Verbose

