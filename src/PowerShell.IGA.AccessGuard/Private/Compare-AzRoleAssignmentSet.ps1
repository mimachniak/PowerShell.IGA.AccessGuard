function Compare-AzRoleAssignmentSet {
    <#
    .SYNOPSIS
        Compares desired and current role assignment collections keyed by Scope+ObjectId+RoleDefinitionName.
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
                Status          = 'Added'
                SuggestedAction = 'Remove role assignment'
                Assignment      = $currentByKey[$key]
            }
        }
    }

    foreach ($key in $referenceByKey.Keys) {
        if (-not $currentByKey.Contains($key)) {
            $referenceAssignment = $referenceByKey[$key]
            $desiredState = if ($referenceAssignment.Ensure) { [string]$referenceAssignment.Ensure } else { 'Present' }
            if ($desiredState -ne 'Present') { continue }

            $diff += [PSCustomObject]@{
                Status          = 'Removed'
                SuggestedAction = 'Add role assignment'
                Assignment      = $referenceAssignment
            }
        }
    }

    return $diff
}
