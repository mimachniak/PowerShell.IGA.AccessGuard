# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

#Requires –Modules Az.Account, Az.Resources, Az.ManagementGroups



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



        $role_assigments += [PSCustomObject]@{
            Scope = $role.Scope
            Inherited = if ($role.Scope -ne "/subscriptions/$($sub.Id)") {
                $true
            } else {
                $false
            }
            InheritedFrom = if ($role.Scope -ne "/subscriptions/$($sub.Id)") {
                $role.Scope
            } else {
                $null
            }
            DisplayName = $role.DisplayName
            SignInName = $role.SignInName
            ObjectId = $role.ObjectId
            ObjectType = if ($role.ObjectType -eq "Unknown") {
                "Orphaned"
            } else {
                $role.ObjectType
            }
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



        $role_assigments += [PSCustomObject]@{
            Scope = $role.Scope
            Inherited = if ($role.Scope -ne "$($mg.Id)") {
                $true
            } else {
                $false
            }
            InheritedFrom = if ($role.Scope -ne "$($mg.Id)") {
                $role.Scope
            } else {
                $null
            }
            DisplayName = $role.DisplayName
            SignInName = $role.SignInName
            ObjectId = $role.ObjectId
            ObjectType = if ($role.ObjectType -eq "Unknown") {
                "Orphaned"
            } else {
                $role.ObjectType
            }
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

$role_assigment_export | ConvertTo-Json -Depth 5 | Out-File -FilePath ".\output.json" -Encoding utf8

<#
foreach ($mg in $list_managementgroups) {

    Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/$($mg.Id)" -IncludeClassicAdministrators

}
#>




<#

foreach ($sub in $list_subscriptions)
{
    
    Set-AzContext -SubscriptionId $sub.Id
    #Write-Output ("**Subscription: " + $sub.Name + "**")

    # Get-AzRoleAssignment -Scope "/subscriptions/96231a05-34ce-4eb4-aa6a-70759cbb5e83
    # Get-AzRoleAssignment -Scope "/providers/Microsoft.Management/managementGroups/Organization" -IncludeClassicAdministrators
    # Get-AzManagementGroup | Select-Object Name, DisplayName, Id
    $list_role = Get-AzRoleAssignment -IncludeClassicAdministrators
    $sub_quota_id = ($sub.SubscriptionPolicies.QuotaId).Split("_")
    $sub_quota_id = $sub_quota_id[0]
    
    foreach ($role in $list_role) {


        #$role.SignInName
        #$role.RoleDefinitionName
        #$role.ObjectType

        if ($role.ObjectType -eq "Group") {

            $SignInName = $role.DisplayName

        } elseif ($role.ObjectType -eq "ServicePrincipal") {

            $SignInName = $role.ObjectId
        }
        else {

            $SignInName = $role.SignInName
        }

            $rbac_report_data = New-Object -TypeName pscustomobject
            $rbac_report_data | Add-Member -MemberType NoteProperty -Name 'SubscriptionID' -Value $sub.Id
            $rbac_report_data | Add-Member -MemberType NoteProperty -Name 'SubscriptionName' -Value $sub.Name
            $rbac_report_data | Add-Member -MemberType NoteProperty -Name 'CostSpending' -Value $sub_quota_id
            $rbac_report_data | Add-Member -MemberType NoteProperty -Name 'SignInName' -Value $SignInName
            $rbac_report_data | Add-Member -MemberType NoteProperty -Name 'ObjectId' -Value "$($role.ObjectId)"
            $rbac_report_data | Add-Member -MemberType NoteProperty -Name 'RoleDefinitionName' -Value $role.RoleDefinitionName
            $rbac_report_data | Add-Member -MemberType NoteProperty -Name 'ObjectType' -Value $role.ObjectType
            $rbac_report += $rbac_report_data

    }
    
}

function Set-AzureEnv {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("Prod-Sub", "Dev-Sub", "Corp-MgmtGroup", "Both")]
        [string]$Target
    )

    switch ($Target) {
        "Prod-Sub"       { # Logic for Prod }
        "Dev-Sub"        { # Logic for Dev }
        "Corp-MgmtGroup" { # Logic for MG }
        "Both"           { # Logic for Both }
    }
}

#>
