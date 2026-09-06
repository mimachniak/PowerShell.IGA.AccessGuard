# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

function Export-AzRoleAccessGuard {
    <#
    .SYNOPSIS
        Exports a snapshot of Azure role assignments for all Subscriptions and Management Groups.
    #>
    [CmdletBinding()]
    param(
        # Output format for the snapshot file. Defaults to Json.
        [ValidateSet('Json', 'Html', 'Csv')]
        [string]$OutputFormat = 'Json',

        # Output file path without extension; the correct extension is appended based on -OutputFormat. Defaults to the module root.
        [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "output"),

        # Only export role assignments for Subscriptions. Default exports both Subscriptions and Management Groups.
        [switch]$SubscriptionOnly,

        # Only export role assignments for Management Groups. Default exports both Subscriptions and Management Groups.
        [switch]$ManagementGroupOnly,

        # Include role assignments inherited from a parent scope. Default only exports assignments defined directly at scope.
        [switch]$IncludeInherited
    )

$report = Get-AzRoleAssignmentReport -SubscriptionOnly:$SubscriptionOnly -ManagementGroupOnly:$ManagementGroupOnly -IncludeInherited:$IncludeInherited
$role_assigment_data_subscriptions = $report.Subscriptions
$role_assigment_data_management_groups = $report.ManagementGroups

# One document per scope type in displayName/description/resources format

write-Output "Exporting Role Assignments from Subscriptions and Management Groups..."

$role_assigment_export = @($report.Documents)

switch ($OutputFormat) {
    'Json' {
        $json_export = if ($role_assigment_export.Count -eq 1) { $role_assigment_export[0] } else { $role_assigment_export }
        $json_export | ConvertTo-Json -Depth 10 | Out-File -FilePath "$OutputPath.json" -Encoding utf8
        Write-Host "Snapshot written to $OutputPath.json"
    }
    'Html' {
        ConvertTo-GroupedHtmlReport -Title 'Azure Role Assignment Snapshot' -Documents $role_assigment_export -ManagementGroupNames $report.ManagementGroupNames -SubscriptionNames $report.SubscriptionNames -GeneratedBy 'Export-AzRoleAssignment' | Out-File -FilePath "$OutputPath.html" -Encoding utf8
        Write-Host "Snapshot written to $OutputPath.html"
    }
    'Csv' {
        $flat_assigments = New-FlatRoleAssignmentList -Documents $role_assigment_export
        $flat_assigments | Export-Csv -Path "$OutputPath.csv" -NoTypeInformation -Encoding utf8
        Write-Host "Snapshot written to $OutputPath.csv"
    }
}

if ($role_assigment_export.Count -eq 1) { return $role_assigment_export[0] }

return $role_assigment_export

}

