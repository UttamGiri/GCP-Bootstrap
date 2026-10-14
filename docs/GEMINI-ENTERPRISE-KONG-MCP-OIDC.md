# Gemini Enterprise → Kong AI Gateway → MCP (Jira & third-party tools)

Architecture and setup flow for a **new Gemini Enterprise workload** with **discovery**, **Model Armor**, **file upload (RAG)**, and **Kong AI Gateway** as the MCP front door. Third-party MCP servers (Jira, ServiceNow, internal APIs) sit **behind** Kong’s **MCP registry / passthrough** pattern. **Central OIDC** at Kong gives one identity path to many MCP servers and tools.

This doc is diagram-first. Terraform for Kong on AWS/GCP in this repo is separate ([VERTEX-KONG-AWS-IRSA-WIF.md](VERTEX-KONG-AWS-IRSA-WIF.md)).

**GCP workload:** use the dedicated **`gfg`** project ([DESIGN-WORKLOAD-GFG.md](DESIGN-WORKLOAD-GFG.md), Terraform [tfe-workspace/workloads/gfg/](../tfe-workspace/workloads/gfg/)). Enable in [tfe-workspace/envs/dev/workload-gfg.tf](../tfe-workspace/envs/dev/workload-gfg.tf) (`enabled = true`). All resources and methods: [workloads/gfg/README.md](../tfe-workspace/workloads/gfg/README.md).

---

## Reference docs (pull latest before build)

| Area | Google / Kong doc |
|------|-------------------|
| Gemini Enterprise quickstart & data stores | [Get started with Gemini Enterprise](https://cloud.google.com/gemini/enterprise/docs/quickstart-gemini-enterprise) |
| Custom MCP server connector | [Set up custom MCP server data store](https://cloud.google.com/gemini/enterprise/docs/connectors/custom-mcp-server/set-up-custom-mcp-server) |
| File upload / GCS / RAG | [Prepare data for custom data sources](https://cloud.google.com/gemini/enterprise/docs/connectors/prepare-data), [Create custom connector](https://cloud.google.com/gemini/enterprise/docs/connectors/create-custom-connector) |
| MCP discovery & Agent Registry | [Google Cloud MCP overview](https://cloud.google.com/mcp/overview) |
| Model Armor on Agent Gateway | [Configure Model Armor on a gateway](https://cloud.google.com/gemini-enterprise-agent-platform/govern/configure-model-armor) |
| Model Armor floor settings (MCP) | [Integrate Model Armor with MCP](https://cloud.google.com/model-armor/model-armor-mcp-google-cloud-integration) |
| Kong OIDC | [OpenID Connect with AI Gateway 2.0](https://developer.konghq.com/ai-gateway/openid-connect/) |
| Kong MCP servers | [AI MCP Server entity](https://developer.konghq.com/ai-gateway/entities/ai-mcp-server/) |
| Kong auth strategies | [AI Auth Strategies](https://developer.konghq.com/ai-gateway/entities/ai-auth-strategy/) |

---

## Best-practice checklist (must-haves)

| Requirement | What to do |
|-------------|------------|
| **Discovery enabled** | Register MCP servers in **Agent Registry** (GCP) and/or expose `tools/list`, `prompts/list`, `resources/list` through Kong so Gemini can import tools as **actions** (custom MCP store supports Streamable HTTP only, HTTPS, often `/mcp`). |
| **Model Armor** | Enable on **Agent Gateway** (ingress + egress). Set **floor settings** for Google MCP with `INSPECT_AND_BLOCK` on `tools/call` and `prompts/get` payloads. |
| **File upload / RAG** | Production: stage docs in **GCS**, create Discovery Engine **data store**, initial **full reconciliation**, then **incremental** sync; enable **ACL** if docs are sensitive (`aclEnabled: true` + metadata). |
| **Kong MCP endpoint** | One HTTPS MCP URL per environment (e.g. `https://kong-ai.example.com/mcp`) — Gemini Enterprise custom MCP **Server URL** points here, not directly to Jira. |
| **MCP registry + third-party servers** | Kong **listener** / **passthrough-listener** / **upstream-server** modes: registry aggregates tools; upstream MCP servers (Jira MCP, etc.) registered behind Kong. |
| **Central OIDC** | Single **openid-connect** AI Auth Strategy on Kong (one IdP per gateway); attach to each MCP server via `access.auth_strategies`; use `access.metadata` for OAuth 2.1 resource-server behavior (audience, protected-resource metadata). |

---

## High-level architecture

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart TB
    subgraph Users["Users"]
        U["Analyst in Gemini Enterprise chat"]
    end

    subgraph GE["Gemini Enterprise (Discovery Engine app)"]
        APP["Gemini Enterprise app"]
        DS_DOC["Data store: GCS documents RAG"]
        DS_MCP["Data store: Custom MCP server URL"]
        AGENT["Optional custom agent"]
    end

    subgraph Gov["Governance"]
        GW_IN["Agent Gateway ingress"]
        MA_IN["Model Armor ingress templates"]
        GW_EG["Agent Gateway egress"]
        MA_EG["Model Armor egress templates"]
    end

    subgraph Kong["Kong AI Gateway"]
        OIDC["AI Auth Strategy openid-connect"]
        MCP_EP["AI MCP Server listener<br/>https://kong-ai/mcp"]
        REG["MCP tool aggregation registry"]
        JIRA_UP["upstream-server: Jira MCP"]
        OTHER_UP["upstream-server: Other MCP"]
    end

    subgraph IdP["Central identity"]
        IDP["OIDC IdP<br/>Okta / Entra / Google Workforce"]
    end

    subgraph Third["Third-party MCP servers"]
        JIRA["Jira MCP server"]
        SVC["ServiceNow / internal MCP"]
    end

    U --> APP
    APP --> DS_DOC
    APP --> DS_MCP
    APP --> AGENT

    APP --> GW_IN
    GW_IN --> MA_IN
    MA_IN --> GW_EG
    GW_EG --> MA_EG
    MA_EG --> MCP_EP

    DS_MCP -->|"HTTPS Streamable HTTP /mcp"| MCP_EP

    MCP_EP --> OIDC
    OIDC --> IDP
    MCP_EP --> REG
    REG --> JIRA_UP
    REG --> OTHER_UP
    JIRA_UP --> JIRA
    OTHER_UP --> SVC

    DS_DOC -.->|"tools/list not scanned"| MA_EG
    MCP_EP -.->|"tools/call sanitized"| MA_EG
```

---

## Setup flow (greenfield workload)

```mermaid
%%{init: {'theme': 'neutral'}}%%
sequenceDiagram
    autonumber
    participant Admin as Platform admin
    participant GCP as GCP project
    participant GCS as Cloud Storage
    participant GE as Gemini Enterprise
    participant MA as Model Armor
    participant Kong as Kong AI Gateway
    participant IdP as OIDC IdP
    participant MCP as Third-party MCP servers

    Admin->>GCP: Enable APIs Discovery Engine Gemini Enterprise Model Armor IAM
    Admin->>MA: Floor settings GOOGLE_MCP_SERVER INSPECT_AND_BLOCK
    Admin->>MA: Agent Gateway ingress egress templates same region

    Admin->>GCS: Upload docs plus ACL metadata JSONL
    Admin->>GE: Create unstructured data store GCS import full then incremental
    Admin->>GE: Connect data store to app enable identity ACL mapping

    Admin->>Kong: Create openid-connect AI Auth Strategy issuer discovery URL
    Admin->>Kong: Deploy AI MCP Server listener mode HTTPS /mcp
    Admin->>Kong: access.auth_strategies plus access.metadata OAuth2.1 RS
    Admin->>MCP: Deploy Jira MCP and others with their own OAuth to Atlassian
    Admin->>Kong: Register upstream-server MCP entries tools_list_auth to upstream
    Admin->>Kong: Aggregate tools in registry namespace per team

    Admin->>GE: Custom MCP data store Server URL https://kong-ai/mcp
    Admin->>GE: Authorization URL IdP or MCP OAuth as designed
    Admin->>GE: Enable Model Armor on connector import tools as actions
    Admin->>GE: Enable discovery tools/list import up to action limits

    Note over GE,Kong: Gemini only sees Kong URL not raw Jira URL
```

---

## Chat example: “Call Jira ticket PROJ-1234”

What happens when the user types in **Gemini Enterprise chat**: *“Call Jira and get details for ticket PROJ-1234”* (or *“call jira number PROJ-1234”*).

```mermaid
%%{init: {'theme': 'neutral'}}%%
sequenceDiagram
    autonumber
    participant User as User
    participant GE as Gemini Enterprise
    participant LLM as Gemini model
    participant GW as Agent Gateway
    participant MA as Model Armor
    participant Kong as Kong AI MCP endpoint
    participant IdP as OIDC IdP
    participant JiraMCP as Jira MCP upstream

    User->>GE: Natural language call jira ticket PROJ-1234
    GE->>LLM: Plan plus prior RAG from file data store optional
    LLM->>GE: Choose action jira_get_issue PROJ-1234

    GE->>GW: MCP tools/call request egress
    GW->>MA: Inspect tools/call payload prompt injection PII
    alt Blocked by Model Armor
        MA-->>User: Policy violation message no tool call
    else Allowed
        MA->>Kong: Forward tools/call Streamable HTTP
        Kong->>IdP: Validate Bearer JWT from user or service delegation
        alt Invalid or expired token
            IdP-->>User: 401 via GE need sign-in
        else Valid token claims scopes audience
            Kong->>Kong: Map JWT to AI Consumer rate limit audit
            Kong->>JiraMCP: Route to jira_get_issue upstream auth
            Note over Kong,JiraMCP: Upstream uses tools_list_auth<br/>Atlassian OAuth for Jira MCP
            JiraMCP->>JiraMCP: Atlassian API GET issue PROJ-1234
            JiraMCP-->>Kong: MCP tool result JSON
            Kong-->>MA: tools/call response
            MA->>MA: Sanitize response leakage injection
            MA-->>GE: Safe tool output
            GE->>LLM: Summarize for user
            LLM-->>User: PROJ-1234 summary status assignee link
        end
    end
```

**Discovery vs execution**

| MCP method | Model Armor | Used when |
|------------|-------------|-----------|
| `tools/list`, `prompts/list`, `resources/list` | Not sanitized | Gemini **discovers** Jira tool names and schemas |
| `tools/call`, `prompts/get` | **Sanitized** | User message triggers **execution** |
| Tool execution errors | Sanitized | Malicious MCP tool error text |

---

## Central OIDC at Kong (one IdP, many MCP servers)

Goal: users authenticate **once** (or SSO session); Kong validates **every** MCP call with the same **openid-connect** strategy; optional **per-tool** authorization via claims (groups, scopes).

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart LR
    subgraph IdP["Single OIDC IdP"]
        DISC["/.well-known/openid-configuration"]
        AUTH["/authorize"]
        TOKEN["/token"]
        JWKS["/jwks"]
    end

    subgraph Kong["Kong AI Gateway one gateway one OIDC strategy"]
        STRAT["AI Auth Strategy openid-connect<br/>config.issuer discovery URL<br/>config.auth_methods bearer"]
        MCP1["MCP listener team-a /mcp/team-a"]
        MCP2["MCP listener team-b /mcp/team-b"]
        UP1["upstream Jira MCP"]
        UP2["upstream HR MCP"]
    end

    subgraph GE["Gemini Enterprise"]
        CONN["Custom MCP connector<br/>Authorization URL + client"]
    end

    GE -->|"User OAuth or token exchange per design"| AUTH
    AUTH --> IdP
    GE -->|"tools/call Bearer access_token"| MCP1
    MCP1 --> STRAT
    MCP2 --> STRAT
    STRAT --> JWKS
    STRAT -->|"valid claims"| UP1
    STRAT -->|"valid claims"| UP2

    MCP1 --> UP1
    MCP2 --> UP2
```

### Kong OIDC configuration pattern

1. **Create one** `openid-connect` **AI Auth Strategy** per AI Gateway (Kong docs: do not mix multiple OIDC providers on the same gateway).
2. Set `config.issuer` to your IdP discovery URL (Okta, Microsoft Entra, Google Workforce, etc.).
3. For each **AI MCP Server** in `conversion-listener`, `listener`, or `passthrough-listener` mode:
   - Set `access.auth_strategies: [<strategy name>]`.
   - Set `access.metadata` when you need **OAuth 2.1 resource server** behavior (protected resource metadata, **audience** validation for MCP clients).
4. **Upstream** Jira MCP: authenticate separately with `config.server.tools_list_auth` (Atlassian OAuth/API token) — this is **service-to-service**, not the end-user OIDC token.

### Gemini Enterprise ↔ Kong auth (two layers)

| Layer | Who | Typical mechanism |
|-------|-----|-------------------|
| **User → Gemini → Kong** | Human analyst | OIDC: Gemini custom MCP store **Authorization URL** + OAuth client; user consents; GE sends Bearer on MCP calls |
| **Kong → Jira MCP** | Platform | Upstream credentials, mTLS, or Atlassian OAuth on MCP server |
| **Optional service account** | Batch / agent | Client credentials or WIF-style token if your IdP supports it for non-interactive agents |

---

## File upload path (RAG) alongside MCP tools

Documents and **live tools** are separate data stores in Gemini Enterprise; both attach to the same app.

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart LR
    subgraph Ingest["Ingestion best practice"]
        SRC["HR policy PDFs APIs export"]
        STG["GCS bucket staging"]
        META["JSONL metadata plus acl_info"]
        IMP["ImportDocuments full reconciliation"]
        INC["Incremental sync schedule"]
    end

    subgraph GE["Gemini Enterprise"]
        DS["Unstructured data store"]
        CHAT["Chat plus RAG citations"]
    end

    SRC --> STG
    META --> STG
    STG --> IMP --> DS
    STG --> INC --> DS
    DS --> CHAT

    subgraph Tools["Actions MCP via Kong"]
        MCP["Custom MCP data store"]
    end

    MCP --> CHAT
```

**Practice:** initial **full** sync from GCS, then **incremental** for changes; enable **ACL** on the data store so chat only retrieves files the user may read ([identity mapping](https://cloud.google.com/gemini/enterprise/docs/identity)).

---

## Kong MCP registry: where third-party servers live

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart TB
    subgraph Registry["Logical MCP registry on Kong"]
        L["AI MCP Server listener public URL"]
        P1["passthrough or conversion for vendor A"]
        P2["passthrough or conversion for vendor B"]
        U1["upstream-server Jira MCP cluster"]
        U2["upstream-server Custom internal MCP"]
    end

    subgraph External["Outside Kong cluster"]
        J["Atlassian Jira Cloud MCP"]
        I["Internal legacy MCP on VPC"]
    end

    L --> P1 --> U1 --> J
    L --> P2 --> U2 --> I

    Note1["Gemini discovers merged tool list from Kong endpoint"]
    L --- Note1
```

| Kong MCP mode | Role |
|---------------|------|
| **listener** | Public MCP HTTP entry; OIDC on `access.auth_strategies` |
| **passthrough-listener** | Forward MCP to one upstream with minimal conversion |
| **upstream-server** | Defines remote MCP URL + **tools_list_auth** for discovery calls |
| **conversion-listener** | Normalize non-standard MCP for Gemini Streamable HTTP |

Register each third-party MCP once; expose **one** (or few) URLs to Gemini Enterprise.

---

## Model Armor placement (required)

```mermaid
%%{init: {'theme': 'neutral'}}%%
flowchart LR
    subgraph Ingress["Client to agent"]
        P1["User prompt"] --> MA1["Model Armor ingress"]
        MA1 --> A["Agent / Gemini"]
    end

    subgraph Egress["Agent to anywhere"]
        A --> T["MCP tools/call"] --> MA2["Model Armor egress"]
        MA2 --> K["Kong MCP"]
        K --> R["Tool response"] --> MA2
        MA2 --> A
    end
```

**Floor setting example (project-wide MCP minimum):**

```bash
gcloud model-armor floorsettings update \
  --full-uri='projects/PROJECT_ID/locations/global/floorSetting' \
  --enable-floor-setting-enforcement=TRUE \
  --add-integrated-services=GOOGLE_MCP_SERVER \
  --google-mcp-server-enforcement-type=INSPECT_AND_BLOCK \
  --enable-google-mcp-server-cloud-logging
```

Also attach **ingress/egress templates** on **Agent Gateway** in the **same region** as templates ([configure Model Armor on a gateway](https://cloud.google.com/gemini-enterprise-agent-platform/govern/configure-model-armor)).

---

## Suggested naming for a new workload

| Component | Example name |
|-----------|----------------|
| GCP project | `gemini-ent-prod` |
| Gemini app | `enterprise-assistant-prod` |
| GCS staging | `gs://gemini-ent-docs-prod/` |
| Kong MCP URL | `https://kong-ai.company.com/mcp/enterprise` |
| OIDC audience | `mcp://kong-ai/enterprise` (match `access.metadata`) |
| Jira upstream | `jira-cloud-mcp` behind `upstream-server` |

---

## Security summary

- **Gemini** never holds Atlassian admin keys; **Jira MCP** does, scoped minimally.
- **Users** never call Jira MCP directly; all traffic **Kong + Model Armor**.
- **OIDC** centralizes **who** can invoke MCP; Kong **AI Consumer** mapping enables audit and rate limits.
- **Discovery** (`tools/list`) is allowed without payload sanitization — still restrict **network** access to Kong and **register** only trusted upstream MCP servers.

---

## Next steps in this repo (optional)

- Reuse Kong on EKS patterns from [VERTEX-KONG-AWS-IRSA-WIF.md](VERTEX-KONG-AWS-IRSA-WIF.md) for **Google token to Vertex**; add **separate routes** for **MCP listener** (different plugin chain: OIDC + MCP, not Vertex WIF).
- Add Terraform modules for Kong `AI MCP Server` + `AI Auth Strategy` when Kong config is codified.

---

## Quick test matrix

| Test | Pass criteria |
|------|----------------|
| Discovery | `tools/list` via Kong returns Jira + other tools |
| OIDC | Missing Bearer → 401; valid JWT → 200 on `tools/call` |
| Model Armor | Prompt injection in tool args blocked on egress |
| RAG | Uploaded GCS doc cited in chat; ACL user B cannot see user A doc |
| Jira E2E | Chat “PROJ-1234” returns issue JSON summarized correctly |
