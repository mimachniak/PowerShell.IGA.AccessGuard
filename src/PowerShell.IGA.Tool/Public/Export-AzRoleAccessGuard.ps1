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

# Join both results into a single object, nested by ManagementGroup/Subscription ID

write-Output "Exporting Role Assignments from Subscriptions and Management Groups..."

$role_assigment_export = [PSCustomObject]@{
    ManagementGroup = [PSCustomObject]$role_assigment_data_management_groups
    Subscription = [PSCustomObject]$role_assigment_data_subscriptions
}

switch ($OutputFormat) {
    'Json' {
        $role_assigment_export | ConvertTo-Json -Depth 5 | Out-File -FilePath "$OutputPath.json" -Encoding utf8
        Write-Host "Snapshot written to $OutputPath.json"
    }
    'Html' {
        ConvertTo-GroupedHtmlReport -Title 'Azure Role Assignment Snapshot' -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions -ManagementGroupNames $report.ManagementGroupNames -SubscriptionNames $report.SubscriptionNames -GeneratedBy 'Export-AzRoleAssignment' | Out-File -FilePath "$OutputPath.html" -Encoding utf8
        Write-Host "Snapshot written to $OutputPath.html"
    }
    'Csv' {
        $flat_assigments = New-FlatRoleAssignmentList -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions
        $flat_assigments | Export-Csv -Path "$OutputPath.csv" -NoTypeInformation -Encoding utf8
        Write-Host "Snapshot written to $OutputPath.csv"
    }
}

}

