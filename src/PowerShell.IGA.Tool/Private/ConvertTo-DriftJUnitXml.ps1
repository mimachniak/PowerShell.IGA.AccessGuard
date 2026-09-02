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

    $tests = $ScopeResults.Count
    $failures = ($ScopeResults | Where-Object { $_.Diff.Count -gt 0 }).Count

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<testsuites>')
    [void]$sb.AppendLine("  <testsuite name=`"$([System.Security.SecurityElement]::Escape($SuiteName))`" tests=`"$tests`" failures=`"$failures`">")

    foreach ($result in $ScopeResults) {

        $testName = [System.Security.SecurityElement]::Escape("$($result.ScopeId)")
        $className = [System.Security.SecurityElement]::Escape("$($result.Section)")

        if ($result.Diff.Count -gt 0) {
            $message = ($result.Diff | ForEach-Object { "$($_.Status): $($_.Assignment.ObjectId) ($($_.Assignment.RoleDefinitionName))" }) -join '; '
            $messageEscaped = [System.Security.SecurityElement]::Escape($message)
            [void]$sb.AppendLine("    <testcase classname=`"$className`" name=`"$testName`">")
            [void]$sb.AppendLine("      <failure message=`"$messageEscaped`">$messageEscaped</failure>")
            [void]$sb.AppendLine('    </testcase>')
        }
        else {
            [void]$sb.AppendLine("    <testcase classname=`"$className`" name=`"$testName`" />")
        }

    }

    [void]$sb.AppendLine('  </testsuite>')
    [void]$sb.AppendLine('</testsuites>')

    return $sb.ToString()
}
