# Normalizes a parsed export (document-style array or already-grouped object) into the ManagementGroup/Subscription assignment shape
function ConvertFrom-RoleAssignmentExportDocument {
    <#
    .SYNOPSIS
        Normalizes a parsed role assignment export (document-style or grouped) into a ManagementGroup/Subscription assignment object.
    #>
    [CmdletBinding()]
    param(
        # Result of ConvertFrom-Json on an exported role assignment file.
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$ExportData
    )

    if ($null -eq $ExportData -or $ExportData -isnot [System.Array] -and $ExportData.PSObject.Properties.Name -notcontains 'resources') {
        return [PSCustomObject]@{
            ManagementGroup = if ($ExportData.ManagementGroup) { $ExportData.ManagementGroup } else { [PSCustomObject]@{} }
            Subscription    = if ($ExportData.Subscription) { $ExportData.Subscription } else { [PSCustomObject]@{} }
        }
    }

    $normalized = [ordered]@{
        ManagementGroup = [ordered]@{}
        Subscription    = [ordered]@{}
    }

    foreach ($document in @($ExportData)) {
        $section = switch ($document.displayName) {
            'ManagementGroups' { 'ManagementGroup'; break }
            'Subscriptions' { 'Subscription'; break }
            default { continue }
        }

        foreach ($resource in @($document.resources)) {
            $properties = $resource.properties
            if (-not $properties -or -not $properties.ScopeId -or -not $properties.ObjectId -or -not $properties.RoleDefinitionName) {
                Write-Warning "Skipping invalid role assignment in document '$($document.displayName)'."
                continue
            }

            $scope_id = [string]$properties.ScopeId
            $assignment_scope = if ($scope_id.StartsWith('/')) {
                $scope_id
            }
            elseif ($section -eq 'Subscription') {
                "/subscriptions/$scope_id"
            }
            else {
                "/providers/Microsoft.Management/managementGroups/$scope_id"
            }

            if (-not $normalized[$section].Contains($scope_id)) {
                $normalized[$section][$scope_id] = @()
            }

            $normalized[$section][$scope_id] = @($normalized[$section][$scope_id]) + [PSCustomObject]@{
                Scope              = $assignment_scope
                Inherited          = $properties.Inherited
                InheritedFrom      = $properties.InheritedFrom
                DisplayName        = $properties.DisplayName
                SignInName         = $properties.SignInName
                ObjectId           = $properties.ObjectId
                ObjectType         = $resource.resourceType
                RoleDefinitionName = $properties.RoleDefinitionName
                Ensure             = if ($properties.Ensure) { $properties.Ensure } else { 'Present' }
            }
        }
    }

    return [PSCustomObject]@{
        ManagementGroup = [PSCustomObject]$normalized.ManagementGroup
        Subscription    = [PSCustomObject]$normalized.Subscription
    }
}
