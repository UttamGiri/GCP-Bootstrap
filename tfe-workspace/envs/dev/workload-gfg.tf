locals {
  gfg_config = {
    enabled         = false
    create_project  = true
    project_id      = "vaflt-workload-gfg-1"
    project_name    = "gfg"
    description     = "Gemini Enterprise app: Discovery Engine data stores, GCS document RAG, Model Armor, custom MCP via Kong AI Gateway (Jira and third-party tools), central OIDC."
    org_id          = "327947404107"
    billing_account = "01BC6F-241F9A-8762DE"
    attach_shared_vpc = false
    impersonators   = []
  }
}
