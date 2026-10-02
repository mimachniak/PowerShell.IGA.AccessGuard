# PowerShell.IGA.AccessGuard.psm1
# PowerShell module for exporting and governing Azure RBAC role assignments
# Author: Michal Machniak
# Version: 1.0.0

# Ensure module imports functions dynamically
$PublicFunctions = Get-ChildItem -Path $PSScriptRoot\public\*.ps1 -ErrorAction SilentlyContinue
$PrivateFunctions = Get-ChildItem -Path $PSScriptRoot\private\*.ps1 -ErrorAction SilentlyContinue

foreach ($Function in @($PublicFunctions)) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Error "Failed to import function from $($Function.FullName): $_"
    }
}

foreach ($Function in @($PrivateFunctions)) {
    try {
        . $Function.FullName
    }
    catch {
        Write-Error "Failed to import function from $($Function.FullName): $_"
    }
}

# Export only public functions
if ($PublicFunctions) {
    Export-ModuleMember -Function $($PublicFunctions.BaseName)
}
