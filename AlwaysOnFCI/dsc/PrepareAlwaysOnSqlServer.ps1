#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration PrepareAlwaysOnSqlServer
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
        [System.Management.Automation.PSCredential]
        $SqlServiceCredential,

        [UInt32]
        $DatabaseEnginePort = 1433,

        [Int]
        $RetryCount = 20,

        [Int]
        $RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory 
    #Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion "6.0.1"
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "8.5.0"
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion "8.2.0"
    Import-DscResource -ModuleName SqlServerDsc -ModuleVersion "16.0.0"
    Import-DscResource -ModuleName StorageDsc -ModuleVersion "5.0.1"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCredential.UserName)", $DomainAdminCredential.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SqlServiceCredential.UserName)", $SqlServiceCredential.Password)

    WaitForSqlSetup

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $True
        }

        WaitforDisk Disk2 {
            DiskId = "2"
            RetryIntervalSec = $RetryIntervalSec
            RetryCount = $RetryCount
        }

        Disk DataDisk {
            DependsOn = "[WaitForDisk]Disk2"
            DiskId = "2"
            DriveLetter = "F"
        }

        WaitforDisk Disk3
        {
            DiskId = "3"
            RetryIntervalSec = $RetryIntervalSec
            RetryCount = $RetryCount
        }

        Disk LogDisk {
            DependsOn = "[WaitForDisk]Disk3"
            DiskId = "3"
            DriveLetter = "G"
        }

        Computer DomainJoin {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
        }

        WindowsFeature Failover-Clustering {
            Ensure = "Present"
            Name = "Failover-Clustering"
        }

        WindowsFeature RSAT-Clustering-PowerShell {
            Ensure = "Present"
            Name = "RSAT-Clustering-PowerShell"
        }

        WindowsFeature RSAT-AD-PowerShell {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
        }

        Firewall DatabaseEngineFirewallRule {
            Ensure = "Present"
            Name = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            Protocol = "TCP"
            Direction = "Inbound"
            LocalPort = $DatabaseEnginePort -as [String]
        }

        Firewall ListenerFirewallRule {
            Ensure = "Present"
            Name = "SQL-Server-ILB-Listener-TCP-In"
            DisplayName = "SQL Server Internal Load Balancer Listener (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the ILB listener."
            Protocol = "TCP"
            Direction = "Inbound"
            LocalPort = "59999"
        }


        xADUser CreateSqlServerServiceAccount
        {
            Ensure = "Present"
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SqlServiceCredential.UserName
            Password = $SqlServiceCredential
            DependsOn = "[WindowsFeature]RSAT-AD-PowerShell", "[Computer]DomainJoin"
        }

        # ADUser CreateSqlServerServiceAccount {
        #     DependsOn = "[WindowsFeature]RSAT-AD-PowerShell", "[Computer]DomainJoin"
        #     Ensure = "Present"
        #     DomainName = $DomainName
        #     UserName = $SqlServiceCredential.UserName
        #     Password = $SqlServiceCredential
        # }

        SqlLogin AddDomainAdminSqlLogin {
            DependsOn = "[xADUser]CreateSqlServerServiceAccount"
            Ensure = "Present"
            Name = $DomainCreds.UserName
            LoginType = "WindowsUser"
            InstanceName = "MSSQLSERVER"
        }

        SqlLogin AddSqlServerServiceSqlLogin {
            DependsOn = "[xADUser]CreateSqlServerServiceAccount"
            Name = $SQLCreds.UserName
            LoginType = "WindowsUser"
            InstanceName = "MSSQLSERVER"
        }
        
        SqlRole AddSysadminMembers {
            DependsOn = "[SqlLogin]AddDomainAdminSqlLogin", "[SqlLogin]AddSqlServerServiceSqlLogin"
            Ensure = "Present"
            ServerRoleName = "sysadmin"
            InstanceName = "MSSQLSERVER"
            MembersToInclude = $SQLCreds.UserName, $DomainCreds.UserName
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

function WaitForSqlSetup {
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true) {
        try {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch {
            break
        }
    }
}
