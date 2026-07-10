# Org Folders

Creates top-level GCP folders under the organization:

```text
vaflt.com (org)
├── Platform/
├── Dev/
└── Prod/
```

Managed from **`tfe-workspace/envs/dev`** (GCP-vaflt-tfe-workspace), authenticated as the **bootstrap service account** on first runs.

`terraform-bootstrap/` is unchanged — it only owns the bootstrap project, bootstrap SA, and bootstrap WIF.

## Bootstrap SA requirement

Folder creation needs org-level permission on `bs-tfe-sa`. Grant once (Console or gcloud):

```bash
gcloud organizations add-iam-policy-binding 327947404107 \
  --member="serviceAccount:bs-tfe-sa@bootstrap-prj-501802.iam.gserviceaccount.com" \
  --role="roles/resourcemanager.folderAdmin"
```

For creating workload projects under folders later, also consider:

- `roles/resourcemanager.projectCreator` (org or folder scope)
- `roles/billing.user` on the billing account

## Using folder IDs

Reference outputs from `module.platform` in the env root:

```hcl
folder_id = module.platform.folder_names["dev"]
```
