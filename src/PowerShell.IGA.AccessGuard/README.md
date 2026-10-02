# PowerShell.IGA.AccessGuard

This directory contains the source code for the **PowerShell.IGA.AccessGuard** module.

For detailed documentation, function parameters, and usage examples, please refer to the project's root [README.md](../../README.md).

## Module Public Functions

- `Export-AzRoleAccessGuard` — Export Azure RBAC baseline snapshot (JSON, HTML, CSV, or AVM-based Bicep).
- `Invoke-AzRoleAccessGuardDrifft` — Compare live Azure state against baseline reference and report drift.
- `Compare-AzRoleAccessGuardExport` — Compare a full export file against a baseline export file and report differences (no Azure calls).
- `Update-AzRoleAccessGuard` — Reconcile Azure RBAC assignments to state declared in drift report.
- `Clear-AzRoleOrphaned` — Discover and remove orphaned role assignments for deleted principals.

## Publish JUnit Drift Results in Azure DevOps

Run the drift check with `-OutputFormat JUnit` to create `output_diff.xml`, then publish that file
with the Azure DevOps `PublishTestResults@2` task. The agent must have this module installed and be
authenticated to Azure before running the drift command.

```yaml
trigger:
- main

pool:
	vmImage: ubuntu-latest

steps:
- pwsh: |
		$driftParams = @{
			ReferenceFile = "$(Build.SourcesDirectory)/baseline.json"
			OutputFormat = 'JUnit'
			OutputPath = "$(Build.SourcesDirectory)/output_diff"
		}
		Invoke-AzRoleAccessGuardDrifft @driftParams
	displayName: Generate JUnit drift results

- task: PublishTestResults@2
	condition: succeededOrFailed()
	inputs:
		testResultsFormat: JUnit
		testResultsFiles: output_diff.xml
		searchFolder: '$(Build.SourcesDirectory)'
		failTaskOnFailedTests: false
```

The Azure DevOps Tests view displays each drift finding as a test result. For example:

![Azure DevOps published JUnit drift test results](../../image/ado-drifft-test-report-v1.png)
