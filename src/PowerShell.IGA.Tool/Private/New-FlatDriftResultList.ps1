# Flattens the nested ManagementGroup/Subscription drift result into a single table for Html/Csv export
function New-FlatDriftResultList {
    <#
    .SYNOPSIS
        Flattens nested ManagementGroup/Subscription drift results into a single table.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.Specialized.OrderedDictionary]$DriftResult
    )

    $flat_diff = @()

    foreach ($section in 'ManagementGroup', 'Subscription') {
        foreach ($id in $DriftResult[$section].Keys) {
            foreach ($entry in $DriftResult[$section][$id]) {
                $flat_diff += [PSCustomObject]@{
                    Section            = $section
                    ScopeId            = $id
                    Status             = $entry.Status
                    SuggestedAction    = $entry.SuggestedAction
                    Scope              = $entry.Assignment.Scope
                    DisplayName        = $entry.Assignment.DisplayName
                    SignInName         = $entry.Assignment.SignInName
                    ObjectId           = $entry.Assignment.ObjectId
                    ObjectType         = $entry.Assignment.ObjectType
                    RoleDefinitionName = $entry.Assignment.RoleDefinitionName
                }
            }
        }
    }

    return $flat_diff
}
