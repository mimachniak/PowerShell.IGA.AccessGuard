# Converts nested role assignment data into a document object with displayName/description/resources
function ConvertTo-RoleAssignmentDocument {
    <#
    .SYNOPSIS
        Converts role assignment data for a scope type into a resource document object.
    #>
    [CmdletBinding()]
    param(
        # Document display name, for example 'ManagementGroups' or 'Subscriptions'.
        [Parameter(Mandatory)]
        [string]$DisplayName,

        # Scope type written to each resource property bag.
        [Parameter(Mandatory)]
        [ValidateSet('ManagementGroup', 'Subscription')]
        [string]$ScopeType,

        # Role assignments keyed by Management Group or Subscription id.
        [System.Collections.Specialized.OrderedDictionary]$ScopeData,

        # Optional document description.
        [string]$Description = ''
    )

    $resources = @()

    if ($ScopeData) {
        foreach ($scope_id in $ScopeData.Keys) {
            foreach ($assigment in $ScopeData[$scope_id]) {
                $resources += [PSCustomObject]@{
                    displayName  = "AzRole-$($assigment.DisplayName)"
                    resourceType = $assigment.ObjectType
                    properties   = [PSCustomObject]@{
                        SignInName         = $assigment.SignInName
                        ObjectId           = $assigment.ObjectId
                        RoleDefinitionName = $assigment.RoleDefinitionName
                        Ensure             = 'Present'
                        DisplayName        = $assigment.DisplayName
                        Scope              = $ScopeType
                        ScopeId            = $scope_id
                        Inherited          = $assigment.Inherited
                        InheritedFrom      = $assigment.InheritedFrom
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        displayName = $DisplayName
        description = $Description
        resources   = $resources
    }
}
