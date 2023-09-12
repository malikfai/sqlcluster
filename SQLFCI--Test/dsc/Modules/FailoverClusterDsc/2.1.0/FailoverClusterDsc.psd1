@{
    moduleVersion        = '2.1.0'

    GUID                 = '026e7fd8-06dd-41bc-b373-59366ab18679'

    Author               = 'DSC Community'

    CompanyName          = 'DSC Community'

    Copyright            = 'Copyright the DSC Community contributors. All rights reserved.'

    Description          = 'Module containing DSC resources for deployment and configuration of Windows Server Failover Cluster.'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion    = '4.0'

    # Functions to export from this module
    FunctionsToExport    = @()

    # Cmdlets to export from this module
    CmdletsToExport      = @()

    # Variables to export from this module
    VariablesToExport    = @()

    # Aliases to export from this module
    AliasesToExport      = @()

    DscResourcesToExport = @('Cluster','ClusterDisk','ClusterIPAddress','ClusterNetwork','ClusterPreferredOwner','ClusterProperty','ClusterQuorum','WaitForCluster')

    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData          = @{
        PSData = @{
            # Set to a prerelease string value if the release should be a prerelease.
            Prerelease   = ''

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags         = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

            # A URL to the license for this module.
            LicenseUri   = 'https://github.com/dsccommunity/xFailOverCluster/blob/main/LICENSE'

            # A URL to the main website for this project.
            ProjectUri   = 'https://github.com/dsccommunity/xFailOverCluster'

            # A URL to an icon representing this module.
            IconUri      = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

            # ReleaseNotes of this module
            ReleaseNotes = '## [2.1.0] - 2022-06-19

### Added

- New Resource
  - ClusterIPAddress
    - Adds an IP address to the cluster. 

### Changed

- Cluster
  - New parameter KeepDownedNodesInCluster controls whether or not to evict
    nodes in a down state from the cluster.
- FailoverClusterDsc
  - Update pipeline files to the latest from the Sampler project.
  - Moved all documentation from the README.md to the GitHub repository Wiki.
    All the DSC resource''s schema MOF files was updated with descriptions from
    the README.md where they were more descriptive.
  - Update GitHub pull request template after documentation was moved.
- ClusterPreferredOwner
  - Minor fix to tests.

'
        } # End of PSData hashtable

    } # End of PrivateData hashtable
}
