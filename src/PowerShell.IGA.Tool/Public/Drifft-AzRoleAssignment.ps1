# Loads 'MyFunctions.ps1' from the same folder as the current script
# . "D:\Git\PowerShell.IGA.Tool\src\PowerShell.IGA.Tool\Private\MyTesFunction.ps1"

# Get-WelcomeMessage -Name "Alice"

# Feature add switch for MG / Subscription export
# Default Export is both MG and Subscription
# Change Name of output
# change of functions
# Add Private function to get role assignments for MG and Subscription

# Loads 'MyFunctions.ps1' from the same folder as the current script
. "D:\Git\PowerShell.IGA.Tool\src\PowerShell.IGA.Tool\Private\Compare-AzRoleAssignmentSet.ps1"

#Requires –Modules Az

    # Previously exported role assignment file (e.g. produced by Export-AzRoleAssignmentPermissions) to compare against
    [string]$ReferenceFile = "D:\Git\output.json"

    # Where the detected differences are written
    [string]$DriftOutputFile = "D:\Git\drift.json"

    $list_subscriptions = Get-AzSubscription | Where-Object {$_.State -ne "Disabled"}
    $list_managementgroups = Get-AzManagementGroup

    $role_assigment_data_subscriptions = [ordered]@{}
    $role_assigment_data_management_groups = [ordered]@{}

    foreach ($sub in $list_subscriptions) {

        Write-Host "Exporting Role Assignments from Subscription: $($sub.Name) ($($sub.Id))"

        $list_role = Get-AzRoleAssignment -Scope "/subscriptions/$($sub.Id)" -AtScope

        $role_assigments = @()

        foreach ($role in $list_role) {

            $role_assigments += [PSCustomObject]@{
                Scope = $role.Scope
                Inherited = if ($role.Scope -ne "/subscriptions/$($sub.Id)") {
                    $true
                } else {
                    $false
                }
                InheritedFrom = if ($role.Scope -ne "/subscriptions/$($sub.Id)") {
                    $role.Scope
                } else {
                    $null
                }
                DisplayName = $role.DisplayName
                SignInName = $role.SignInName
                ObjectId = $role.ObjectId
                ObjectType = if ($role.ObjectType -eq "Unknown") {
                    "Orphaned"
                } else {
                    $role.ObjectType
                }
                RoleDefinitionName = $role.RoleDefinitionName
            }

        }

        $role_assigment_data_subscriptions[$sub.Id] = $role_assigments

    }

    foreach ($mg in $list_managementgroups) {

        write-Host "Exporting Role Assignments from Management Group: $($mg.DisplayName) ($($mg.Id))"

        $list_role = Get-AzRoleAssignment -Scope "$($mg.Id)" -AtScope

        $role_assigments = @()

        foreach ($role in $list_role) {

            $role_assigments += [PSCustomObject]@{
                Scope = $role.Scope
                Inherited = if ($role.Scope -ne "$($mg.Id)") {
                    $true
                } else {
                    $false
                }
                InheritedFrom = if ($role.Scope -ne "$($mg.Id)") {
                    $role.Scope
                } else {
                    $null
                }
                DisplayName = $role.DisplayName
                SignInName = $role.SignInName
                ObjectId = $role.ObjectId
                ObjectType = if ($role.ObjectType -eq "Unknown") {
                    "Orphaned"
                } else {
                    $role.ObjectType
                }
                RoleDefinitionName = $role.RoleDefinitionName
            }

        }

        $role_assigment_data_management_groups[$mg.Id] = $role_assigments

    }

    $role_assigment_export = [PSCustomObject]@{
        ManagementGroup = [PSCustomObject]$role_assigment_data_management_groups
        Subscription = [PSCustomObject]$role_assigment_data_subscriptions
    }

    if (-not (Test-Path -Path $ReferenceFile)) {
        Write-Warning "Reference file '$ReferenceFile' not found. Skipping drift comparison."
        return $role_assigment_export
    }

    $reference_export = Get-Content -Path $ReferenceFile -Raw | ConvertFrom-Json

    $drift_result = [ordered]@{
        ManagementGroup = [ordered]@{}
        Subscription = [ordered]@{}
    }

    foreach ($section in 'ManagementGroup', 'Subscription') {

        $current_section = $role_assigment_export.$section
        $reference_section = $reference_export.$section

        $current_ids = @()
        if ($current_section) { $current_ids = @($current_section.PSObject.Properties.Name) }

        $reference_ids = @()
        if ($reference_section) { $reference_ids = @($reference_section.PSObject.Properties.Name) }

        $all_ids = @($current_ids + $reference_ids) | Select-Object -Unique

        foreach ($id in $all_ids) {

            $current_assignments = @()
            if ($current_ids -contains $id) { $current_assignments = @($current_section.$id) }

            $reference_assignments = @()
            if ($reference_ids -contains $id) { $reference_assignments = @($reference_section.$id) }

            $id_diff = Compare-AzRoleAssignmentSet -ReferenceAssignments $reference_assignments -CurrentAssignments $current_assignments

            if ($id_diff.Count -gt 0) {
                $drift_result[$section][$id] = $id_diff
            }
        }
    }

    $drift_output = [PSCustomObject]@{
        ManagementGroup = [PSCustomObject]$drift_result.ManagementGroup
        Subscription = [PSCustomObject]$drift_result.Subscription
    }

    $drift_output | ConvertTo-Json -Depth 6 | Out-File -FilePath $DriftOutputFile -Encoding utf8

    $total_changes = ($drift_result.ManagementGroup.Values + $drift_result.Subscription.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
    Write-Host "Drift detection complete. $total_changes change(s) found. Details written to $DriftOutputFile"

    return $drift_output | ConvertTo-Json -Depth 6

