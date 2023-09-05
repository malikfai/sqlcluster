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

    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName StorageDsc
    
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
            DiskId = "2"
            DriveLetter = "F"
            DependsOn = "[WaitForDisk]Disk2"
        }

        WindowsFeature ADPS {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        } 

        Computer DomainJoin {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainAdminCredential
        }

        File FSWFolder {
            DestinationPath = "F:\$($SharePath.ToUpperInvariant())"
            Type = "Directory"
            Ensure = "Present"
            DependsOn = "[Computer]DomainJoin"
        }

        SmbShare FSWShare {
            Name = $SharePath.ToUpperInvariant()
            Path = "F:\$($SharePath.ToUpperInvariant())"
            FullAccess = "BUILTIN\Administrators"
            Ensure = "Present"
            DependsOn = "[File]FSWFolder"
        }
    }     
}
