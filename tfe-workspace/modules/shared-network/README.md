# Shared VPC (per environment)

Platform creates **one shared VPC host project per environment** (Dev, Prod). Workload team projects attach as **service projects** and use subnets from here — they do not create their own VPC.

```text
Dev/
  vaflt-shared-net-dev/     ← host project (this module)
    shared-vpc-dev
    subnets: workload-a, workload-b, ...
  workload-a-dev-prj        ← service project (workload-project module)
  workload-b-dev-prj        ← service project
```

Workload teams consume shared networking only. They do not create VPCs in their repos.
