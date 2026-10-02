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
        [ValidateSet('Terminal', 'Json', 'Html', 'Csv', 'JUnit', 'Bicep')]
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
    $reference_export = ConvertFrom-RoleAssignmentExportDocument -ExportData $reference_export

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

    $drift_documents = ConvertTo-RoleAssignmentDriftDocuments -DriftResult $drift_result

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
        'Bicep' {
            $bicep_management_group_data = [ordered]@{}
            $bicep_subscription_data = [ordered]@{}
            $removal_count = 0

            foreach ($section in 'ManagementGroup', 'Subscription') {
                foreach ($scope_id in $drift_result[$section].Keys) {
                    $scope_changes = @($drift_result[$section][$scope_id])
                    $removal_count += @($scope_changes | Where-Object { $_.Status -eq 'Added' }).Count
                    $assignments_to_add = @($scope_changes | Where-Object { $_.Status -eq 'Removed' } | ForEach-Object { $_.Assignment })

                    if ($assignments_to_add.Count -gt 0) {
                        if ($section -eq 'ManagementGroup') {
                            $bicep_management_group_data[$scope_id] = $assignments_to_add
                        }
                        else {
                            $bicep_subscription_data[$scope_id] = $assignments_to_add
                        }
                    }
                }
            }

            $bicep_export = ConvertTo-RoleAssignmentBicep -SubscriptionData $bicep_subscription_data -ManagementGroupData $bicep_management_group_data
            $bicep_export | Out-File -FilePath "$OutputPath.bicep" -Encoding utf8
            Write-Host "Bicep drift deployment written to $OutputPath.bicep"
            if ($removal_count -gt 0) {
                Write-Warning "$removal_count added role assignment(s) require removal. The AVM Bicep modules only create assignments, so these changes are not included in the Bicep output."
            }
        }
    }

    $total_changes = ($drift_result.ManagementGroup.Values + $drift_result.Subscription.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "Drift detection complete. $total_changes change(s) found."

    return $drift_output

}

