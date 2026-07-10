# Workload project (platform-provisioned)

Platform creates for each team:

- GCP project under Dev/Prod folder  
- Attach to environment **shared VPC** (service project)  

**Subnet isolation:** `roles/compute.networkUser` is granted on **only this team's subnet(s)** to `serviceProject:PROJECT_ID`.

**Human users:** optional `human_users` map grants GCP project IAM on **this team project only** (e.g. one user on team A, none on team B).

**Object storage:** optional `storage_buckets` creates GCS buckets in **this team project only**.

**Identity (optional):** set `enable_identity = true` + `tfe_workspace_id` to create team SA + WIF for a dedicated TFE workspace.
