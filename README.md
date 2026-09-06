PowerShell.IGA.AccessGuard
An Identity Governance and Administration (IGA) solution for managing Azure Role-Based Access Control (RBAC) role assignments.

The tool enables security and cloud engineering teams to maintain strict access compliance across Azure scopes (Subscriptions, Resource Groups, and Resources) through declarative configuration management.

Capabilities
📤 Role Assignment Export
Discovers and exports active RBAC role assignments across any target Azure scope into structured configuration files (JSON or YAML), creating a clear baseline of actual environment permissions.

🔍 Drift Reporting
Analyzes the live Azure access state against desired configuration files to identify permission drift, missing assignments, or unauthorized privilege creep.

🛡️ Non-Declared Role Enforcement & Override
Enforces compliance by reconciling target Azure scopes to match the desired state configuration. Automatically revokes and overrides any active role assignments that are not explicitly authorized and declared in the configuration file.

Governance & Compliance Use Cases
Continuous Compliance Audit: Periodically inspect cloud environments for access drift away from enterprise security policies.

Zero-Trust Access Control: Ensure no unauthorized or stale access remains active on critical subscriptions or resource groups.

CI/CD Pipeline Integration: Validate access control changes alongside infrastructure deployments.
