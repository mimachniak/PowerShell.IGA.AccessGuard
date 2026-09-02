function Compare-AzRoleAssignmentSet {
    <#
    .SYNOPSIS
        Compares two role assignment collections and returns Added/Removed entries keyed by Scope+ObjectId+RoleDefinitionName.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$ReferenceAssignments = @(),

        [AllowEmptyCollection()]
        [object[]]$CurrentAssignments = @()
    )

    $getKey = { param($assignment) "$($assignment.Scope)|$($assignment.ObjectId)|$($assignment.RoleDefinitionName)" }

    $referenceByKey = [ordered]@{}
    foreach ($assignment in $ReferenceAssignments) {
        $referenceByKey[(& $getKey $assignment)] = $assignment
    }

    $currentByKey = [ordered]@{}
    foreach ($assignment in $CurrentAssignments) {
        $currentByKey[(& $getKey $assignment)] = $assignment
    }

    $diff = @()

    foreach ($key in $currentByKey.Keys) {
        if (-not $referenceByKey.Contains($key)) {
            $diff += [PSCustomObject]@{
                Status     = 'Added'
                Assignment = $currentByKey[$key]
            }
        }
    }

    foreach ($key in $referenceByKey.Keys) {
        if (-not $currentByKey.Contains($key)) {
            $diff += [PSCustomObject]@{
                Status     = 'Removed'
                Assignment = $referenceByKey[$key]
            }
        }
    }

    return $diff
}
