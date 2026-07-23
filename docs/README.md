# Documentation fixed

| Document | Description |
|----------|-------------|
| [BOOTSTRAP-FLOW.md](BOOTSTRAP-FLOW.md) | Initial Cloud Shell bootstrap and TFE state import |
| [DAILY-WORKSPACE-FLOW.md](DAILY-WORKSPACE-FLOW.md) | Daily destroy/apply, identity handoff, and naming rules |
| [TFE-WEBHOOK-GITHUB.md](TFE-WEBHOOK-GITHUB.md) | Why TFE cannot call GitHub directly and what works instead |
| [PROVIDER-VERSION-ERROR.md](PROVIDER-VERSION-ERROR.md) | Provider version mismatch error, fix, downgrade policy, and demo steps for this repo |
| [CONFLUENCE-DOCS-SYNC.md](CONFLUENCE-DOCS-SYNC.md) | Publish docs to Confluence via GitHub Actions (setup, secrets, page mapping) |

Module-specific READMEs remain next to their Terraform code (`terraform-bootstrap/`, `tfe-workspace/`).

## Confluence sync

Markdown in this folder syncs to Confluence via `.github/workflows/confluence-docs-sync.yml`.

- Setup guide: [CONFLUENCE-DOCS-SYNC.md](CONFLUENCE-DOCS-SYNC.md)
- Page IDs: [confluence/page-mapping.json](confluence/page-mapping.json)
