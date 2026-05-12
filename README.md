# ARC-1 ABAP CI/CD review

End-to-end demo: SAP ABAP changes pushed via abapGit to GitHub, then
reviewed by a combination of static lint, GitHub Copilot, and Claude —
all wired to [ARC-1](https://github.com/marianfoo/arc-1) as an MCP
server so the AI reviewers can see the **live SAP system**, not just
the diff text.

> Companion to **[ARC-1 ABAP CI/CD review — blog post](https://blog.zeis.de/posts/2026-05-12-arc-1-abap-cicd-review/)**.

## What you'll see in this repo

- **[PR #14](https://github.com/marianfoo/arc-1-abap-cicd-review/pull/14)** —
  one diff reviewed by four different surfaces side-by-side:
  abaplint (static), Copilot Code Review (AI, no MCP),
  Copilot Coding Agent (AI + MCP), Claude (AI + MCP).
- **[Issues labelled `sap:dump`](https://github.com/marianfoo/arc-1-abap-cicd-review/issues?q=is%3Aissue+label%3Asap%3Adump)** —
  autonomous Claude agent triages ST22 short dumps, opens one issue
  per new dump with a hypothesis and an urgency label.
- **Five workflows** in [`.github/workflows/`](.github/workflows/),
  all sharing the same ARC-1 MCP backend:
  - `pr.yml` — abaplint via reviewdog
  - `sap-tests.yml` — ABAP Unit tests + ATC on every PR (deterministic, no AI)
  - `copilot-review-trigger.yml` — label-triggered Copilot review
  - `claude-review-trigger.yml` — label-triggered Claude review
  - `sap-dump-triage.yml` — scheduled / manual dump triage (shallow)
  - `sap-dump-deep-dive.yml` — label-triggered deep-dive on a dump issue

## Architecture

```
┌────────────────────┐     abapGit     ┌────────────────────────┐
│ SAP test system    │ ──────push────▶ │ GitHub: this repo      │
│ ZARC1_DEMO         │ ◀─────pull───── │ PR + autonomous agent  │
└────────────────────┘                 └────────┬───────────────┘
        ▲                                       │
        │ HTTPS (MCP, viewer-sql)               ▼
   ┌────┴────┐                          ┌────────────────────────┐
   │ ARC-1   │ ◀──────(MCP)──────────── │ GitHub Actions         │
   │ BTP CF  │                          │  abaplint              │
   └─────────┘                          │  Copilot Coding Agent  │
                                        │  Claude Code Action    │
                                        │  Dump-triage agent     │
                                        └────────────────────────┘
```

Three review patterns, one MCP backend:

| Pattern | Trigger | Workflow |
|---|---|---|
| reactive on push | PR opened / updated | `pr.yml` |
| reactive on user action | label / mention | `copilot-review-trigger.yml`, `claude-review-trigger.yml` |
| proactive on schedule | cron | `sap-dump-triage.yml` |

## Sample package (`ZARC1_DEMO`)

| Object | Name | Purpose |
|---|---|---|
| DEVC | `ZARC1_DEMO` | Package root |
| DOMA | `ZARC1_D_STATUS` | char1, fixed values A/D/X |
| DTEL | `ZARC1_E_STATUS` | data element on the domain |
| MSAG | `ZARC1_TASK` | user-facing messages |
| TABL | `ZARC1_T_TASK` | task storage |
| INTF | `ZIF_ARC1_TASK_SERVICE` | service contract |
| CLAS | `ZCL_ARC1_TASK_SERVICE` | implementation + local test class |
| PROG | `ZARC1_TASK_LIST` | SELECT-OPTIONS report → SALV |

## Setup

### 1. SAP-side

- Install abapGit (`ZABAPGIT` or `ZABAPGIT_STANDALONE`).
- Trust GitHub's current TLS chain in `STRUST` → SSL Client (Standard).
  Verify the live chain first:
  ```bash
  openssl s_client -servername github.com -connect github.com:443 -showcerts
  ```
  Only the **intermediate + root** need to be in the PSE — the leaf
  rotates every ~90 days automatically.
- Generate a GitHub Personal Access Token (fine-grained, `Contents: read/write`
  on this repo) and register it in the abapGit UI for HTTPS push.
- Create the package + objects above (Eclipse/SE80, or scripted with
  the ARC-1 CLI — see [docs](https://github.com/marianfoo/arc-1)).

### 2. ARC-1 instance

Deploy ARC-1 on SAP BTP Cloud Foundry (the [ARC-1 README](https://github.com/marianfoo/arc-1)
walks through this). Mint an API key with the **`viewer-sql`**
profile:

```bash
cf set-env <arc-1-app> ARC1_API_KEYS "<key>:viewer-sql"
cf restage <arc-1-app>
```

Note the public URL (`https://<arc-1-app>.cfapps.<region>.hana.ondemand.com`).

### 3. GitHub-side secrets/vars

Repo → Settings → Secrets and variables → Actions:

| Type | Name | Value |
|---|---|---|
| Variable | `ARC1_URL` | the ARC-1 public URL from step 2 |
| Secret | `ARC1_API_KEY` | the viewer-sql API key |
| Secret | `ANTHROPIC_API_KEY` | from [console.anthropic.com](https://console.anthropic.com) |
| Secret | `COPILOT_TRIGGER_PAT` | fine-grained PAT, this repo only, `Pull requests: read/write` + `Contents: read` |

### 4. Copilot Coding Agent (optional but recommended)

Repo → Settings → Code & automation → Copilot → Cloud agent:

- **MCP configuration**:
  ```json
  {
    "mcpServers": {
      "arc-1": {
        "type": "http",
        "url": "https://<your-arc-1-host>/mcp",
        "headers": { "Authorization": "Bearer $COPILOT_MCP_ARC1_API_KEY" },
        "tools": ["SAPRead","SAPSearch","SAPNavigate","SAPContext","SAPDiagnose","SAPLint","SAPQuery"]
      }
    }
  }
  ```
  The `tools` array is an **explicit allowlist** — Copilot calls MCP
  tools without per-call approval, so write tools are omitted.
- **Custom allowlist** (Internet access): add the ARC-1 host so
  Copilot's firewall lets it through.
- **Agent secrets**: `COPILOT_MCP_ARC1_API_KEY` (same value as
  `ARC1_API_KEY` above — the `COPILOT_MCP_` prefix is required by
  GitHub).

### 5. Claude (optional, parallel to Copilot)

Two ways:

- **CI workflow** — uses [`anthropics/claude-code-action@v1`](https://github.com/anthropics/claude-code-action),
  already wired up in `claude-review-trigger.yml`. Reads `ANTHROPIC_API_KEY`
  + the ARC-1 secrets from step 3. No GitHub App install needed.
- **`@claude` mention** — install the [Claude GitHub App](https://github.com/apps/claude),
  configure ARC-1 in the app's per-repo settings. Lets you ask
  questions in PR comments without firing a workflow.

## Use

### Static lint on every PR — automatic

Every PR fires [`pr.yml`](.github/workflows/pr.yml). abaplint runs via
[reviewdog](https://github.com/reviewdog/reviewdog) and posts findings
as:

- inline review comments on changed lines (Files Changed tab),
- a sticky summary comment for findings on unchanged files
  (Conversation tab),
- a Check Run with annotations (Checks tab).

The job fails on any abaplint error **introduced by the PR diff** —
pre-existing tech debt stays visible in the sticky comment but does
not gate new PRs.

### SAP unit tests + ATC on every PR — automatic, deterministic

[`sap-tests.yml`](.github/workflows/sap-tests.yml) runs on every PR
touching `src/`. For each changed object:

- **CLAS** → ABAP Unit tests via `SAPDiagnose(action="unittest")`
- **CLAS / INTF / PROG / FUGR** → ATC via `SAPDiagnose(action="atc")`

Findings post as:

- a sticky summary comment (Conversation tab),
- inline review comments on the diff for line-specific ATC findings
  (Files Changed tab).

Gates the merge on **any failing/erroring unit test** OR **any P1/P2
ATC finding**. No AI cost — pure bash + ARC-1 over MCP. Uses the same
`viewer-sql` API key as the AI review workflows.

### AI review on demand — labels

| Label | Surface | Notes |
|---|---|---|
| (sidebar → Reviewers → Copilot) | Copilot Code Review | Reviews from diff only; no MCP. |
| `copilot:review` | Copilot Coding Agent + ARC-1 MCP | Workflow posts a `@copilot` comment that fires the agent. |
| `claude:review` | Claude Code Action + ARC-1 MCP | Workflow runs Claude in CI; posts review with inline comments + Apply-suggestion buttons. |

The label triggers a workflow that auto-removes the label after firing,
so re-applying re-triggers.

Both AI reviewers can post **inline suggestions with an "Apply" button**
just like a human reviewer's suggestions — see PR #14 for examples.

### Autonomous dump triage — scheduled (or manual)

[`sap-dump-triage.yml`](.github/workflows/sap-dump-triage.yml) runs
Claude on a schedule (currently `workflow_dispatch` only — enable the
cron block in the file for autonomous mode). Each run:

1. Lists ST22 short dumps via `SAPDiagnose(action="dumps")`.
2. Dedupes against existing `sap:dump` issues (HTML-comment marker
   `<!-- dump-id: ... -->`).
3. Opens **one issue per new dump** with a 2–4 sentence triage,
   citing the ARC-1 tool results, and an urgency label per the
   rubric in [`.github/sap-dump-triage-prompt.md`](.github/sap-dump-triage-prompt.md):
   - `urgency:high` — background / cron / security / recurrence
   - `urgency:medium` — user-facing transient (default)
   - `urgency:low` — dev-tool/ADT/debugger noise

Caps: max 5 new dumps per run, `--max-turns 30`. Bounded cost (~$0.30
worst case per run).

### Deep-dive on a dump — label `dump:investigate`

Apply the **`dump:investigate`** label to any `sap:dump` issue and
[`sap-dump-deep-dive.yml`](.github/workflows/sap-dump-deep-dive.yml)
fires. Claude:

1. Extracts the dump ID from the issue body's HTML marker.
2. Pulls the **full** dump text via `SAPDiagnose(includeFullText=true)`.
3. Reads the failing source via `SAPRead` (method-level when possible).
4. Posts ONE comment with root cause + suggested fix + verification
   steps + cited tool calls.
5. Updates labels: `needs-triage` → `dump:investigated`.

Cost is higher than the shallow triage (~$0.50–1.50 per deep-dive)
because full source reads are expensive. That's by design — the
two-stage pattern keeps continuous coverage cheap (Stage 1) and
spends real budget only where it pays off (Stage 2).

## Adapt it for your environment

| Change | Where |
|---|---|
| BTP CF host | `ARC1_URL` repo variable |
| Model | `--model` in workflow `claude_args` |
| Severity rubric | `.github/sap-dump-triage-prompt.md` |
| PR review focus | `.github/claude-review-prompt.md` / `.github/copilot-review-prompt.md` |
| Dump-triage cadence | `cron:` in `sap-dump-triage.yml` (commented out by default) |
| Allowed MCP tools | `--allowedTools` in workflow `claude_args` / Copilot MCP config |
| `abaplint` rules | `abaplint.jsonc` |

## Measured costs (small team baseline)

| Operation | Per call | Volume (5 PRs/day, 10 dumps/day) | Monthly |
|---|---|---|---|
| abaplint via reviewdog | free (Actions minutes) | every PR | $0 |
| Copilot Code Review | included in Copilot subscription | every PR | — |
| Copilot Coding Agent + MCP | included in Copilot subscription, fair-use | label-triggered | — |
| Claude PR review | ~$0.20 | 5 × 22 working days | ~$22 |
| Dump triage (shallow) | ~$0.04 | 10 × 30 days | ~$12 |
| Dump deep-dive | ~$1.00 | ~20 % of dumps | ~$60 |
| ARC-1 BTP CF hosting | flat | always-on | ~$30–50 |
| **Total marginal AI cost** | | | **~$125 / month** |

Compare to one SAP-consultant hour at €80–150 spent triaging dumps or
chasing cross-object regressions: pays for itself in 1–2 hours saved
per week.

## Why each layer earns its keep

- **abaplint** catches the long tail of style + statement-level bugs.
  Run locally too: `npx @abaplint/cli`.
- **Copilot Code Review** (no MCP) is the cheapest AI layer —
  catches well-known anti-patterns from training, but can't
  verify against the live system (and occasionally hallucinates).
- **Coding Agent / Claude + ARC-1 MCP** is the only layer that
  answers questions like *"does this change break callers?"*,
  *"is the active version in SAP already drifting from the PR?"*,
  *"is this BAdI registration already covered by a SAP-standard
  service?"* — questions that need both the surrounding repo and
  the live SAP system as context.
- **Autonomous dump triage** turns silent SAP failures into tracked
  GitHub issues with a 2–4 sentence hypothesis, before users open
  tickets.
