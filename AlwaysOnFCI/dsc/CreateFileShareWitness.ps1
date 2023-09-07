#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration CreateFileShareWitness
{
    param
    (
        [Parameter(Mandatory)]
        [String]
        $DomainName,

        [String]
        $DomainNetbiosName = (Get-NetBIOSName -DomainName $DomainName),

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $DomainAdminCredential,

        [Parameter(Mandatory)]
        [String]
        $SharePath
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "8.5.0"
    Import-DscResource -ModuleName StorageDsc -ModuleVersion "5.0.1"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCredential.UserName)", $DomainAdminCredential.Password)

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
        }

        WaitforDisk Disk2 {
            DiskId = "2"
            RetryIntervalSec = 20
            RetryCount = 30
        }

        Disk DataDisk {
            DependsOn = "[WaitForDisk]Disk2"
            DiskId = "2"
            DriveLetter = "F"
        }

        Computer DomainJoin {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
        }

        File FSWFolder {
            DependsOn = "[Computer]DomainJoin"
            Ensure = "Present"
            Type = "Directory"
            DestinationPath = "F:\$($SharePath.ToUpperInvariant())"
        }

        SmbShare FSWShare {
            DependsOn = "[File]FSWFolder"
            Ensure = "Present"
            Name = $SharePath.ToUpperInvariant()
            Path = "F:\$($SharePath.ToUpperInvariant())"
            FullAccess = "BUILTIN\Administrators"
        }
    }     
}

function Get-NetBIOSName { 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length = $DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length = 15
        }
        return $DomainName.Substring(0, $length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0, 15)
        }
        else {
            return $DomainName
        }
    }
}