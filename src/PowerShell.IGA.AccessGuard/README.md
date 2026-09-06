# PowerShell.IGA.AccessGuard

This directory contains the source code for the **PowerShell.IGA.AccessGuard** module.

For detailed documentation, function parameters, and usage examples, please refer to the project's root [README.md](../../README.md).

## Module Public Functions

- `Export-AzRoleAccessGuard` — Export Azure RBAC baseline snapshot (JSON, HTML, CSV).
- `Invoke-AzRoleAccessGuardDrifft` — Compare live Azure state against baseline reference and report drift.
- `Update-AzRoleAccessGuard` — Reconcile Azure RBAC assignments to state declared in drift report.
- `Clear-AzRoleOrphaned` — Discover and remove orphaned role assignments for deleted principals.
