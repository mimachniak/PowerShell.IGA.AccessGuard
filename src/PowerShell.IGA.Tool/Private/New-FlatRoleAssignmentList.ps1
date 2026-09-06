# Flattens the nested ManagementGroup/Subscription role assignment data into a single table for Html/Csv export
function New-FlatRoleAssignmentList {
    <#
    .SYNOPSIS
        Flattens nested ManagementGroup/Subscription role assignment data into a single table.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ScopeData')]
    param(
        # Documents in displayName/description/resources format.
        [Parameter(Mandatory, ParameterSetName = 'Documents')]
        [object[]]$Documents,

        [Parameter(ParameterSetName = 'ScopeData')]
        [System.Collections.Specialized.OrderedDictionary]$ManagementGroupData,

        [Parameter(ParameterSetName = 'ScopeData')]
        [System.Collections.Specialized.OrderedDictionary]$SubscriptionData
    )

    $flat_assigments = @()

    if ($PSCmdlet.ParameterSetName -eq 'Documents') {
        foreach ($document in $Documents) {
            foreach ($resource in @($document.resources)) {
                $flat_assigments += [PSCustomObject]@{
                    Document           = $document.displayName
                    ResourceName       = $resource.displayName
                    ResourceType       = $resource.resourceType
                    SignInName         = $resource.properties.SignInName
                    ObjectId           = $resource.properties.ObjectId
                    RoleDefinitionName = $resource.properties.RoleDefinitionName
                    Ensure             = $resource.properties.Ensure
                    DisplayName        = $resource.properties.DisplayName
                    Scope              = $resource.properties.Scope
                    ScopeId            = $resource.properties.ScopeId
                    Inherited          = $resource.properties.Inherited
                    InheritedFrom      = $resource.properties.InheritedFrom
                }
            }
        }

        return $flat_assigments
    }

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
