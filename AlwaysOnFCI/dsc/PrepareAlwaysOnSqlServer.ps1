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

    Import-DscResource -ModuleName ActiveDirectoryDsc
    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName NetworkingDsc
    Import-DscResource -ModuleName SqlServerDsc
    Import-DscResource -ModuleName StorageDsc

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
            DiskId = "2"
            DriveLetter = "F"
            DependsOn = "[WaitForDisk]Disk2"
        }

        WaitforDisk Disk3
        {
            DiskId = "3"
            RetryIntervalSec = $RetryIntervalSec
            RetryCount = $RetryCount
        }

        Disk DataDisk {
            DiskId = "3"
            DriveLetter = "G"
            DependsOn = "[WaitForDisk]Disk3"
        }

        WindowsFeature Failover-Clustering {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

        WindowsFeature RSAT-Clustering-PowerShell {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
        }

        WindowsFeature RSAT-AD-PowerShell {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }
        
        WaitForADDomain WaitForDomain { 
            DependsOn = "[WindowsFeature]RSAT-AD-PowerShell"
            DomainName = $DomainName 
            Credential = $DomainCreds
        }

        Computer DomainJoin {
            DependsOn = "[WaitForADDomain]WaitForDomain"
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
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

        SqlLogin AddDomainAdminSqlLogin {
            DependsOn = "[WindowsFeature]RSAT-AD-PowerShell"
            Ensure = "Present"
            Name = $DomainCreds.UserName
            LoginType = "WindowsUser"
            InstanceName = "MSSQLSERVER"
            PsDscRunAsCredential = $DomainAdminCredential
        }

        SqlRole AddDomainAdminSqlLoginToSysadminServerRole {
            DependsOn = "[SqlLogin]AddDomainAdminAccountToSysadminServerRole"
            Ensure = "Present"
            ServerRoleName = "sysadmin"
            InstanceName = "MSSQLSERVER"
            MembersToInclude = $DomainCreds.UserName
        }

        ADUser CreateSqlServerServiceAccount {
            DependsOn = "[SqlRole]AddDomainAdminSqlLoginToSysadminServerRole"
            Ensure = "Present"
            DomainName = $DomainName
            UserName = $SqlServiceCredential.UserName
            Password = $SqlServiceCredential
            PsDscRunAsCredential = $DomainCreds
        }

        SqlLogin AddSqlServerServiceAccountToSysadminServerRole {
            DependsOn = "[ADUser]CreateSqlServerServiceAccount"
            Name = $SQLCreds.UserName
            LoginType = "WindowsUser"
            InstanceName = "MSSQLSERVER"
            PsDscRunAsCredential = $DomainAdminCredential
        }
        
        SqlRole AddDomainAdminSqlLoginToSysadminServerRole {
            DependsOn = "[SqlLogin]AddSqlServerServiceAccountToSysadminServerRole"
            Ensure = "Present"
            ServerRoleName = "sysadmin"
            InstanceName = "MSSQLSERVER"
            MembersToInclude = $SQLCreds.UserName
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
