# Platform team Terraform

**Platform team only.** Workload teams use separate repos — not managed here.

## What this repo creates

| Resource | Module |
|----------|--------|
| Org folders (Platform, Dev, Prod) | `org-folders` |
| OU policies (allowed regions, no SA keys, bucket rules) | `folder-policies` |
| Shared VPC per environment (dev, prod) | `shared-network` |
| Team GCP projects + SA + WIF | `workload-project` |

## What platform does NOT create

- Application buckets, GKE, Cloud Run (workload team repos)
- Per-team VPCs (teams use shared VPC subnets)

## Modules

```text
envs/dev/main.tf
└── platform-layout
      ├── org-folders
      ├── folder-policies (dev, prod OUs)
      ├── shared-networks (dev, prod — one shared VPC each)
      └── workload-project (for_each team in map)
            └── workspace-identity (SA + WIF)
```

## Onboard a team

Add to `workload_projects` in `envs/dev/main.tf` with `shared_network_key = "dev"`.

Apply → hand off outputs to team for TFE env vars and `project_id` for their repo.
