#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration AddSqlClusterNode
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
        $SqlClusterName,

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

    $SqlSetupFolder = "C:\SQLServerFull\"

    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($DomainAdminCredential.UserName)", $DomainAdminCredential.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SqlServiceCredential.UserName)", $SqlServiceCredential.Password)

    Enable-CredSSPNTLM -DomainName $DomainName

    WaitForSqlSetup

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

        WaitforDisk Disk3 {
            DiskId = "3"
            RetryIntervalSec = 20
            RetryCount = 30
        }

        Disk LogDisk {
            DiskId = "3"
            DriveLetter = "G"
            DependsOn = "[WaitForDisk]Disk3"
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
        
        Script "UninstallSql" {
            DependsOn = "[WindowsFeature]RSAT-AD-PowerShell", "[Computer]DomainJoin"
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

        Cluster JoinClusterNode
        {
            Name                          = $ClusterName
            DomainAdministratorCredential = $DomainCreds
            DependsOn                     = '[WaitForCluster]WaitForCluster'
        }

        # xCluster AddClusterNode
        # {
        #     DependsOn = "[Computer]DomainJoin"
        #     Name = $ClusterName
        #     DomainAdministratorCredential = $DomainCreds
        #     Nodes = $(hostname)
        # }

        ClusterDisk AddClusterDataDisk {
            DependsOn = "[xCluster]AddClusterNode"
            Number = 2
            Ensure = "Present"
            Label = "SQL-DATA"
        }

        ClusterDisk AddClusterLogDisk {
            DependsOn = "[xCluster]AddClusterNode"
            Number = 3
            Ensure = "Present"
            Label = "SQL-LOG"
        }

        PendingReboot RebootBeforeSQLInstall {
            DependsOn = "[Script]UninstallSql", "[ClusterDisk]AddClusterDataDisk", "[ClusterDisk]AddClusterLogDisk"
            Name = "RebootBeforeSQLInstall" 
         }
 
        SqlSetup InstallSql {
            DependsOn = "[PendingReboot]RebootBeforeSQLInstall"
            Action = "AddNode"
            SkipRule = "Cluster_VerifyForErrors"
            ForceReboot = $false
            UpdateEnabled = "False"
            SourcePath = $SqlSetupFolder
            InstanceName = "MSSQLSERVER"
            Features = "SQLEngine"
            SQLSvcAccount = $SQLCreds
            AgtSvcAccount = $SQLCreds
            SQLSysAdminAccounts = $SQLCreds.UserName
            FailoverClusterNetworkName = $SqlClusterName
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

        SqlLogin AddSqlServerServiceLogin {
            DependsOn = "[SqlSetup]InstallSql"
            Name = $SQLCreds.UserName
            LoginType = "WindowsUser"
            ServerName = $SqlClusterName
            InstanceName = "MSSQLSERVER"
        }
        
        SqlRole AddSysadminMembers {
            DependsOn = "[SqlLogin]AddDomainAdminSqlLogin", "[SqlLogin]AddSqlServerServiceLogin"
            Ensure = "Present"
            ServerRoleName = "sysadmin"
            MembersToInclude = $SQLCreds.UserName, $DomainCreds.UserName
            ServerName = $SqlClusterName
            InstanceName = "MSSQLSERVER"
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

function Enable-CredSSPNTLM { 
    param(
        [Parameter(Mandatory = $true)]
        [string]$DomainName
    )
    
    # This is needed for the case where NTLM authentication is used

    Write-Verbose 'STARTED:Setting up CredSSP for NTLM'
   
    Enable-WSManCredSSP -Role client -DelegateComputer localhost, *.$DomainName -Force -ErrorAction SilentlyContinue
    Enable-WSManCredSSP -Role server -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -ErrorAction SilentlyContinue)) {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name '\CredentialsDelegation' -ErrorAction SilentlyContinue
    }

    if ( -not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue)) {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -Value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -ErrorAction SilentlyContinue)) {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -Value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -ErrorAction SilentlyContinue)) {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -ErrorAction SilentlyContinue)) {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -Value "wsman/$env:COMPUTERNAME" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -ErrorAction SilentlyContinue)) {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -Value "wsman/localhost" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -ErrorAction SilentlyContinue)) {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -Value "wsman/*.$DomainName" -PropertyType string -ErrorAction SilentlyContinue
    }

    Write-Verbose "DONE:Setting up CredSSP for NTLM"
}