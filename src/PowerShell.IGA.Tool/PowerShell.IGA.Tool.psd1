@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'PowerShell.IGA.Tool.psm1'

    # required modules
    RequiredModules = @(
        @{ ModuleName = 'Az.Resources'; MinimumVersion = '15.2' }
        @{ ModuleName = 'Az.Accounts'; MinimumVersion = '15.2' }
    )

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = '51f9ab95-fd20-4078-8b8c-d77168ab0542'

    # Author of this module
    Author = 'Michal Machniak'

    # Company or vendor of this module
    CompanyName = 'Michal Machniak'

    # Copyright statement for this module
    Copyright = '(c) Michal Machniak. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'PowerShell module generates Azure resource names based on a predefined naming convention schema and resource-specific rules.It ensures that the generated names comply with Azure naming restrictions and best practices'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        'Export-AzRoleAssignment',
        'Remove-AzRoleOrphaned',
        'Invoke-AzRoleAssignmentDiffReport',
        'Merge-AzRoleAssignment',
        'Set-AzRoleAssignment'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @()

    # Public and private script files loaded by the module
    FileList = @()

    PrivateData      = @{
        PSData = @{
            # ExternalModuleDependencies = @('Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Utility')
            ProjectUri                 = 'https://github.com/mimachniak/AzureResources-NameGenerator'
            LicenseUri                 = 'https://github.com/mimachniak/AzureResources-NameGenerator/blob/main/LICENSE'
            IconUri = ''
            Tags                       = @('Azure', 'RBAC', 'Generator', 'Validation')

            # ReleaseNotes of this module
            ReleaseNotes = '
            v.1.0.0 - Initial release of PowerShell.IGA.Tool module.
            '

            # Prerelease string of this module
            Prerelease   = ''
        } # End of PSData hashtable
    } # End of PrivateData hashtable
} # End of module manifest hashtable