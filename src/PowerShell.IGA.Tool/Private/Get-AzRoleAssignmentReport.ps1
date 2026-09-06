# Gathers role assignments for all Subscriptions and Management Groups, shared by the Public snapshot/cleanup functions
function Get-AzRoleAssignmentReport {
    <#
    .SYNOPSIS
        Gathers Azure role assignments for all Subscriptions and Management Groups.
    #>
    [CmdletBinding()]
    param(
        # Only return Unknown/Orphaned object type assignments defined directly at scope (excludes inherited assignments).
        [switch]$OrphanedOnly,

        # Only gather role assignments for Subscriptions. Default gathers both Subscriptions and Management Groups.
        [switch]$SubscriptionOnly,

        # Only gather role assignments for Management Groups. Default gathers both Subscriptions and Management Groups.
        [switch]$ManagementGroupOnly,

        # Include role assignments inherited from a parent scope. Default only returns assignments defined directly at scope.
        [switch]$IncludeInherited
    )

    $list_subscriptions = if ($ManagementGroupOnly) { @() } else { Get-AzSubscription | Where-Object { $_.State -ne "Disabled" } }
    $list_managementgroups = if ($SubscriptionOnly) { @() } else { Get-AzManagementGroup }

    $role_assigment_data_subscriptions = [ordered]@{}
    $role_assigment_data_management_groups = [ordered]@{}
    $subscription_names = [ordered]@{}
    $management_group_names = [ordered]@{}

    foreach ($sub in $list_subscriptions) {

        Write-Host "Exporting Role Assignments from Subscription: $($sub.Name) ($($sub.Id))"

        $list_role = Get-AzRoleAssignment -Scope "/subscriptions/$($sub.Id)" -AtScope

        $role_assigments = @()

        foreach ($role in $list_role) {

            $is_inherited = $role.Scope -ne "/subscriptions/$($sub.Id)"
            $is_orphaned = ($role.ObjectType -eq "Unknown") -or ([string]::IsNullOrEmpty($role.DisplayName) -and [string]::IsNullOrEmpty($role.SignInName))

            if ($OrphanedOnly) {
                if (-not $is_orphaned) { continue }
                if ($is_inherited) { continue }
            }
            else {
                if ($is_orphaned) { continue }
                if ($is_inherited -and -not $IncludeInherited) { continue }
            }

            $role_assigments += [PSCustomObject]@{
                Scope = $role.Scope
                Inherited = if ($OrphanedOnly) { $false } else { $is_inherited }
                InheritedFrom = if ($OrphanedOnly) { $null } elseif ($is_inherited) { $role.Scope } else { $null }
                DisplayName = if ($is_orphaned) { "Orphaned" } else { $role.DisplayName }
                SignInName = if ($is_orphaned) { "Orphaned" } else { $role.SignInName }
                ObjectId = $role.ObjectId
                ObjectType = $role.ObjectType
                RoleDefinitionName = $role.RoleDefinitionName
            }

        }

        $role_assigment_data_subscriptions[$sub.Id] = $role_assigments
        $subscription_names[$sub.Id] = $sub.Name

    }

    foreach ($mg in $list_managementgroups) {

        Write-Host "Exporting Role Assignments from Management Group: $($mg.DisplayName) ($($mg.Id))"

        $list_role = Get-AzRoleAssignment -Scope "$($mg.Id)" -AtScope

        $role_assigments = @()

        foreach ($role in $list_role) {

            $is_inherited = $role.Scope -ne "$($mg.Id)"
            $is_orphaned = ($role.ObjectType -eq "Unknown") -or ([string]::IsNullOrEmpty($role.DisplayName) -and [string]::IsNullOrEmpty($role.SignInName))

            if ($OrphanedOnly) {
                if (-not $is_orphaned) { continue }
                if ($is_inherited) { continue }
            }
            else {
                if ($is_orphaned) { continue }
                if ($is_inherited -and -not $IncludeInherited) { continue }
            }

            $role_assigments += [PSCustomObject]@{
                Scope = $role.Scope
                Inherited = if ($OrphanedOnly) { $false } else { $is_inherited }
                InheritedFrom = if ($OrphanedOnly) { $null } elseif ($is_inherited) { $role.Scope } else { $null }
                DisplayName = if ($is_orphaned) { "Orphaned" } else { $role.DisplayName }
                SignInName = if ($is_orphaned) { "Orphaned" } else { $role.SignInName }
                ObjectId = $role.ObjectId
                ObjectType = $role.ObjectType
                RoleDefinitionName = $role.RoleDefinitionName
            }

        }

        $role_assigment_data_management_groups[$mg.Id] = $role_assigments
        $management_group_names[$mg.Id] = $mg.DisplayName

    }

    # Document view in displayName/description/resources format, one document per gathered scope type
    $documents = @()

    if (-not $SubscriptionOnly) {
        $documents += ConvertTo-RoleAssignmentDocument -DisplayName 'ManagementGroups' -ScopeType 'ManagementGroup' -ScopeData $role_assigment_data_management_groups
    }

    if (-not $ManagementGroupOnly) {
        $documents += ConvertTo-RoleAssignmentDocument -DisplayName 'Subscriptions' -ScopeType 'Subscription' -ScopeData $role_assigment_data_subscriptions
    }

    return [PSCustomObject]@{
        Subscriptions         = $role_assigment_data_subscriptions
        ManagementGroups      = $role_assigment_data_management_groups
        SubscriptionNames     = $subscription_names
        ManagementGroupNames  = $management_group_names
        Documents             = $documents
    }
}
