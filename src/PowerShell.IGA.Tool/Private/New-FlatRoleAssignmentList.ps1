# Flattens the nested ManagementGroup/Subscription role assignment data into a single table for Html/Csv export
function New-FlatRoleAssignmentList {
    <#
    .SYNOPSIS
        Flattens nested ManagementGroup/Subscription role assignment data into a single table.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.Specialized.OrderedDictionary]$ManagementGroupData,
        [System.Collections.Specialized.OrderedDictionary]$SubscriptionData
    )

    $flat_assigments = @()

    foreach ($mgId in $ManagementGroupData.Keys) {
        foreach ($assigment in $ManagementGroupData[$mgId]) {
            $flat_assigments += [PSCustomObject]@{
                ScopeType          = 'ManagementGroup'
                ScopeId            = $mgId
                Scope              = $assigment.Scope
                Inherited          = $assigment.Inherited
                InheritedFrom      = $assigment.InheritedFrom
                DisplayName        = $assigment.DisplayName
                SignInName         = $assigment.SignInName
                ObjectId           = $assigment.ObjectId
                ObjectType         = $assigment.ObjectType
                RoleDefinitionName = $assigment.RoleDefinitionName
            }
        }
    }

    foreach ($subId in $SubscriptionData.Keys) {
        foreach ($assigment in $SubscriptionData[$subId]) {
            $flat_assigments += [PSCustomObject]@{
                ScopeType          = 'Subscription'
                ScopeId            = $subId
                Scope              = $assigment.Scope
                Inherited          = $assigment.Inherited
                InheritedFrom      = $assigment.InheritedFrom
                DisplayName        = $assigment.DisplayName
                SignInName         = $assigment.SignInName
                ObjectId           = $assigment.ObjectId
                ObjectType         = $assigment.ObjectType
                RoleDefinitionName = $assigment.RoleDefinitionName
            }
        }
    }

    return $flat_assigments
}
