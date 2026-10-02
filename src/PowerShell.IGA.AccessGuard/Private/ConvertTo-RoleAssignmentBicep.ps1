function ConvertTo-RoleAssignmentBicep {
    [CmdletBinding()]
    param(
        [System.Collections.IDictionary]$SubscriptionData,
        [System.Collections.IDictionary]$ManagementGroupData
    )

    $bicep_lines = [System.Collections.Generic.List[string]]::new()
    $bicep_lines.Add("targetScope = 'tenant'")
    $bicep_lines.Add('')
    $exported_at_utc = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
    $bicep_lines.Add("metadata generatedBy = 'PowerShell.IGA.AccessGuard'")
    $bicep_lines.Add("metadata exportedAtUtc = '$exported_at_utc'")
    $bicep_lines.Add('')
    $format_bicep_string = {
        param([string]$Value)
        "'" + $Value.Replace("'", "''").Replace('${', '\${') + "'"
    }

    $scope_collections = @(
        @{ ScopeType = 'ManagementGroup'; ScopeData = $ManagementGroupData; Marker = 'Management Group Role Assignments' }
        @{ ScopeType = 'Subscription'; ScopeData = $SubscriptionData; Marker = 'Subscription Role Assignments' }
    )
    $allowed_principal_types = @('Device', 'ForeignGroup', 'Group', 'ServicePrincipal', 'User')
    $seen_assignments = @{}
    $used_module_names = @{}

    foreach ($scope_collection in $scope_collections) {
        $bicep_lines.Add("// MARK: $($scope_collection.Marker)")
        $bicep_lines.Add('')
        if ($null -eq $scope_collection.ScopeData) { continue }

        foreach ($recorded_scope_id in @($scope_collection.ScopeData.Keys | Sort-Object)) {
            $assignments = @($scope_collection.ScopeData[$recorded_scope_id] | Sort-Object ObjectId, RoleDefinitionName)

            foreach ($assignment in $assignments) {
                $principal_id = [string]$assignment.ObjectId
                $principal_type = [string]$assignment.ObjectType
                $role_name = [string]$assignment.RoleDefinitionName
                $display_name = [string]$assignment.DisplayName
                $sign_in_name = [string]$assignment.SignInName

                if ([string]::IsNullOrWhiteSpace($principal_id) -or
                    [string]::IsNullOrWhiteSpace($role_name) -or
                    $principal_type -eq 'Unknown' -or
                    $role_name -match '^(?i:unknown|orphaned)(\b|$)' -or
                    $display_name -eq 'Orphaned' -or
                    $sign_in_name -eq 'Orphaned' -or
                    ([string]::IsNullOrWhiteSpace($display_name) -and [string]::IsNullOrWhiteSpace($sign_in_name))) {
                    continue
                }

                $assignment_scope = [string]$assignment.Scope
                $target_scope_type = $null
                $target_scope_id = $null

                if ($assignment_scope -match '(?i)^/?subscriptions/([^/]+)$') {
                    $target_scope_type = 'Subscription'
                    $target_scope_id = $Matches[1]
                }
                elseif ($assignment_scope -match '(?i)^/?providers/Microsoft\.Management/managementGroups/([^/]+)$') {
                    $target_scope_type = 'ManagementGroup'
                    $target_scope_id = $Matches[1]
                }
                elseif (-not $assignment.Inherited) {
                    $target_scope_type = $scope_collection.ScopeType
                    if ($target_scope_type -eq 'Subscription') {
                        if ($recorded_scope_id -match '(?i)^/?subscriptions/([^/]+)$') {
                            $target_scope_id = $Matches[1]
                        }
                        else {
                            $target_scope_id = [string]$recorded_scope_id
                        }
                    }
                    else {
                        if ($recorded_scope_id -match '(?i)^/?providers/Microsoft\.Management/managementGroups/([^/]+)$') {
                            $target_scope_id = $Matches[1]
                        }
                        else {
                            $target_scope_id = [string]$recorded_scope_id
                        }
                    }
                }

                if ([string]::IsNullOrWhiteSpace($target_scope_id)) { continue }

                $assignment_key = '{0}|{1}|{2}|{3}' -f $target_scope_type.ToLowerInvariant(), $target_scope_id.ToLowerInvariant(), $principal_id.ToLowerInvariant(), $role_name.ToLowerInvariant()
                if ($seen_assignments.ContainsKey($assignment_key)) { continue }
                $seen_assignments[$assignment_key] = $true

                $scope_prefix = if ($target_scope_type -eq 'ManagementGroup') { 'mg' } else { 'sub' }
                $role_name_identifier = [regex]::Replace($role_name.ToLowerInvariant(), '[^a-z0-9]+', '_').Trim('_')
                $principal_id_identifier = [regex]::Replace($principal_id.ToLowerInvariant(), '[^a-z0-9]+', '_').Trim('_')
                $module_name = 'mod_role_assignment_{0}_{1}_{2}' -f $scope_prefix, $role_name_identifier, $principal_id_identifier
                if ($used_module_names.ContainsKey($module_name)) {
                    $scope_id_identifier = [regex]::Replace($target_scope_id.ToLowerInvariant(), '[^a-z0-9]+', '_').Trim('_')
                    $module_name = '{0}_{1}' -f $module_name, $scope_id_identifier
                    $collision_index = 1
                    while ($used_module_names.ContainsKey($module_name)) {
                        $module_name = '{0}_{1}' -f $module_name, $collision_index
                        $collision_index++
                    }
                }
                $used_module_names[$module_name] = $true
                $module_reference = if ($target_scope_type -eq 'ManagementGroup') {
                    'br/public:avm/res/authorization/role-assignment/mg-scope:0.1.2'
                }
                else {
                    'br/public:avm/res/authorization/role-assignment/sub-scope:0.1.1'
                }

                $bicep_lines.Add("module $module_name '$module_reference' = {")
                if ($target_scope_type -eq 'ManagementGroup') {
                    $scope_literal = & $format_bicep_string $target_scope_id
                    $bicep_lines.Add("  scope: managementGroup($scope_literal)")
                }
                else {
                    $scope_literal = & $format_bicep_string $target_scope_id
                    $bicep_lines.Add("  scope: subscription($scope_literal)")
                }
                $bicep_lines.Add('  params: {')
                $bicep_lines.Add("    principalId: $(& $format_bicep_string $principal_id)")
                $bicep_lines.Add("    roleDefinitionIdOrName: $(& $format_bicep_string $role_name)")
                if ($target_scope_type -eq 'ManagementGroup') {
                    $bicep_lines.Add("    managementGroupId: $scope_literal")
                }
                if ($allowed_principal_types -contains $principal_type) {
                    $bicep_lines.Add("    principalType: $(& $format_bicep_string $principal_type)")
                }
                $bicep_lines.Add('    enableTelemetry: false')
                $bicep_lines.Add('  }')
                $bicep_lines.Add('}')
                $bicep_lines.Add('')
            }
        }
    }

    if ($used_module_names.Count -eq 0) {
        $bicep_lines.Add('// No deployable role assignments were found.')
    }

    return ($bicep_lines -join [Environment]::NewLine) + [Environment]::NewLine
}