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

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $Admincreds,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $SQLServiceCreds,

        [System.Management.Automation.PSCredential]
        $SQLAuthCreds,

        [Parameter(Mandatory)]
        [String]
        $ClusterName,

        [Parameter(Mandatory)]
        [String]
        $SharePath,

        [Parameter(Mandatory)]
        [String[]]
        $Nodes,

        [Parameter(Mandatory)]
        [String]
        $SqlAlwaysOnAvailabilityGroupName,

        [Parameter(Mandatory)]
        [String]
        $SqlAlwaysOnAvailabilityGroupListenerName,

        [UInt32]
        $SqlAlwaysOnAvailabilityGroupListenerPort = 1433,

        [Parameter(Mandatory)]
        [String]
        $LBName,

        [Parameter(Mandatory)]
        [String]
        $LBAddress,

        [Parameter(Mandatory)]
        [String]
        $PrimaryReplica,

        [Parameter(Mandatory)]
        [String]
        $SecondaryReplica,

        [Parameter(Mandatory)]
        [String]
        $SqlAlwaysOnEndpointName,

        [String]
        $DNSServerName = 'dc-pdc',

        [UInt32]
        $DatabaseEnginePort = 1433,

        [String]
        $DomainNetbiosName = (Get-NetBIOSName -DomainName $DomainName),

        [String[]]
        $DatabaseNames,

        [Int]
        $RetryCount = 20,

        [Int]
        $RetryIntervalSec = 30
    )

    Import-DscResource -ModuleName ComputerManagementDsc
    Import-DscResource -ModuleName FailOverClusterDsc
    Import-DscResource -ModuleName StorageDsc
    Import-DscResource -ModuleName ActiveDirectoryDsc
    #Import-DscResource -ModuleName xDisk
    #Import-DscResource -ModuleName xSqlPs
    Import-DscResource -ModuleName NetworkingDsc
    #Import-DscResource -ModuleName xSql
    Import-DscResource -ModuleName SQLServerDsc
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$DomainFQDNCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
    [System.Management.Automation.PSCredential]$SQLCreds = New-Object System.Management.Automation.PSCredential ("${DomainNetbiosName}\$($SQLServiceCreds.UserName)", $SQLServiceCreds.Password)
    [string]$LBFQName="${LBName}.${DomainName}"

    Enable-CredSSPNTLM -DomainName $DomainName

    WaitForSqlSetup

    Node localhost
    {

        WaitforDisk Disk2
        {
            DiskId = "2"
             RetryIntervalSec =20
             RetryCount = 30
        }

        Disk DataDisk {
            DiskId = "2"
            DriveLetter = "F"
            DependsOn = "[WaitForDisk]Disk2"
        }

        WaitforDisk Disk3
        {
            DiskId = "3"
             RetryIntervalSec =20
             RetryCount = 30
        }

        Disk DataDisk {
            DiskId = "3"
            DriveLetter = "G"
            DependsOn = "[WaitForDisk]Disk3"
        }

        WindowsFeature FC
        {
            Name = "Failover-Clustering"
            Ensure = "Present"
        }

		WindowsFeature FailoverClusterTools 
        { 
            Ensure = "Present" 
            Name = "RSAT-Clustering-Mgmt"
			DependsOn = "[WindowsFeature]FC"
        } 

        WindowsFeature FCPS
        {
            Name = "RSAT-Clustering-PowerShell"
            Ensure = "Present"
        }

        WindowsFeature ADPS
        {
            Name = "RSAT-AD-PowerShell"
            Ensure = "Present"
        }

        WaitForADDomain DscForestWait 
        { 
            DomainName = $DomainName 
            Credential= $DomainCreds
	        DependsOn = "[WindowsFeature]ADPS"
        }
        
        Computer DomainJoin
        {
            Name = $env:COMPUTERNAME
            DomainName = $DomainName
            Credential = $DomainCreds
	        DependsOn = "[WaitForADDomain]DscForestWait"
        }

        Firewall DatabaseEngineFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Engine-TCP-In"
            DisplayName = "SQL Server Database Engine (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Engine."
            Protocol = "TCP"
            LocalPort = $DatabaseEnginePort -as [String]
            Ensure = "Present"
        }

        Firewall DatabaseMirroringFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Database-Mirroring-TCP-In"
            DisplayName = "SQL Server Database Mirroring (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Database Mirroring."
            Protocol = "TCP"
            LocalPort = "5022"
            Ensure = "Present"
        }

        Firewall ListenerFirewallRule
        {
            Direction = "Inbound"
            Name = "SQL-Server-Availability-Group-Listener-TCP-In"
            DisplayName = "SQL Server Availability Group Listener (TCP-In)"
            Description = "Inbound rule for SQL Server to allow TCP traffic for the Availability Group listener."
            Protocol = "TCP"
            LocalPort = "59999"
            Ensure = "Present"
        }

        SqlLogin AddDomainAdminAccountToSysadminServerRole
        {
            Name = $DomainCreds.UserName
            LoginType = "WindowsUser"
            InstanceName = "MSSQLSERVER"
            ServerRoleName = "sysadmin"
            PsDscRunAsCredential = $Admincreds
        }

        ADUser CreateSqlServerServiceAccount
        {
            PsDscRunAsCredential = $DomainCreds
            DomainName = $DomainName
            UserName = $SQLServicecreds.UserName
            Password = $SQLServicecreds
            Ensure = "Present"
            DependsOn = "[SqlLogin]AddDomainAdminAccountToSysadminServerRole"
        }

        SqlLogin AddSqlServerServiceAccountToSysadminServerRole
        {
            Name = $SQLCreds.UserName
            LoginType = "WindowsUser"
            InstanceName = "MSSQLSERVER"
            ServerRoleName = "sysadmin"
            PsDscRunAsCredential = $Admincreds
            DependsOn = "[ADUser]CreateSqlServerServiceAccount"
        }
        
        SqlEndpoint AddSqlServerEndpoint
        {
            EndpointName = $SqlAlwaysOnEndpointName
            EndpointType = "DatabaseMirroring"
            InstanceName = "MSSQLSERVER"
            Port = $DatabaseEnginePort
            PsDscRunAsCredential = $Admincreds
            DependsOn = "[SqlLogin]AddSqlServerServiceAccountToSysadminServerRole"
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }

        Cluster FailoverCluster
        {
            Name = $ClusterName
            DomainAdministratorCredential = $DomainCreds
            StaticIPAddress = "10.0.1.0/26"
        }

        WaitForFileShareWitness WaitForFSW
        {
            SharePath = $SharePath
            DomainAdministratorCredential = $DomainCreds

        }

        ClusterQuorum FailoverClusterQuorum
        {
            IsSingleInstance = "Yes"
            Type = "NodeAndFileShareMajority"
            Resource = $SharePath
            PsDscRunAsCredential = $DomainCredsc;
        }

        SqlAlwaysOnService ConfigureSqlServerWithAlwaysOn
        {
            Ensure = "Present"
            InstanceName = $env:COMPUTERNAME
            PsDscRunAsCredential  = $DomainFQDNCreds
            RestartTimeout       = 120
            DependsOn = "[Cluster]FailoverCluster"
        }

        SQLAddListenerIPToDNS AddLoadBalancer
        {
            LBName = $LBName
            Credential = $DomainCreds
            LBAddress = $LBAddress
            DNSServerName = $DNSServerName
            DomainName = $DomainName
            DependsOn = "[SqlServer]ConfigureSqlServerWithAlwaysOn"
        }

        SqlEndpoint SqlAlwaysOnEndpoint
        {
            EndpointName = $SqlAlwaysOnEndpointName
            EndpointType = "DatabaseMirroring"
            InstanceName = $env:COMPUTERNAME
            Port = 5022
            Owner = $SQLServiceCreds.UserName
            PsDscRunAsCredential  = $SQLCreds
            DependsOn = "[SqlServer]ConfigureSqlServerWithAlwaysOn"
        }

        SqlAlwaysOnService ConfigureSqlServerSecondaryWithAlwaysOn
        {
            InstanceName = $SecondaryReplica
            PsDscRunAsCredential  = $DomainFQDNCreds
            RestartTimeout       = 120
            DependsOn = "[Cluster]FailoverCluster"
        }

        SqlEndpoint SqlSecondaryAlwaysOnEndpoint
        {
            InstanceName = $SecondaryReplica
            EndpointName = $SqlAlwaysOnEndpointName
            EndpointType = "DatabaseMirroring"
            Port = 5022
            Owner = $SQLServiceCreds.UserName
            PsDscRunAsCredential = $SQLCreds
	    DependsOn="[SqlServer]ConfigureSqlServerSecondaryWithAlwaysOn"
        }
        
        SqlAvailabilityGroup SqlAG
        {
            Name = $SqlAlwaysOnAvailabilityGroupName
            EndpointType = "DatabaseMirroring"
            ClusterName = $ClusterName
            InstanceName = $env:COMPUTERNAME
            PortNumber = 5022
            DomainCredential =$DomainCreds
            SqlAdministratorCredential = $Admincreds
	        DependsOn="[SqlEndpoint]SqlSecondaryAlwaysOnEndpoint"
        }
           
        SqlAvailabilityGroupListener SqlAGListener
        {
            Name = $SqlAlwaysOnAvailabilityGroupListenerName
            AvailabilityGroupName = $SqlAlwaysOnAvailabilityGroupName
            DomainNameFqdn = $LBFQName
            ListenerPortNumber = $SqlAlwaysOnAvailabilityGroupListenerPort
            ListenerIPAddress = $LBAddress
            ProbePortNumber = 59999
            InstanceName = $env:COMPUTERNAME
            DomainCredential = $DomainCreds
            SqlAdministratorCredential = $Admincreds
            DependsOn = "[SqlAvailabilityGroup]SqlAG"
        }

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $true
        }

    }

}

function Update-DNS
{
    param(
        [string]$LBName,
        [string]$LBAddress,
        [string]$DomainName

        )
               
        $ARecord=Get-DnsServerResourceRecord -Name $LBName -ZoneName $DomainName -ErrorAction SilentlyContinue -RRType A
        if (-not $Arecord)
        {
            Add-DnsServerResourceRecordA -Name $LBName -ZoneName $DomainName -IPv4Address $LBAddress
        }
}

function WaitForSqlSetup
{
    # Wait for SQL Server Setup to finish before proceeding.
    while ($true)
    {
        try
        {
            Get-ScheduledTaskInfo "\ConfigureSqlImageTasks\RunConfigureImage" -ErrorAction Stop
            Start-Sleep -Seconds 5
        }
        catch
        {
            break
        }
    }
}

function Get-NetBIOSName
{ 
    [OutputType([string])]
    param(
        [string]$DomainName
    )

    if ($DomainName.Contains('.')) {
        $length=$DomainName.IndexOf('.')
        if ( $length -ge 16) {
            $length=15
        }
        return $DomainName.Substring(0,$length)
    }
    else {
        if ($DomainName.Length -gt 15) {
            return $DomainName.Substring(0,15)
        }
        else {
            return $DomainName
        }
    }
}

function Enable-CredSSPNTLM
{ 
    param(
        [Parameter(Mandatory=$true)]
        [string]$DomainName
    )
    
    # This is needed for the case where NTLM authentication is used

    Write-Verbose 'STARTED:Setting up CredSSP for NTLM'
   
    Enable-WSManCredSSP -Role client -DelegateComputer localhost, *.$DomainName -Force -ErrorAction SilentlyContinue
    Enable-WSManCredSSP -Role server -Force -ErrorAction SilentlyContinue

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows -Name '\CredentialsDelegation' -ErrorAction SilentlyContinue
    }

    if( -not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'ConcatenateDefaults_AllowFreshNTLMOnly' -value '1' -PropertyType dword -ErrorAction SilentlyContinue
    }

    if(-not (Test-Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -ErrorAction SilentlyContinue))
    {
        New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation -Name 'AllowFreshCredentialsWhenNTLMOnly' -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '1' -value "wsman/$env:COMPUTERNAME" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '2' -value "wsman/localhost" -PropertyType string -ErrorAction SilentlyContinue
    }

    if (-not (Get-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -ErrorAction SilentlyContinue))
    {
        New-ItemProperty HKLM:\SOFTWARE\Policies\Microsoft\Windows\CredentialsDelegation\AllowFreshCredentialsWhenNTLMOnly -Name '3' -value "wsman/*.$DomainName" -PropertyType string -ErrorAction SilentlyContinue
    }

    Write-Verbose "DONE:Setting up CredSSP for NTLM"
}

