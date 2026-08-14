# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

#Requires –Modules Az

function Clean-AzRoleOrphaned {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        # Actually remove the orphaned role assignments from Azure. Default behavior only reports them.
        [switch]$Remove,

        [string]$ReportPath = ".\output_unknow.json"
    )

$list_subscriptions = Get-AzSubscription | Where-Object {$_.State -ne "Disabled"}
$list_managementgroups = Get-AzManagementGroup



$role_assigment_export = [PSCustomObject]@{
    ManagementGroup = $null
    Subscription = $null
}

$role_assigment_data_subscriptions = [ordered]@{}
$role_assigment_data_management_groups = [ordered]@{}

foreach ($sub in $list_subscriptions) {

    Write-Host "Exporting Role Assignments from Subscription: $($sub.Name) ($($sub.Id))"
    
    $list_role = Get-AzRoleAssignment -Scope "/subscriptions/$($sub.Id)" -AtScope

    $role_assigments = @()

    foreach ($role in $list_role) {

        if ($role.ObjectType -ne "Unknown") {
            continue
        }

        if ($role.Scope -ne "/subscriptions/$($sub.Id)") {
            continue
        }

        $role_assigments += [PSCustomObject]@{
            Scope = $role.Scope
            Inherited = $false
            InheritedFrom = $null
            DisplayName = $role.DisplayName
            SignInName = $role.SignInName
            ObjectId = $role.ObjectId
            ObjectType = "Orphaned"
            RoleDefinitionName = $role.RoleDefinitionName
        }

    }

    $role_assigment_data_subscriptions[$sub.Id] = $role_assigments

}


foreach ($mg in $list_managementgroups) {

    write-Host "Exporting Role Assignments from Management Group: $($mg.DisplayName) ($($mg.Id))"

    $list_role = Get-AzRoleAssignment -Scope "$($mg.Id)" -AtScope

    $role_assigments = @()

    foreach ($role in $list_role) {

        if ($role.ObjectType -ne "Unknown") {
            continue
        }

        if ($role.Scope -ne "$($mg.Id)") {
            continue
        }

        $role_assigments += [PSCustomObject]@{
            Scope = $role.Scope
            Inherited = $false
            InheritedFrom = $null
            DisplayName = $role.DisplayName
            SignInName = $role.SignInName
            ObjectId = $role.ObjectId
            ObjectType = "Orphaned"
            RoleDefinitionName = $role.RoleDefinitionName
        }

    }

    $role_assigment_data_management_groups[$mg.Id] = $role_assigments

}

# Join both results into a single object, nested by ManagementGroup/Subscription ID

write-Output "Exporting Role Assignments from Subscriptions and Management Groups..."

$role_assigment_export = [PSCustomObject]@{
    ManagementGroup = [PSCustomObject]$role_assigment_data_management_groups
    Subscription = [PSCustomObject]$role_assigment_data_subscriptions
}

$role_assigment_export | ConvertTo-Json -Depth 5 | Out-File -FilePath $ReportPath -Encoding utf8

if (-not $Remove) {
    Write-Host "Report only mode. No role assignments were removed. Report written to $ReportPath"
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





