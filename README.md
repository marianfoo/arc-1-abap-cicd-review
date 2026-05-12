# ARC-1 ABAP CI/CD review

End-to-end demo: SAP ABAP development → abapGit push → GitHub PR →
automated review (static lint via [abaplint](https://abaplint.org/)
+ semantic AI review via **GitHub Copilot Coding Agent** wired to
[ARC-1](https://github.com/marianfoo/arc-1) as an MCP server).

> Companion to the [Joule Studio + ARC-1 clean-core blog post](https://blog.zeis.de/posts/2026-05-08-arc-1-joule-studio-clean-core/) —
> same toolchain, different surface: this time the LLM lives in the
> GitHub PR instead of Joule Studio.

## Package contents (`ZARC1_DEMO`)

| Object | Name | Purpose |
|---|---|---|
| DEVC | `ZARC1_DEMO` | Package root |
| DOMA | `ZARC1_D_STATUS` | char1, fixed values A/D/X |
| DTEL | `ZARC1_E_STATUS` | data element on the domain |
| MSAG | `ZARC1_TASK` | user-facing messages |
| TABL | `ZARC1_T_TASK` | task storage (client + task_id key) |
| INTF | `ZIF_ARC1_TASK_SERVICE` | service contract |
| CLAS | `ZCL_ARC1_TASK_SERVICE` | implementation + local test class |
| PROG | `ZARC1_TASK_LIST` | SELECT-OPTIONS report → SALV |

A deliberate code-style issue is seeded in `zarc1_task_list.prog.abap`
(chained `DATA: BEGIN OF`) so the PR-workflow has something to flag.
**The "first PR" against this repo is the fix.**

## How it works

```
┌────────────────────┐     abapGit     ┌────────────────────────┐
│ SAP test system    │ ──────push────▶ │ GitHub: this repo      │
│ ZARC1_DEMO         │ ◀─────pull───── │ feature branch         │
└────────────────────┘                 └────────┬───────────────┘
        ▲                                       │ open PR
        │ HTTPS (MCP)                           ▼
        │                              ┌────────────────────────┐
   ┌────┴────┐                         │ GitHub Actions         │
   │ ARC-1   │ ◀──────(MCP)──────────  │  · abaplint            │
   │ BTP CF  │   read-only viewer-sql  │                        │
   └─────────┘                         │ Copilot Coding Agent   │
                                       │  · reads diff          │
                                       │  · calls ARC-1 MCP     │
                                       │  · posts PR review     │
                                       └────────────────────────┘
```

Two review layers, each doing what it's best at:

1. **`abaplint` workflow** — the canonical [abaplint GitHub Action](https://github.com/abaplint/actions-abaplint)
   runs on every PR, annotates findings inline on the diff via the
   Checks API. Config: [`abaplint.jsonc`](abaplint.jsonc), tuned for
   SAP_BASIS 758 / S/4HANA 2023.
2. **GitHub Copilot Coding Agent** with ARC-1 attached as an MCP
   server. When assigned to a PR (manually or via auto-assignment
   in repo Settings), Copilot reads the diff and uses ARC-1 to pull
   the surrounding SAP context that the static lint can't see —
   callers, sibling code, ATC findings, customizing tables, etc.

We deliberately do **not** run a second "ARC-1 SAPLint" job in CI —
it would re-run the same engine on the same files. ARC-1's value-
add is the live-SAP context fed to the LLM reviewer, not duplicate
linting.

## Reproducing this setup

### Prerequisites

- A SAP system with abapGit installed (report `ZABAPGIT` or
  `ZABAPGIT_STANDALONE`).
- GitHub's current TLS chain trusted in `STRUST` → SSL Client
  (Standard). GitHub rotates leaf certs every ~90 days; only the
  **intermediate + root** in the chain need to be in the PSE —
  the leaf rotates automatically. Verify the live chain first:
  ```bash
  openssl s_client -servername github.com -connect github.com:443 -showcerts
  ```
- An ARC-1 instance reachable from GitHub (the BTP CF deployment
  with XSUAA + Destination Service is the easiest).
- A GitHub Personal Access Token registered in abapGit for HTTPS
  push (fine-grained, scope `Contents: read/write` on this repo).
- A GitHub Copilot subscription that includes **Coding Agent**
  (Copilot Pro / Business / Enterprise).

### One-time setup in SAP

1. Create package `ZARC1_DEMO` (transportable, `HOME` SWCV).
2. Create a workbench transport request.
3. Create the objects listed above. Either by hand in Eclipse/SE80,
   or scripted via the ARC-1 CLI:

   ```bash
   node dist/cli.js call SAPTransport --json '{"action":"create",…,"targetPackage":"ZARC1_DEMO"}'
   node dist/cli.js call SAPManage    --json '{"action":"create_package","name":"ZARC1_DEMO","softwareComponent":"HOME","transport":"…"}'
   node dist/cli.js call SAPWrite     --json '{"action":"create","type":"DOMA",…}'
   # … one SAPWrite per object, then SAPActivate.
   ```

### One-time setup in GitHub

**1. Repo → Settings → Copilot → Cloud agent → MCP configuration**

Paste this JSON:

```json
{
  "mcpServers": {
    "arc-1": {
      "type": "http",
      "url": "https://<your-arc-1-host>/mcp",
      "headers": {
        "Authorization": "Bearer $COPILOT_MCP_ARC1_API_KEY"
      },
      "tools": [
        "SAPRead",
        "SAPSearch",
        "SAPNavigate",
        "SAPContext",
        "SAPDiagnose",
        "SAPLint",
        "SAPQuery"
      ]
    }
  }
}
```

The `tools` array is an **explicit allowlist** — Copilot calls MCP
tools autonomously without per-call approval, so writing tools
(`SAPWrite`, `SAPActivate`, `SAPManage`, `SAPTransport`, `SAPGit`)
are deliberately omitted.

**2. Repo → Settings → Copilot → Cloud agent → Secrets**

Add `COPILOT_MCP_ARC1_API_KEY` — an ARC-1 API key with the
**`viewer-sql`** profile (read + free SQL + table preview, no
writes). The `COPILOT_MCP_` prefix is required by GitHub.

**3. Branch protection on `main`**

Require the `abaplint` check to pass. Optionally require a Copilot
review (or assign Copilot as default reviewer for PRs).

**4. Reviewer instructions**

The agent reads [`.github/copilot-instructions.md`](.github/copilot-instructions.md)
on every invocation. It tells Copilot which ARC-1 tools to reach for
when answering each kind of review question, and what to skip
because the abaplint check already covered it.

### Triggering an ARC-1-backed Copilot review on a PR

Important: the right-sidebar **"Reviewers → Copilot"** assignment
triggers the *Copilot Code Review* product, which does **not** call
MCP servers — it reviews from the diff text only. For MCP-backed
review (Copilot Coding Agent), you need to **`@copilot`-mention**
in a PR comment. Three ways, increasingly automated:

**Option 1 — Apply the `copilot:review` label** (recommended)

Open the PR → right sidebar → Labels → `copilot:review`. The
[`copilot-review-trigger.yml`](.github/workflows/copilot-review-trigger.yml)
workflow posts the canonical prompt from
[`.github/copilot-review-prompt.md`](.github/copilot-review-prompt.md)
as a PR comment containing `@copilot review …`, which invokes Copilot
Coding Agent. The label auto-removes after posting so you can re-apply
it later to re-trigger.

> **One-time setup:** this workflow needs a fine-grained PAT, not the
> default `GITHUB_TOKEN`. Comments posted by `github-actions[bot]` do
> NOT trigger `@copilot` mentions — that's GitHub's recursion-prevention
> rule. (GitHub App installation tokens are also unsupported for this,
> per [github/gh-aw#19765](https://github.com/github/gh-aw/issues/19765).)
> The canonical workaround:
>
> 1. github.com → your profile → Settings → Developer settings →
>    Personal access tokens → Fine-grained tokens → **Generate new token**.
> 2. Repository access: this repo only.
> 3. Permissions: **Pull requests = Read and write**, **Contents = Read**.
> 4. Expiry: your call (90 days or 1 year is typical).
> 5. Copy the token.
> 6. This repo → Settings → Secrets and variables → Actions →
>    **New repository secret** → name `COPILOT_TRIGGER_PAT`, paste the
>    token. The workflow fails fast with a clear error if the secret
>    isn't set.
>
> The token owner needs an active Copilot subscription — that's what
> makes `@copilot` work in the comment Copilot will see.

**Option 2 — GitHub Saved Reply** (one-click, account-level)

In github.com → your profile → Settings → Saved replies → "Add a saved
reply" → paste the contents of
[`.github/copilot-review-prompt.md`](.github/copilot-review-prompt.md).
Then on any PR, click the dropdown to the right of the Comment button,
pick the saved reply, hit Comment.

**Option 3 — Paste the prompt manually**

Open [`.github/copilot-review-prompt.md`](.github/copilot-review-prompt.md),
copy, paste into a new PR comment. Useful when you want to tweak the
prompt for a specific PR.

All three end up the same way: Copilot Coding Agent picks up the
`@copilot` mention, uses ARC-1 via the MCP config, posts one summary
review citing the tool calls.

## Alternative: Claude instead of Copilot

Same task, different engine. The repo has a parallel workflow
[`claude-review-trigger.yml`](.github/workflows/claude-review-trigger.yml)
using [`anthropics/claude-code-action@v1`](https://github.com/anthropics/claude-code-action).
**Apply the `claude:review` label** to a PR and the workflow runs Claude
Code in CI, queries ARC-1 via MCP, and posts a review as `claude[bot]`.

Why Claude is *simpler to wire up* than Copilot here: Claude runs
INSIDE our workflow, so it posts comments via the default `GITHUB_TOKEN`
— no PAT trick needed (there's no `@`-mention to chain another bot
through). The trade-off: needs an Anthropic API key + you pay per token.

**One-time setup for the Claude path:**

1. `ANTHROPIC_API_KEY` (repository secret) — get from
   [console.anthropic.com](https://console.anthropic.com).
2. `ARC1_API_KEY` (repository secret) — same `viewer-sql` profile API
   key as the Copilot setup, just stored under a regular name (the
   `COPILOT_MCP_` prefix is required for Copilot only).
3. `ARC1_URL` (repository variable) — same as Copilot, already set.

That's it. No GitHub App install, no PAT, no extra UI config — the MCP
server is configured inline in the workflow.

**Optional: `@claude` mention via the Claude GitHub App.** If you'd
also like the conversational `@claude` mention surface (parallel to
`@copilot`), install the [Claude GitHub App](https://github.com/apps/claude)
on the repo and configure its MCP servers in the app's settings.
Trigger reviews with `@claude review …` in PR comments. The mention
surface is mostly redundant once the label-triggered workflow above
is wired up — keep this for ad-hoc questions ("@claude, what does the
caller chain look like for `create_task`?").

Reviewer instructions for Claude live in
[`.github/CLAUDE.md`](.github/CLAUDE.md) — same review criteria as
Copilot, different invocation surface.

## After abapGit push: adding the test class

The `seed/zcl_arc1_task_service.clas.testclasses.abap` file in this
repo is the **local test class** for `ZCL_ARC1_TASK_SERVICE`. ABAP
Unit tests inside it cover the class's private `validate_title`
method. abapGit pull will materialise the `CCAU` include in SAP the
first time it sees this file in `src/`.

## Why each layer earns its keep

- **abaplint** is fast (~30 s), runs entirely on the GH runner,
  catches the long tail of style and statement-level bugs. Run it
  locally too: `npx @abaplint/cli` for instant feedback before
  pushing.
- **Copilot Coding Agent + ARC-1 MCP** is the only layer that
  answers "does this change break callers?", "is this consistent
  with the rest of the package?", "is the data this BAdI registers
  for already covered by a SAP-standard service?" — questions that
  need the surrounding repository **and** the live SAP system as
  context. ARC-1's token-efficient design (compressed dependency
  context, method-level surgery, `SAPContext` for class graphs)
  keeps the MCP responses small enough for the LLM to actually use
  them.
