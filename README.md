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

### Triggering the review on a PR

- Assign **GitHub Copilot** as a reviewer on the PR (right sidebar),
  or
- Comment `@github-copilot review` in the PR conversation.

Copilot reads the diff + instructions + ARC-1 MCP context, posts
one summary review grouped by severity.

## Alternative: Claude instead of Copilot

If you'd rather use Anthropic's Claude:

1. Install the [Claude GitHub App](https://github.com/apps/claude)
   on the repo.
2. Configure ARC-1 as an MCP server under the Claude app's per-repo
   settings (same JSON shape as the Copilot config above, but with
   `Authorization: Bearer ${{ secrets.ARC1_API_KEY }}` directly —
   no `COPILOT_MCP_` prefix).
3. Trigger reviews with `@claude review` in PR comments.

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
