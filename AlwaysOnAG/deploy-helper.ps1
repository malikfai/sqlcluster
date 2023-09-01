Connect-AzAccount -Environmentname AzureUSGovernment

$deploymentName = "deploy-sqlcluster"
$resourceGroupName = "sqlcluster"
$namePrefix = "fm-ag"
$existingDomainName = "contoso.local"
$adminUsername = "fmadmin"
$adminPassword = "!Welcome2023"
##Read-Host -MaskInput -Prompt "Enter SQL Service Acct Password"
##Read-Host -AsSecureString -Prompt "Enter Admin Password"
$sqlServerServiceAccountUserName = "sqlservice"
$sqlServerServiceAccountPassword = "!Welcome2023"
##Read-Host -MaskInput -Prompt "Enter SQL Service Acct Password"
$existingSqlSubnetName = "sqlSubnet"
$existingVirtualNetworkName = "autohav2VNEThef"
$existingAdPDCVMName = "ad-primary-dc"
$sqlLBIPAddress = "10.0.1.10"
$windowsImagePublisher = "MicrosoftSQLServer"
$windowsImageOffer = "SQL2014SP2-WS2012R2"
$windowsImageSKU = "Enterprise"
$windowsImageVersion = "latest"
$sqlDiskSize = 1024
$_artifactsLocation = "https://raw.githubusercontent.com/malikfai/sqlcluster/main/AlwaysOnAG/"

$templateParameterObject = @{
    "namePrefix" = $namePrefix
    "existingDomainName" = $existingDomainName
    "adminUsername" = $adminUsername
    "adminPassword" = $adminPassword
    "sqlServerServiceAccountUserName" = $sqlServerServiceAccountUserName
    "sqlServerServiceAccountPassword" = $sqlServerServiceAccountPassword
    "existingSqlSubnetName" = $existingSqlSubnetName
    "existingVirtualNetworkName" = $existingVirtualNetworkName
    "existingAdPDCVMName" = $existingAdPDCVMName
    "sqlLBIPAddress" = $sqlLBIPAddress
    "windowsImagePublisher" = $windowsImagePublisher
    "windowsImageOffer" = $windowsImageOffer
    "windowsImageSKU" = $windowsImageSKU
    "windowsImageVersion" = $windowsImageVersion
    "sqlDiskSize" = $sqlDiskSize
    "_artifactsLocation" = $_artifactsLocation
}

New-AzResourceGroupDeployment -name $deploymentName -ResourceGroupName $resourceGroupName -TemplateFile .\azuredeploy.json -TemplateParameterObject $templateParameterObject -Verbose

