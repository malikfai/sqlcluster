#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration SqlClusterNode1
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
        $SharePath,
        
        [Parameter(Mandatory)]
        [String]
        $ClusterName,
        
        [Parameter(Mandatory)]
        [String]
        $ClusterIPAddress,

        [Parameter(Mandatory)]
        [String]
        $SqlClusterName,

        [Parameter(Mandatory)]
        [String]
        $SqlClusterIPAddress,

        [Parameter(Mandatory)]
        [string]
        $SqlClusterNode2Name,

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
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "8.5.0"
    Import-DscResource -ModuleName FailoverClusterDsc -ModuleVersion "2.1.0"
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion "8.2.0"
    Import-DscResource -ModuleName SqlServerDsc -ModuleVersion "16.0.0"
    Import-DscResource -ModuleName StorageDsc -ModuleVersion "5.0.1"
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xFailoverCluster

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCredential.UserName)", $DomainAdminCredential.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SqlServiceCredential.UserName)", $SqlServiceCredential.Password)

    $SqlSetupFolder = "C:\SQLServerFull\"
    
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

        WaitforDisk Disk3 {
            DiskId = "3"
            RetryIntervalSec = $RetryIntervalSec
            RetryCount = $RetryCount
        }

        Disk LogDisk {
            DependsOn = "[WaitForDisk]Disk3"
            DiskId = "3"
            DriveLetter = "G"
        }

        WindowsFeature Failover-Clustering {
            Ensure = "Present"
            Name = "Failover-Clustering"
        }

        WindowsFeature RSAT-Clustering-Mgmt { 
            DependsOn = "[WindowsFeature]Failover-Clustering"
            Ensure = "Present" 
            Name = "RSAT-Clustering-Mgmt"
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

        Computer DomainJoin {
            DependsOn = "[Disk]DataDisk", "[Disk]LogDisk", "[WindowsFeature]RSAT-Clustering-Mgmt"
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
        }

        xADUser CreateSqlServerServiceAccount
        {
            DependsOn = "[Computer]DomainJoin"
            Ensure = "Present"
            DomainAdministratorCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SqlServiceCredential.UserName
            Password = $SqlServiceCredential
        }

        WaitForAll WaitForSqlClusterNode2 {
            ResourceName = "[Computer]DomainJoin"
            NodeName = $SqlClusterNode2Name
            RetryIntervalSec = 15            
            RetryCount = 30 
            DependsOn = "[Computer]DomainJoin"
        }

        Script UninstallSql {
            PsDscRunAsCredential = $LocalAdminCredential
            SetScript = {
                try {
                    $sqlSetupPath = Join-Path $using:SqlSetupFolder 'setup.exe'
                    $sqlSetupArgs = '/Action=Uninstall /FEATURES=AS,IS,SQL,RS,Tools,DQC /INSTANCENAME=MSSQLSERVER /Quiet'
                    $process = Start-Process -FilePath $sqlSetupPath -ArgumentList $sqlSetupArgs -PassThru -Wait
                    $process.WaitForExit()
                }
                catch {
                    throw "Error uninstalling SQL features"
                }

            }
            GetScript = { @{} }
            TestScript = {
                return $false
            }
        }

        # xCluster FailoverCluster
        # {
        #     DependsOn = "[Computer]DomainJoin"
        #     Name = $ClusterName
        #     DomainAdministratorCredential = $DomainCreds
        #     Nodes = $(hostname)
        # }

        Cluster FailoverCluster {
            DependsOn = "[WaitForAll]WaitForSqlClusterNode2"
            Name = $ClusterName
            StaticIPAddress = $ClusterIPAddress
            DomainAdministratorCredential = $DomainCreds
        }

        # WaitForCluster WaitForCluster
        # {
        #     Name             = $ClusterName
        #     RetryIntervalSec = 10
        #     RetryCount       = 60
        #     DependsOn        = '[Cluster]FailoverCluster'
        # }

        # Cluster AddClusterNode
        # {
        #     Name                          = $ClusterName
        #     DomainAdministratorCredential = $DomainCreds
        #     DependsOn                     = '[WaitForCluster]WaitForCluster'
        # }
        

        # xWaitForFileShareWitness WaitForFSW
        # {
        #     SharePath = $SharePath
        #     DomainAdministratorCredential = $DomainCreds

        # }

        ClusterQuorum FailoverClusterQuorum
        {
            DependsOn = "[Cluster]FailoverCluster"
            IsSingleInstance = "Yes"
            Type = "NodeAndFileShareMajority"
            Resource = $SharePath
        }

        ClusterDisk AddClusterDataDisk {
            DependsOn = "[Cluster]FailoverCluster"
            Number = 2
            Ensure = "Present"
            Label = "SQL-DATA"
        }

        ClusterDisk AddClusterLogDisk {
            DependsOn = "[Cluster]FailoverCluster"
            Number = 3
            Ensure = "Present"
            Label = "SQL-LOG"
        }

        PendingReboot RebootBeforeSQLInstall {
           DependsOn = "[Script]UninstallSql", "[ClusterDisk]AddClusterDataDisk", "[ClusterDisk]AddClusterLogDisk"
           Name = "RebootBeforeSQLInstall" 
        }

        SqlSetup InstallSql {
            DependsOn = "[xADUser]CreateSqlServerServiceAccount", "[PendingReboot]RebootBeforeSQLInstall"
            Action = "InstallFailoverCluster"
            SkipRule = "Cluster_VerifyForErrors"
            ForceReboot = $false
            UpdateEnabled = "False"
            SourcePath = $SqlSetupFolder
            InstanceName = "MSSQLSERVER"
            Features = "SQLEngine"
            InstallSharedDir = 'C:\Program Files\Microsoft SQL Server'
            InstallSharedWOWDir = 'C:\Program Files (x86)\Microsoft SQL Server'
            InstanceDir = 'C:\Program Files\Microsoft SQL Server'
            SQLCollation  = 'SQL_Latin1_General_CP1_CI_AS'
            SQLSvcAccount = $SQLCreds
            AgtSvcAccount = $SQLCreds
            SQLSysAdminAccounts = $SQLCreds.UserName
            InstallSQLDataDir = "F:\MSSQL\Data"
            SQLUserDBDir = "F:\MSSQL\Data"
            SQLUserDBLogDir = "G:\MSSQL\Log"
            SQLTempDBDir = "F:\MSSQL\Temp"
            SQLTempDBLogDir = "F:\MSSQL\Temp"
            SQLBackupDir = "F:\MSSQL\Backup"
            FailoverClusterNetworkName = $SqlClusterName
            FailoverClusterIPAddress = $SqlClusterIPAddress
            PsDscRunAsCredential = $DomainCreds
        }

        SqlLogin AddDomainAdminSqlLogin {
            DependsOn = "[SqlSetup]InstallSql"
            Ensure = "Present"
            Name = $DomainCreds.UserName
            LoginType = "WindowsUser"
            ServerName = $SqlClusterName
            InstanceName = "MSSQLSERVER"
        }

        SqlLogin AddSqlServerServiceSqlLogin {
            DependsOn = "[SqlSetup]InstallSql", "[xADUser]CreateSqlServerServiceAccount"
            Name = $SQLCreds.UserName
            LoginType = "WindowsUser"
            ServerName = $SqlClusterName
            InstanceName = "MSSQLSERVER"
        }
        
        SqlRole AddSysadminMembers {
            DependsOn = "[SqlLogin]AddDomainAdminSqlLogin", "[SqlLogin]AddSqlServerServiceSqlLogin"
            Ensure = "Present"
            ServerRoleName = "sysadmin"
            ServerName = $SqlClusterName
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
