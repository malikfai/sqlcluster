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

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $DomainAdminCredential,

        [Parameter(Mandatory)]
        [String]
        $SharePath
    )

    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "8.5.0"
    Import-DscResource -ModuleName StorageDsc -ModuleVersion "5.0.1"
    
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

        WindowsFeature RSAT-AD-PowerShell {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        } 

        Computer DomainJoin {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainAdminCredential
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
