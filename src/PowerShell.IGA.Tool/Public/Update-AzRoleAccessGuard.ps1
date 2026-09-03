function Update-AzRoleAccessGuard {
    <#
    .SYNOPSIS
        Reconciles Azure role assignments using a drift report.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        # Drift report produced by Invoke-AzRoleAccessGuardDrifft.
        [ValidateNotNullOrEmpty()]
        [string]$DriftFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'output_diff.json')
    )

    if (-not (Test-Path -LiteralPath $DriftFile -PathType Leaf)) {
        throw "Drift report '$DriftFile' was not found."
    }

    try {
        $drift_report = Get-Content -LiteralPath $DriftFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Unable to read drift report '$DriftFile': $($_.Exception.Message)"
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
                $action = switch ($entry.Status) {
                    'Added' { 'Remove role assignment'; break }
                    'Removed' { 'Restore role assignment'; break }
                    default {
                        Write-Warning "Skipping '$target' because status '$($entry.Status)' is not supported."
                        continue
                    }
                }

                if ($PSCmdlet.ShouldProcess($target, $action)) {
                    if ($entry.Status -eq 'Added') {
                        Remove-AzRoleAssignment -ObjectId $assignment.ObjectId -Scope $assignment.Scope -RoleDefinitionName $assignment.RoleDefinitionName -ErrorAction Stop
                    }
                    else {
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