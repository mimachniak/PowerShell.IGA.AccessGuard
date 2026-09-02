# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

#Requires –Modules Az

function Remove-AzRoleOrphaned {
    <#
    .SYNOPSIS
        Reports, and optionally removes, orphaned Azure role assignments across Subscriptions and Management Groups.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        # Actually remove the orphaned role assignments from Azure. Default behavior only reports them.
        [switch]$Remove,

        # Report format. 'Terminal' prints a table to the host instead of writing a file. Defaults to Json.
        [ValidateSet('Terminal', 'Json', 'Html', 'Csv', 'JUnit')]
        [string]$OutputFormat = 'Json',

        # Report file path without extension; the correct extension is appended based on -OutputFormat (ignored for 'Terminal').
        [string]$OutputPath = ".\output_unknow"
    )

$report = Get-AzRoleAssignmentReport -OrphanedOnly
$role_assigment_data_subscriptions = $report.Subscriptions
$role_assigment_data_management_groups = $report.ManagementGroups

# Join both results into a single object, nested by ManagementGroup/Subscription ID

write-Output "Exporting Role Assignments from Subscriptions and Management Groups..."

$role_assigment_export = [PSCustomObject]@{
    ManagementGroup = [PSCustomObject]$role_assigment_data_management_groups
    Subscription = [PSCustomObject]$role_assigment_data_subscriptions
}

switch ($OutputFormat) {
    'Terminal' {
        New-FlatRoleAssignmentList -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions | Format-Table -AutoSize
    }
    'Json' {
        $role_assigment_export | ConvertTo-Json -Depth 5 | Out-File -FilePath "$OutputPath.json" -Encoding utf8
        Write-Host "Report written to $OutputPath.json"
    }
    'Html' {
        ConvertTo-GroupedHtmlReport -Title 'Azure Orphaned Role Assignment Report' -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions -ManagementGroupNames $report.ManagementGroupNames -SubscriptionNames $report.SubscriptionNames -GeneratedBy 'Remove-AzRoleOrphaned' | Out-File -FilePath "$OutputPath.html" -Encoding utf8
        Write-Host "Report written to $OutputPath.html"
    }
    'Csv' {
        New-FlatRoleAssignmentList -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions | Export-Csv -Path "$OutputPath.csv" -NoTypeInformation -Encoding utf8
        Write-Host "Report written to $OutputPath.csv"
    }
    'JUnit' {
        ConvertTo-RoleAssignmentJUnitXml -ManagementGroupData $role_assigment_data_management_groups -SubscriptionData $role_assigment_data_subscriptions | Out-File -FilePath "$OutputPath.xml" -Encoding utf8
        Write-Host "Report written to $OutputPath.xml"
    }
}

if (-not $Remove) {
    Write-Host "Report only mode. No role assignments were removed."
    return $role_assigment_export
}

$all_orphaned = @($role_assigment_data_subscriptions.Values) + @($role_assigment_data_management_groups.Values) | ForEach-Object { $_ }

foreach ($role_assigment in $all_orphaned) {

    $target = "$($role_assigment.ObjectId) on $($role_assigment.Scope) ($($role_assigment.RoleDefinitionName))"

    if ($PSCmdlet.ShouldProcess($target, "Remove orphaned role assignment")) {

        Remove-AzRoleAssignment -ObjectId $role_assigment.ObjectId -Scope $role_assigment.Scope -RoleDefinitionName $role_assigment.RoleDefinitionName

    }

}

return $role_assigment_export

}





