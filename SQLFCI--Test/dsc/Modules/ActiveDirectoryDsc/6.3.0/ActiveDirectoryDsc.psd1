@{
# Version number of this module.
moduleVersion = '6.3.0'

# ID used to uniquely identify this module
GUID = '9FECD4F6-8F02-4707-99B3-539E940E9FF5'

# Author of this module
Author = 'DSC Community'

# Company or vendor of this module
CompanyName = 'DSC Community'

# Copyright statement for this module
Copyright = 'Copyright the DSC Community contributors. All rights reserved.'

# Description of the functionality provided by this module
Description = 'The ActiveDirectoryDsc module contains DSC resources for deployment and configuration of Active Directory.

These DSC resources allow you to configure new domains, child domains, and high availability domain controllers, establish cross-domain trusts and manage users, groups and OUs.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Nested modules to load when this module is imported.
NestedModules = 'Modules\ActiveDirectoryDsc.Common\ActiveDirectoryDsc.Common.psm1'

# Functions to export from this module
FunctionsToExport = @(
  # Exported so that WaitForADDomain can use this function in a separate scope.
  'Find-DomainController'
)

# Cmdlets to export from this module
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module
AliasesToExport = @()

# Dsc Resources to export from this module
DscResourcesToExport = @('ADComputer','ADDomain','ADDomainController','ADDomainControllerProperties','ADDomainDefaultPasswordPolicy','ADDomainFunctionalLevel','ADDomainTrust','ADFineGrainedPasswordPolicy','ADForestFunctionalLevel','ADForestProperties','ADGroup','ADKDSKey','ADManagedServiceAccount','ADObjectEnabledState','ADObjectPermissionEntry','ADOptionalFeature','ADOrganizationalUnit','ADReplicationSite','ADReplicationSiteLink','ADServicePrincipalName','ADUser','WaitForADDomain','ADReplicationSubnet')

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('DesiredStateConfiguration', 'DSC', 'DSCResourceKit', 'DSCResource')

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/dsccommunity/ActiveDirectoryDsc/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/dsccommunity/ActiveDirectoryDsc'

        # A URL to an icon representing this module.
        IconUri = 'https://dsccommunity.org/images/DSC_Logo_300p.png'

        # ReleaseNotes of this module
        ReleaseNotes = '## [6.3.0] - 2023-08-24

### Removed

- ActiveDirectoryDsc
  - There was a ''build.ps1'' file under the source folder than are no longer
    required for ModuleBuilder to work.

### Changed

- ActiveDirectoryDsc
  - Move CI/CD build step to using build worker image `windows-latest`.
- ActiveDirectoryDsc.Common
  - Created Get-DomainObject to wrap Get-ADDomain with common retry logic.
- ADDomainController
  - Refactored to use Get-DomainObject ([issue #673](https://github.com/dsccommunity/ActiveDirectoryDsc/issues/673)).
  - Refactored Unit Tests.
- ADDomain
  - Refactored to use Get-DomainObject.
  - Refactored Unit Tests.
- ADOrganizationalUnit
  - Added DomainController Parameter.

### Fixed

- ADReplicationSiteLink
  - Allow OptionChangeNotification, OptionTwoWaySync and OptionDisableCompression to be updated even if
    ReplicationFrequencyInMinutes is not set ([issue #637](https://github.com/dsccommunity/ActiveDirectoryDsc/issues/637)).

'

        # Set to a prerelease string value if the release should be a prerelease.
        Prerelease = ''

      } # End of PSData hashtable

} # End of PrivateData hashtable
}
