# Converts Subscription/ManagementGroup role assignment scope results into a JUnit-compatible XML report
function ConvertTo-RoleAssignmentJUnitXml {
    <#
    .SYNOPSIS
        Converts role assignment scope results into a JUnit XML test report, one testcase per Subscription/Management Group scope.
    #>
    [CmdletBinding()]
    param(
        [System.Collections.Specialized.OrderedDictionary]$ManagementGroupData,
        [System.Collections.Specialized.OrderedDictionary]$SubscriptionData,

        [string]$SuiteName = 'AzRoleAssignmentOrphaned'
    )

    $scope_results = @()
    foreach ($mgId in $ManagementGroupData.Keys) {
        $scope_results += [PSCustomObject]@{ Section = 'ManagementGroup'; ScopeId = $mgId; Assignments = $ManagementGroupData[$mgId] }
    }
    foreach ($subId in $SubscriptionData.Keys) {
        $scope_results += [PSCustomObject]@{ Section = 'Subscription'; ScopeId = $subId; Assignments = $SubscriptionData[$subId] }
    }

    $tests = $scope_results.Count
    $failures = ($scope_results | Where-Object { $_.Assignments.Count -gt 0 }).Count

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
    [void]$sb.AppendLine('<testsuites>')
    [void]$sb.AppendLine("  <testsuite name=`"$([System.Security.SecurityElement]::Escape($SuiteName))`" tests=`"$tests`" failures=`"$failures`">")

    foreach ($result in $scope_results) {

        $testName = [System.Security.SecurityElement]::Escape("$($result.ScopeId)")
        $className = [System.Security.SecurityElement]::Escape("$($result.Section)")

        if ($result.Assignments.Count -gt 0) {
            $message = ($result.Assignments | ForEach-Object { "$($_.ObjectId) ($($_.RoleDefinitionName)) on $($_.Scope)" }) -join '; '
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
