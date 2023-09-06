try {
    Import-Module Az.Compute

    $originalModulePath = $env:PSModulePath
    $tempModulePaths = @(Get-Module -Name PSDesiredStateConfiguration -ListAvailable | Select-Object -ExpandProperty ModuleBase)
    $tempModulePaths += $(Get-Module -Name Microsoft.Powershell.Management -ListAvailable | Select-Object -ExpandProperty Path | Split-Path -Parent)
    $tempModulePaths += [system.io.path]::Combine($PSScriptRoot, 'dsc', 'modules')
    $env:PSModulePath = $($tempModulePaths -Join ';')

    Publish-AzVMDscConfiguration -ConfigurationPath "$PSScriptRoot\dsc\CreateFailoverCluster.ps1" -OutputArchivePath "$PSScriptRoot\dsc\CreateFailoverCluster.ps1.zip" -Force
    Publish-AzVMDscConfiguration -ConfigurationPath "$PSScriptRoot\dsc\CreateFileShareWitness.ps1" -OutputArchivePath "$PSScriptRoot\dsc\CreateFileShareWitness.ps1.zip" -Force
    Publish-AzVMDscConfiguration -ConfigurationPath "$PSScriptRoot\dsc\PrepareAlwaysOnSqlServer.ps1" -OutputArchivePath "$PSScriptRoot\dsc\PrepareAlwaysOnSqlServer.ps1.zip" -Force
}
finally {
    $env:PSModulePath = $originalModulePath
}