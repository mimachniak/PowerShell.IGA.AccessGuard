# Renders a titled, collapsible HTML report grouped by Management Group and Subscription scope
function ConvertTo-GroupedHtmlReport {
    <#
    .SYNOPSIS
        Converts Management Group / Subscription scoped row data into a titled, collapsible HTML report.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ScopeData')]
    param(
        [Parameter(Mandatory)]
        [string]$Title,

        # Documents in displayName/description/resources format.
        [Parameter(Mandatory, ParameterSetName = 'Documents')]
        [object[]]$Documents,

        [Parameter(ParameterSetName = 'ScopeData')]
        [System.Collections.Specialized.OrderedDictionary]$ManagementGroupData,

        [Parameter(ParameterSetName = 'ScopeData')]
        [System.Collections.Specialized.OrderedDictionary]$SubscriptionData,

        # Optional ScopeId -> DisplayName lookups shown alongside each scope's ID in the report.
        [System.Collections.IDictionary]$ManagementGroupNames = @{},
        [System.Collections.IDictionary]$SubscriptionNames = @{},

        # Name shown in the report subtitle to identify which tool/function generated it.
        [string]$GeneratedBy = 'PowerShell.IGA.Tool'
    )

    $generated_on = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    $style = @'
<style>
    body { font-family: Segoe UI, Arial, sans-serif; margin: 20px; color: #222; }
    h1 { margin-bottom: 0; }
    .subtitle { color: #666; margin-top: 4px; }
    h2 { border-bottom: 2px solid #444; padding-bottom: 4px; margin-top: 30px; }
    details { margin-bottom: 8px; border: 1px solid #ccc; border-radius: 4px; padding: 6px 10px; }
    summary { font-weight: bold; cursor: pointer; }
    table { border-collapse: collapse; width: 100%; margin-top: 8px; }
    th, td { border: 1px solid #ddd; padding: 6px 8px; font-size: 13px; text-align: left; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #fafafa; }
</style>
'@

    function ConvertTo-ScopeTable {
        param([array]$Rows)

        if (-not $Rows -or $Rows.Count -eq 0) { return '<p><em>No entries.</em></p>' }

        $columns = $Rows[0].PSObject.Properties.Name
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('<table><thead><tr>')
        foreach ($col in $columns) { [void]$sb.Append("<th>$([System.Net.WebUtility]::HtmlEncode($col))</th>") }
        [void]$sb.Append('</tr></thead><tbody>')
        foreach ($row in $Rows) {
            [void]$sb.Append('<tr>')
            foreach ($col in $columns) {
                [void]$sb.Append("<td>$([System.Net.WebUtility]::HtmlEncode([string]$row.$col))</td>")
            }
            [void]$sb.Append('</tr>')
        }
        [void]$sb.Append('</tbody></table>')
        return $sb.ToString()
    }

    function ConvertTo-GroupSectionHtml {
        param([string]$SectionTitle, [System.Collections.Specialized.OrderedDictionary]$Data, [System.Collections.IDictionary]$Names)

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append("<h2>$([System.Net.WebUtility]::HtmlEncode($SectionTitle))</h2>")

        if (-not $Data -or $Data.Keys.Count -eq 0) {
            [void]$sb.Append('<p><em>No entries.</em></p>')
            return $sb.ToString()
        }

        foreach ($id in $Data.Keys) {
            $rows = @($Data[$id])
            $label = $id
            if ($Names -and $Names.Contains($id) -and $Names[$id]) { $label = "$id ($($Names[$id]))" }
            [void]$sb.Append("<details><summary>$([System.Net.WebUtility]::HtmlEncode($label)) ($($rows.Count))</summary>")
            [void]$sb.Append((ConvertTo-ScopeTable -Rows $rows))
            [void]$sb.Append('</details>')
        }

        return $sb.ToString()
    }

    function ConvertTo-DocumentSectionHtml {
        param([object]$Document, [System.Collections.IDictionary]$Names)

        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append("<h2>$([System.Net.WebUtility]::HtmlEncode([string]$Document.displayName))</h2>")

        if ($Document.description) {
            [void]$sb.Append("<p class='subtitle'>$([System.Net.WebUtility]::HtmlEncode([string]$Document.description))</p>")
        }

        $resources = @($Document.resources)

        if ($resources.Count -eq 0) {
            [void]$sb.Append('<p><em>No entries.</em></p>')
            return $sb.ToString()
        }

        foreach ($group in $resources | Group-Object { $_.properties.ScopeId }) {
            $label = $group.Name
            if ($Names -and $Names.Contains($group.Name) -and $Names[$group.Name]) { $label = "$($group.Name) ($($Names[$group.Name]))" }

            $rows = foreach ($resource in $group.Group) {
                [PSCustomObject]@{
                    displayName        = $resource.displayName
                    resourceType       = $resource.resourceType
                    DisplayNameProp    = $resource.properties.DisplayName
                    SignInName         = $resource.properties.SignInName
                    ObjectId           = $resource.properties.ObjectId
                    RoleDefinitionName = $resource.properties.RoleDefinitionName
                    Ensure             = $resource.properties.Ensure
                    Scope              = $resource.properties.Scope
                    ScopeId            = $resource.properties.ScopeId
                    Inherited          = $resource.properties.Inherited
                    InheritedFrom      = $resource.properties.InheritedFrom
                }
            }

            [void]$sb.Append("<details><summary>$([System.Net.WebUtility]::HtmlEncode($label)) ($($group.Count))</summary>")
            [void]$sb.Append((ConvertTo-ScopeTable -Rows @($rows)))
            [void]$sb.Append('</details>')
        }

        return $sb.ToString()
    }

    $body = "<h1>$([System.Net.WebUtility]::HtmlEncode($Title))</h1>"
    $body += "<p class='subtitle'>Generated by $([System.Net.WebUtility]::HtmlEncode($GeneratedBy)) on $generated_on</p>"

    if ($PSCmdlet.ParameterSetName -eq 'Documents') {
        foreach ($document in $Documents) {
            $names = if ([string]$document.displayName -like 'ManagementGroup*') { $ManagementGroupNames } else { $SubscriptionNames }
            $body += ConvertTo-DocumentSectionHtml -Document $document -Names $names
        }
    }
    else {
        $body += ConvertTo-GroupSectionHtml -SectionTitle 'Management Groups' -Data $ManagementGroupData -Names $ManagementGroupNames
        $body += ConvertTo-GroupSectionHtml -SectionTitle 'Subscriptions' -Data $SubscriptionData -Names $SubscriptionNames
    }

    return "<html><head><meta charset='utf-8'><title>$([System.Net.WebUtility]::HtmlEncode($Title))</title>$style</head><body>$body</body></html>"
}
