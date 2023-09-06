#
# Copyright="� Microsoft Corporation. All rights reserved."
#

configuration CreateFailoverCluster
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

        [Parameter(Mandatory)]
        [String]
        $ClusterName,

        [Parameter(Mandatory)]
        [String]
        $SharePath,

        [UInt32]
        $DatabaseEnginePort = 1433,

        [Int]
        $RetryCount = 20,

        [Int]
        $RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName ActiveDirectoryDsc -ModuleVersion "6.0.1"
    Import-DscResource -ModuleName ComputerManagementDsc -ModuleVersion "8.5.0"
    Import-DscResource -ModuleName FailoverClusterDsc -ModuleVersion "2.1.0"
    Import-DscResource -ModuleName NetworkingDsc -ModuleVersion "8.2.0"
    Import-DscResource -ModuleName SqlServerDsc -ModuleVersion "16.0.0"
    Import-DscResource -ModuleName StorageDsc -ModuleVersion "5.0.1"

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
        }

        ADUser CreateSqlServerServiceAccount {
            DependsOn = "[SqlRole]AddDomainAdminSqlLoginToSysadminServerRole"
            Ensure = "Present"
            DomainName = $DomainName
            UserName = $SqlServiceCredential.UserName
            Password = $SqlServiceCredential
            PsDscRunAsCredential = $DomainCreds
        }

        SqlLogin AddSqlServerServiceLogin {
            DependsOn = "[ADUser]CreateSqlServerServiceAccount"
            Name = $SQLCreds.UserName
            LoginType = "WindowsUser"
            InstanceName = "MSSQLSERVER"
        }
        
        SqlRole AddSysadminMembers {
            DependsOn = "[SqlLogin]AddSqlServerServiceLogin"
            Ensure = "Present"
            ServerRoleName = "sysadmin"
            InstanceName = "MSSQLSERVER"
            MembersToInclude = $SQLCreds.UserName, $DomainCreds.UserName
        }

        Cluster FailoverCluster
        {
            DependsOn = "[Computer]DomainJoin"
            Name = $ClusterName
            DomainAdministratorCredential = $DomainCreds
            StaticIPAddress = "10.0.1.0/26"
        }

        ClusterQuorum FailoverClusterQuorum
        {
            DependsOn = "[Cluster]FailoverCluster"
            IsSingleInstance = "Yes"
            Type = "NodeAndFileShareMajority"
            Resource = $SharePath
            PsDscRunAsCredential = $DomainCreds
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

