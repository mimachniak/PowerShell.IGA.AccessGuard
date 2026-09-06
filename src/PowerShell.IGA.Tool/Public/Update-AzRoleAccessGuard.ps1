function Update-AzRoleAccessGuard {
    <#
    .SYNOPSIS
        Reconciles Azure role assignments using a drift report.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        # Drift report produced by Invoke-AzRoleAccessGuardDrifft.
        [ValidateNotNullOrEmpty()]
        [string]$DriftFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'output_diff.json'),

        # Suppress confirmation prompts for unattended remediation. -WhatIf remains supported.
        [switch]$Force
    )

    if ($Force) {
        $ConfirmPreference = 'None'
    }

    if (-not (Test-Path -LiteralPath $DriftFile -PathType Leaf)) {
        throw "Drift report '$DriftFile' was not found."
    }

    try {
        $drift_report = Get-Content -LiteralPath $DriftFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Unable to read drift report '$DriftFile': $($_.Exception.Message)"
    }

    if ($drift_report -is [System.Array] -or $drift_report.PSObject.Properties.Name -contains 'resources') {
        $normalized_report = [ordered]@{
            ManagementGroup = [ordered]@{}
            Subscription = [ordered]@{}
        }

        foreach ($document in @($drift_report)) {
            $section_name = switch ($document.displayName) {
                'ManagementGroups' { 'ManagementGroup'; break }
                'Subscriptions' { 'Subscription'; break }
                default { continue }
            }

            foreach ($resource in @($document.resources)) {
                $properties = $resource.properties
                if (-not $properties -or -not $properties.ScopeId -or -not $properties.Status) {
                    Write-Warning "Skipping invalid role assignment in document '$($document.displayName)'."
                    continue
                }

                $scope_id = [string]$properties.ScopeId
                if (-not $normalized_report[$section_name].Contains($scope_id)) {
                    $normalized_report[$section_name][$scope_id] = @()
                }

                $normalized_report[$section_name][$scope_id] = @($normalized_report[$section_name][$scope_id]) + [PSCustomObject]@{
                    Status          = $properties.Status
                    SuggestedAction = $properties.SuggestedAction
                    Ensure          = $properties.Ensure
                    Assignment      = [PSCustomObject]@{
                        Scope              = if ($section_name -eq 'Subscription' -and -not ([string]$properties.ScopeId).StartsWith('/')) { "/subscriptions/$($properties.ScopeId)" } else { $properties.ScopeId }
                        ObjectId           = $properties.ObjectId
                        RoleDefinitionName = $properties.RoleDefinitionName
                    }
                }
            }
        }

        $drift_report = [PSCustomObject]@{
            ManagementGroup = [PSCustomObject]$normalized_report.ManagementGroup
            Subscription    = [PSCustomObject]$normalized_report.Subscription
        }
    }

    $results = @()
    foreach ($section_name in 'ManagementGroup', 'Subscription') {
        $section = $drift_report.$section_name
        if (-not $section) { continue }

        foreach ($scope_property in $section.PSObject.Properties) {
            foreach ($entry in @($scope_property.Value)) {
                $assignment = $entry.Assignment
                if (-not $assignment -or -not $assignment.ObjectId -or -not $assignment.RoleDefinitionName -or -not $assignment.Scope) {
                    Write-Warning "Skipping invalid $section_name drift entry at '$($scope_property.Name)'."
                    continue
                }

                $target = "$($assignment.ObjectId) on $($assignment.Scope) ($($assignment.RoleDefinitionName))"
                $ensure = if ($entry.Ensure) { [string]$entry.Ensure } else {
                    switch ($entry.Status) {
                        'Added' { 'Absent'; break }
                        'Removed' { 'Present'; break }
                    }
                }

                $action = switch ($ensure) {
                    'Absent' { 'Remove role assignment'; break }
                    'Present' { 'Add role assignment'; break }
                    default {
                        Write-Warning "Skipping '$target' because Ensure '$ensure' is not supported."
                        continue
                    }
                }

                if ($PSCmdlet.ShouldProcess($target, $action)) {
                    if ($ensure -eq 'Absent') {
                        Remove-AzRoleAssignment -ObjectId $assignment.ObjectId -Scope $assignment.Scope -RoleDefinitionName $assignment.RoleDefinitionName -ErrorAction Stop
                    }
                    elseif ($ensure -eq 'Present') {
                        New-AzRoleAssignment -ObjectId $assignment.ObjectId -Scope $assignment.Scope -RoleDefinitionName $assignment.RoleDefinitionName -ErrorAction Stop
                    }
                }

                $results += [PSCustomObject]@{
                    Section = $section_name
                    ScopeId = $scope_property.Name
                    Status  = $entry.Status
                    Action  = $action
                    ObjectId = $assignment.ObjectId
                    RoleDefinitionName = $assignment.RoleDefinitionName
                    Scope = $assignment.Scope
                }
            }
        }
    }

    return $results
}