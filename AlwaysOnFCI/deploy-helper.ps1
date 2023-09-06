Connect-AzAccount -Environmentname AzureUSGovernment

$deploymentName = "deploy-sqlcluster-fci"
$resourceGroupName = "sqlcluster"
$namePrefix = "fm-fci"
$domainName = "contoso.local"
$domainAdminUsername = "fmadmin"
$domainAdminPassword = "!Welcome2023" #Read-Host -MaskInput -Prompt "Enter Domain Admin Password"
$sqlServiceUserName = "sqlservice"
$sqlServicePassword = "!Welcome2023" #Read-Host -MaskInput -Prompt "Enter SQL Service Acct Password"
$localAdminUsername = "local-admin"
$localAdminPassword = "!Welcome2023"
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

