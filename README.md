# ARC-1 ABAP CI/CD review

End-to-end demo: SAP ABAP development → abapGit push → GitHub PR →
automated review (static lint + SAP-aware lint + LLM review using
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
┌────────────────────┐     abapGit     ┌────────────────────┐
│ SAP test system    │ ──────push────▶ │ GitHub: this repo  │
│ a4h.marianzeis.de  │                 │                    │
│ ZARC1_DEMO         │ ◀─────pull───── │ feature branch     │
└────────────────────┘                 └─────────┬──────────┘
        ▲                                        │ open PR
        │ HTTPS                                  ▼
        │                              ┌────────────────────┐
        │                              │ GitHub Actions     │
   ┌────┴────┐         HTTPS           │  1. abaplint       │
   │ ARC-1   │ ◀──────(MCP)──────────  │  2. ARC-1 SAPLint  │
   │ BTP CF  │                         │  3. Claude review  │
   └─────────┘                         └────────────────────┘
```

The CI runner never has SAP credentials. It talks to **ARC-1**
deployed on SAP BTP Cloud Foundry, which talks to the SAP test
system. CI auth is a single API key (`viewer-data` profile,
read + data preview, no writes).

## Three PR-check jobs

### 1. `abaplint` — static lint (no SAP, no ARC-1)
Runs `@abaplint/cli` against the changed source files.
Catches naming, statement-level issues, deprecated keywords,
chained declarations, etc.
- Config: [`abaplint.jsonc`](abaplint.jsonc) (tuned for SAP_BASIS 758 / S/4HANA 2023).
- ~30 s on a GitHub-hosted runner.

### 2. `arc1-saplint` — semantic lint (via ARC-1)
For each changed object, calls `SAPLint(type, name)` on the
ARC-1 BTP instance. ARC-1 uses its cloud preset (stricter than
the repo's `abaplint.jsonc`).
- Diff → object list via [`.github/scripts/parse-abapgit-diff.sh`](.github/scripts/parse-abapgit-diff.sh).
- Requires repo vars/secrets:
  - `vars.ARC1_URL` — e.g. `https://arc-1.cfapps.eu10.hana.ondemand.com`
  - `secrets.ARC1_API_KEY` — `viewer-data` profile

### 3. `llm-review` — LLM PR review (Claude Code Action + ARC-1)
Claude reads the diff, then uses ARC-1 (configured as an MCP
server) to:
- pull the activated version of each changed object,
- find downstream callers (`SAPNavigate references`),
- run remote syntax check (`SAPDiagnose syntax`),
- list sibling code in the package.

It posts ONE summary review comment grouped by severity.
- Instructions: [`.github/CLAUDE.md`](.github/CLAUDE.md)
- Requires: `secrets.ANTHROPIC_API_KEY` (plus the ARC-1 vars
  above)

GitHub Copilot can review the same PR. Configure ARC-1 as an MCP
server under Repository → Settings → Copilot, then assign Copilot
as a reviewer. Instructions for Copilot: [`.github/copilot-instructions.md`](.github/copilot-instructions.md).

## Reproducing this setup

### Prerequisites

- A SAP system with abapGit installed (report `ZABAPGIT` or
  `ZABAPGIT_STANDALONE`).
- GitHub's current TLS chain trusted in STRUST → SSL Client
  (Standard). GitHub rotates certs every ~90 days; only the
  **intermediate + root** in the chain need to be in the PSE —
  the leaf rotates automatically. Verify the live chain with
  `openssl s_client -servername github.com -connect github.com:443`
  before importing.
- An ARC-1 instance reachable from GitHub Actions (the BTP CF
  deployment with XSUAA + Destination Service is the easiest).
- A GitHub Personal Access Token registered in abapGit for HTTPS
  push (fine-grained, scope `Contents: read/write` on this repo).

### One-time setup in SAP

1. Create package `ZARC1_DEMO` (transportable, `HOME` SWCV).
2. Create a workbench transport request.
3. Create the objects listed above. The exact source we used to
   bootstrap this repo lives in `seed/` after the first abapGit
   push.

You can do (1)–(3) by hand in Eclipse/SE80, or scripted via the
ARC-1 CLI:

```bash
node dist/cli.js call SAPTransport --json '{"action":"create","description":"…","targetPackage":"ZARC1_DEMO"}'
node dist/cli.js call SAPManage    --json '{"action":"create_package","name":"ZARC1_DEMO","softwareComponent":"HOME","transport":"…"}'
node dist/cli.js call SAPWrite     --json '{"action":"create","type":"DOMA",…}'
# … one SAPWrite per object, then SAPActivate.
```

### One-time setup in GitHub

In Repository → Settings:
- Variables → `ARC1_URL` = your ARC-1 public URL.
- Secrets → `ARC1_API_KEY` = an ARC-1 API key with `viewer-data`
  profile.
- Secrets → `ANTHROPIC_API_KEY` = your Claude API key.
- Branch protection on `main`: require all three checks to pass.

### After abapGit push

1. The `seed/` directory contains the local test class
   (`zcl_arc1_task_service.clas.testclasses.abap`).
   Move it to `src/` and `git push` — your next abapGit **pull**
   in SAP will create the CCAU include in the class.
2. Open the first PR (fix the seeded chained-DATA issue in the
   report) and watch the three checks run.

## Why each layer earns its keep

- **abaplint** is fast and catches the long tail of style bugs.
  Run it locally too (`npx abaplint`) for instant feedback.
- **ARC-1 SAPLint** uses the same engine but with ARC-1's cloud
  preset, which is closer to the rules SAP itself applies in
  BTP ABAP Environment. Bridges "looks fine locally" to "would
  fly through ATC."
- **LLM review** is the only layer that can answer "does this
  change break callers?", "is this consistent with the rest of
  the package?", "is the naming consistent?", etc. — questions
  that need the surrounding repository as context, which ARC-1
  provides token-efficiently (one tool call per question,
  typically <1k tokens of response).
