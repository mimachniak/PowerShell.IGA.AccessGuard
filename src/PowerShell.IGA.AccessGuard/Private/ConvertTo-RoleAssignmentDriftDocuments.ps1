# Converts a ManagementGroup/Subscription drift result into displayName/description/resources documents for Json export
function ConvertTo-RoleAssignmentDriftDocuments {
    <#
    .SYNOPSIS
        Converts a drift result into document objects with displayName/description/resources.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$DriftResult,

        [string]$Description = 'Role assignment drift detected against the reference export.'
    )

    $drift_documents = @()

    foreach ($section in 'ManagementGroup', 'Subscription') {
        $resources = @()
        foreach ($scope_id in $DriftResult[$section].Keys) {
            foreach ($entry in $DriftResult[$section][$scope_id]) {
                $assignment = $entry.Assignment
                $resources += [PSCustomObject]@{
                    displayName  = "AzRole-$($assignment.DisplayName)"
                    resourceType = $assignment.ObjectType
                    properties   = [PSCustomObject]@{
                        SignInName         = $assignment.SignInName
                        ObjectId           = $assignment.ObjectId
                        RoleDefinitionName = $assignment.RoleDefinitionName
                        Ensure             = if ($entry.Status -eq 'Removed') { 'Present' } else { 'Absent' }
                        DisplayName        = $assignment.DisplayName
                        Scope              = $section
                        ScopeId            = $scope_id
                        Inherited          = $assignment.Inherited
                        InheritedFrom      = $assignment.InheritedFrom
                        Status             = $entry.Status
                        SuggestedAction    = $entry.SuggestedAction
                    }
                }
            }
        }

        $drift_documents += [PSCustomObject]@{
            displayName = if ($section -eq 'ManagementGroup') { 'ManagementGroups' } else { 'Subscriptions' }
            description = $Description
            resources   = $resources
        }
    }

    return $drift_documents
}
