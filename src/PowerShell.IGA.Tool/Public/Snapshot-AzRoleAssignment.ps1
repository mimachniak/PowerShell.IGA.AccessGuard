# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

function Snapshot-AzRoleAssignment {
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
        [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) "output")
    )

$report = Get-AzRoleAssignmentReport
$role_assigment_data_subscriptions = $report.Subscriptions
$role_assigment_data_management_groups = $report.ManagementGroups

# Join both results into a single object, nested by ManagementGroup/Subscription ID

write-Output "Exporting Role Assignments from Subscriptions and Management Groups..."

$role_assigment_export = [PSCustomObject]@{
    ManagementGroup = [PSCustomObject]$role_assigment_data_management_groups
    Subscription = [PSCustomObject]$role_assigment_data_subscriptions
}

switch ($OutputFormat) {
    'Json' {
        $role_assigment_export | ConvertTo-Json -Depth 5 | Out-File -FilePath "$OutputPath.json" -Encoding utf8
    }
    'Html' {
        # Flatten nested ManagementGroup/Subscription data into a single table for Html/Csv output
        $flat_assigments = New-FlatRoleAssignmentList -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions
        $flat_assigments | ConvertTo-Html | Out-File -FilePath "$OutputPath.html" -Encoding utf8
    }
    'Csv' {
        $flat_assigments = New-FlatRoleAssignmentList -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions
        $flat_assigments | Export-Csv -Path "$OutputPath.csv" -NoTypeInformation -Encoding utf8
    }
}

}

