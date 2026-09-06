# Loads 'MyFunctions.ps1' from the same folder as the current script
# . "D:\Git\PowerShell.IGA.Tool\src\PowerShell.IGA.Tool\Private\MyTesFunction.ps1"

# Get-WelcomeMessage -Name "Alice"

# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

#Requires –Modules Az

function Invoke-AzRoleAccessGuardDrifft {
    <#
    .SYNOPSIS
        Compares the current Azure role assignments against a previously exported reference file and reports drift.
    #>
    [CmdletBinding()]
    param(
        # Previously exported role assignment file (e.g. produced by Export-AzRoleAssignment) to compare against
        [string]$ReferenceFile,

        # Where the detected differences are written, without extension; the correct extension is appended based on -OutputFormat.
        [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'output_diff'),

        # Output format for the drift report. 'Terminal' prints a table to the host instead of writing a file. Defaults to Json.
        [ValidateSet('Terminal', 'Json', 'Html', 'Csv', 'JUnit')]
        [string]$OutputFormat = 'Json'
    )

    $report = Get-AzRoleAssignmentReport
    $role_assigment_data_subscriptions = $report.Subscriptions
    $role_assigment_data_management_groups = $report.ManagementGroups

    $role_assigment_export = [PSCustomObject]@{
        ManagementGroup = [PSCustomObject]$role_assigment_data_management_groups
        Subscription = [PSCustomObject]$role_assigment_data_subscriptions
    }

    if (-not (Test-Path -Path $ReferenceFile)) {
        Write-Warning "Reference file '$ReferenceFile' not found. Skipping drift comparison."
        return $role_assigment_export
    }

    $reference_export = Get-Content -Path $ReferenceFile -Raw | ConvertFrom-Json

    # Convert document-style exports into the grouped assignment shape used by the comparison engine.
    if ($reference_export -is [System.Array] -or $reference_export.PSObject.Properties.Name -contains 'resources') {
        $normalized_reference = [ordered]@{
            ManagementGroup = [ordered]@{}
            Subscription = [ordered]@{}
        }

        foreach ($document in @($reference_export)) {
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

                if (-not $normalized_reference[$section].Contains($scope_id)) {
                    $normalized_reference[$section][$scope_id] = @()
                }

                $normalized_reference[$section][$scope_id] = @($normalized_reference[$section][$scope_id]) + [PSCustomObject]@{
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

        $reference_export = [PSCustomObject]@{
            ManagementGroup = [PSCustomObject]$normalized_reference.ManagementGroup
            Subscription    = [PSCustomObject]$normalized_reference.Subscription
        }
    }

    $drift_result = [ordered]@{
        ManagementGroup = [ordered]@{}
        Subscription = [ordered]@{}
    }

    $scope_test_results = @()

    foreach ($section in 'ManagementGroup', 'Subscription') {

        $current_section = $role_assigment_export.$section
        $reference_section = $reference_export.$section

        $current_ids = @()
        if ($current_section) { $current_ids = @($current_section.PSObject.Properties.Name) }

        $reference_ids = @()
        if ($reference_section) { $reference_ids = @($reference_section.PSObject.Properties.Name) }

        $all_ids = @($current_ids + $reference_ids) | Select-Object -Unique

        foreach ($id in $all_ids) {

            $current_assignments = @()
            if ($current_ids -contains $id) { $current_assignments = @($current_section.$id) }

            $reference_assignments = @()
            if ($reference_ids -contains $id) { $reference_assignments = @($reference_section.$id) }

            $id_diff = Compare-AzRoleAssignmentSet -ReferenceAssignments $reference_assignments -CurrentAssignments $current_assignments

            $scope_test_results += [PSCustomObject]@{
                Section = $section
                ScopeId = $id
                Diff    = $id_diff
            }

            if ($id_diff.Count -gt 0) {
                $drift_result[$section][$id] = $id_diff
            }
        }
    }

    $drift_output = [PSCustomObject]@{
        ManagementGroup = [PSCustomObject]$drift_result.ManagementGroup
        Subscription = [PSCustomObject]$drift_result.Subscription
    }

    $drift_documents = @()
    foreach ($section in 'ManagementGroup', 'Subscription') {
        $resources = @()
        foreach ($scope_id in $drift_result[$section].Keys) {
            foreach ($entry in $drift_result[$section][$scope_id]) {
                $assignment = $entry.Assignment
                $resources += [PSCustomObject]@{
                    displayName  = "AzRole-$($assignment.DisplayName)"
                    resourceType = $assignment.ObjectType
                    properties   = [PSCustomObject]@{
                        SignInName         = $assignment.SignInName
                        ObjectId           = $assignment.ObjectId
                        RoleDefinitionName = $assignment.RoleDefinitionName
                        Ensure             = if ($entry.Status -eq 'Removed') { 'Present' } else { 'Absent' }
                        DisplayName        = $assignment.DisplayName
                        Scope              = $section
                        ScopeId            = $scope_id
                        Inherited          = $assignment.Inherited
                        InheritedFrom      = $assignment.InheritedFrom
                        Status             = $entry.Status
                        SuggestedAction    = $entry.SuggestedAction
                    }
                }
            }
        }

        $drift_documents += [PSCustomObject]@{
            displayName = if ($section -eq 'ManagementGroup') { 'ManagementGroups' } else { 'Subscriptions' }
            description = 'Role assignment drift detected against the reference export.'
            resources   = $resources
        }
    }

    switch ($OutputFormat) {
        'Terminal' {
            New-FlatDriftResultList -DriftResult $drift_result | Format-Table -AutoSize
        }
        'Json' {
            $drift_documents | ConvertTo-Json -Depth 6 | Out-File -FilePath "$OutputPath.json" -Encoding utf8
                Write-Host "Drift report written to $OutputPath.json"
        }
        'Html' {
            ConvertTo-DriftGroupedHtmlReport -Title 'Azure Role Assignment Drift Report' -DriftResult $drift_result -ManagementGroupNames $report.ManagementGroupNames -SubscriptionNames $report.SubscriptionNames -GeneratedBy 'Test-AzRoleAssignment' | Out-File -FilePath "$OutputPath.html" -Encoding utf8
            Write-Host "Drift report written to $OutputPath.html"
        }
        'Csv' {
            New-FlatDriftResultList -DriftResult $drift_result | Export-Csv -Path "$OutputPath.csv" -NoTypeInformation -Encoding utf8
            Write-Host "Drift report written to $OutputPath.csv"
        }
        'JUnit' {
            ConvertTo-DriftJUnitXml -ScopeResults $scope_test_results | Out-File -FilePath "$OutputPath.xml" -Encoding utf8
            Write-Host "Drift report written to $OutputPath.xml"
        }
    }

    $total_changes = ($drift_result.ManagementGroup.Values + $drift_result.Subscription.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "Drift detection complete. $total_changes change(s) found."

    return $drift_output

}

