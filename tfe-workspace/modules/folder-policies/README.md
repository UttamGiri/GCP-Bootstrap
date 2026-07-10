# Folder (OU) policies

Org policy constraints applied at the **Dev** or **Prod** folder level by the platform team.

| Policy | Constraint | Effect |
|--------|------------|--------|
| Resource locations | `gcp.resourceLocations` | Only allowed regions (default: US) |
| No SA keys | `iam.disableServiceAccountKeyCreation` | Workload teams cannot create JSON keys |
| Uniform bucket access | `storage.uniformBucketLevelAccess` | Buckets must use uniform access |

Defines **what workload teams are allowed to create** under that OU. Workload teams do not manage these policies.
