# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

#Requires –Modules Az



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

$role_assigment_export | ConvertTo-Json -Depth 5 | Out-File -FilePath ".\output_unknow.json" -Encoding utf8





