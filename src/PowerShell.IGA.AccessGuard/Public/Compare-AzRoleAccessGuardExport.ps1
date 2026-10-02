function Compare-AzRoleAccessGuardExport {
    <#
    .SYNOPSIS
        Compares a full role assignment export against a baseline export file and reports the differences, without querying Azure.
    #>
    [CmdletBinding()]
    param(
        # Full export file (e.g. produced by Export-AzRoleAccessGuard -IncludeInherited) treated as the current/actual state.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FullExportFile,

        # Baseline export file (e.g. produced by Export-AzRoleAccessGuard) treated as the reference/desired state.
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ExportFile,

        # Where the detected differences are written, without extension; the correct extension is appended based on -OutputFormat.
        [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'output_export_diff'),

        # Output format for the comparison report. 'Terminal' prints a table to the host instead of writing a file. Defaults to Json.
        [ValidateSet('Terminal', 'Json', 'Html', 'Csv', 'JUnit')]
        [string]$OutputFormat = 'Json'
    )

    if (-not (Test-Path -LiteralPath $FullExportFile -PathType Leaf)) {
        throw "Full export file '$FullExportFile' was not found."
    }

    if (-not (Test-Path -LiteralPath $ExportFile -PathType Leaf)) {
        throw "Export file '$ExportFile' was not found."
    }

    $full_export = Get-Content -LiteralPath $FullExportFile -Raw | ConvertFrom-Json
    $full_export = ConvertFrom-RoleAssignmentExportDocument -ExportData $full_export

    $export = Get-Content -LiteralPath $ExportFile -Raw | ConvertFrom-Json
    $export = ConvertFrom-RoleAssignmentExportDocument -ExportData $export

    $drift_result = [ordered]@{
        ManagementGroup = [ordered]@{}
        Subscription    = [ordered]@{}
    }

    $scope_test_results = @()

    foreach ($section in 'ManagementGroup', 'Subscription') {

        $current_section = $full_export.$section
        $reference_section = $export.$section

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
        Subscription    = [PSCustomObject]$drift_result.Subscription
    }

    $drift_documents = ConvertTo-RoleAssignmentDriftDocuments -DriftResult $drift_result -Description 'Role assignment drift detected between the full export and the export file.'

    switch ($OutputFormat) {
        'Terminal' {
            New-FlatDriftResultList -DriftResult $drift_result | Format-Table -AutoSize
        }
        'Json' {
            $drift_documents | ConvertTo-Json -Depth 6 | Out-File -FilePath "$OutputPath.json" -Encoding utf8
            Write-Host "Comparison report written to $OutputPath.json"
        }
        'Html' {
            ConvertTo-DriftGroupedHtmlReport -Title 'Azure Role Assignment Export Comparison' -DriftResult $drift_result -GeneratedBy 'Compare-AzRoleAccessGuardExport' | Out-File -FilePath "$OutputPath.html" -Encoding utf8
            Write-Host "Comparison report written to $OutputPath.html"
        }
        'Csv' {
            New-FlatDriftResultList -DriftResult $drift_result | Export-Csv -Path "$OutputPath.csv" -NoTypeInformation -Encoding utf8
            Write-Host "Comparison report written to $OutputPath.csv"
        }
        'JUnit' {
            ConvertTo-DriftJUnitXml -ScopeResults $scope_test_results -SuiteName 'AzRoleAssignmentExportComparison' | Out-File -FilePath "$OutputPath.xml" -Encoding utf8
            Write-Host "Comparison report written to $OutputPath.xml"
        }
    }

    $total_changes = ($drift_result.ManagementGroup.Values + $drift_result.Subscription.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "Comparison complete. $total_changes change(s) found between full export and export."

    return $drift_output

}
