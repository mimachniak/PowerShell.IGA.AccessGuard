# Converts flattened Subscription/ManagementGroup drift scope results into a JUnit-compatible XML report
function ConvertTo-DriftJUnitXml {
    <#
    .SYNOPSIS
        Converts drift scope results into a JUnit XML test report, one testcase per Subscription/Management Group scope.
    #>
    [CmdletBinding()]
    param(
        # Each entry must have Section, ScopeId and Diff (array of Status/Assignment entries from Compare-AzRoleAssignmentSet).
        [Parameter(Mandatory)]
        [array]$ScopeResults,

        [string]$SuiteName = 'AzRoleAssignmentDrift'
    )

    $failedTests = @()
    foreach ($result in $ScopeResults) {
        if ($result.Diff.Count -eq 0) { continue }

        foreach ($diffEntry in $result.Diff) {
            $assignment = $diffEntry.Assignment
            $objectId = if ($null -ne $assignment.ObjectId) { [string]$assignment.ObjectId } else { 'Unknown' }
            $objectType = if ($null -ne $assignment.ObjectType) { [string]$assignment.ObjectType } else { 'Unknown' }
            $displayName = if ($null -ne $assignment.DisplayName) { [string]$assignment.DisplayName } else { 'Unknown' }
            $roleName = if ($null -ne $assignment.RoleDefinitionName) { [string]$assignment.RoleDefinitionName } else { 'Unknown' }

            $failedTests += [PSCustomObject]@{
                Section = $result.Section
                ScopeId = $result.ScopeId
                Status = [string]$diffEntry.Status
                ObjectId = $objectId
                ObjectType = $objectType
                DisplayName = $displayName
                RoleDefinitionName = $roleName
                Assignment = $assignment
            }
        }
    }

    $tests = $failedTests.Count
    $failures = $failedTests.Count

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<testsuites>')
    [void]$sb.AppendLine("  <testsuite name=`"$([System.Security.SecurityElement]::Escape($SuiteName))`" tests=`"$tests`" failures=`"$failures`">")

    foreach ($failedTest in $failedTests) {
        $className = [System.Security.SecurityElement]::Escape("$($failedTest.Section) / $($failedTest.ScopeId)")
        $testName = [System.Security.SecurityElement]::Escape("$($failedTest.RoleDefinitionName) / $($failedTest.ObjectType) / $($failedTest.DisplayName) / $($failedTest.ObjectId) / $($failedTest.Status)")

        $message = "Role assignment drift test failed: Scope: $($failedTest.ScopeId); $($failedTest.Status): Object ID: $($failedTest.ObjectId); Type: $($failedTest.ObjectType); DisplayName: $($failedTest.DisplayName); Role: $($failedTest.RoleDefinitionName)"
        $messageEscaped = [System.Security.SecurityElement]::Escape($message)

        [void]$sb.AppendLine("    <testcase classname=`"$className`" name=`"$testName`">")
        [void]$sb.AppendLine("      <failure message=`"$messageEscaped`">$messageEscaped</failure>")
        [void]$sb.AppendLine('    </testcase>')
    }

    [void]$sb.AppendLine('  </testsuite>')
    [void]$sb.AppendLine('</testsuites>')

    return $sb.ToString()
}
