# Workload project (platform-provisioned)

Platform creates for each team:

- GCP project under Dev/Prod folder  
- Attach to environment **shared VPC** (service project)  

**Subnet isolation:** `roles/compute.networkUser` is granted on **only this team's subnet(s)** to `serviceProject:PROJECT_ID`. The VPC is shared; other teams' subnets are not usable from this project.

**Commented out (for now):** team SA + WIF (`module.identity`). Uncomment when each team has its own TFE workspace.
