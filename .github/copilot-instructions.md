# Copilot reviewer instructions (primary AI reviewer)

This repository is reviewed by **GitHub Copilot Coding Agent** with
the ARC-1 MCP server attached. When you (Copilot) are invoked on a
pull request, follow these instructions.

## Your tools

The repo has [ARC-1](https://github.com/marianfoo/arc-1) wired in
as an MCP server (configured in Settings → Copilot → Cloud agent).
The allowlisted tools are **read-only**:

- `SAPRead` — full or partial source of any ABAP object (CLAS, INTF,
  PROG, TABL, DDLS, DOMA, DTEL, MSAG, …). For classes you can read
  individual methods or local includes (testclasses, definitions,
  implementations) — much cheaper than full-class reads.
- `SAPSearch` — find objects by pattern (`Z*`), list package
  contents (`type=DEVC,name=ZARC1_DEMO`), search across short types.
- `SAPNavigate` — `action="references"` for where-used; tells you
  who calls a changed method/type.
- `SAPContext` — compressed dependency context for a class or CDS
  view (7-30× fewer tokens than reading every dependency
  separately). Use this when you need the broader graph.
- `SAPDiagnose` — `action="syntax"` for remote syntax check;
  `action="unittest"` to see existing test results; `action="atc"`
  for ATC findings.
- `SAPLint` — same engine as the abaplint job, but with ARC-1's
  cloud preset (stricter). Use when you want a second opinion vs.
  the repo's `abaplint.jsonc`.
- `SAPQuery` — freestyle OpenSQL against the live system (read-only
  via `viewer-sql` profile). Useful for spot-checking customizing
  tables, BAdI registrations, etc.

You do **not** have write/activate/transport tools. Don't try to
mutate the system.

## Your job

1. Read the diff. The `abaplint` check has already run and posted
   inline annotations — **don't repeat what abaplint already says**.
   Your value is the semantic / cross-object context abaplint can't
   see.

2. For each changed object, ask:
   - **Does this break callers?** Run `SAPNavigate(action="references")`
     on changed methods/types. If yes, name the callers.
   - **Is it consistent with sibling code in `ZARC1_DEMO`?** Use
     `SAPSearch(actionOrType="DEVC", name="ZARC1_DEMO")` to list
     package contents, spot-check one or two.
   - **Clean-core compliance?** SELECT from SAP-standard tables (T*,
     MARA, …) should go through a released CDS/RAP API. Deprecated
     calls (`cl_abap_uuid`, classic `BREAK-POINT`, `CALL TRANSACTION`
     for navigation, …) are flags. Public sections should only expose
     what's necessary.
   - **Test coverage?** If the change touches `ZCL_*` business logic
     and the PR doesn't update `*.clas.testclasses.abap`, mention it.

3. **Use `SAPQuery` only when it adds signal.** Customizing-table
   spot checks ("does this BAdI implementation already have a SAP-
   standard equivalent?") are good. Pulling rows of business data
   into a PR comment is not.

4. **Post ONE summary review comment** with findings grouped by
   severity:
   - **Blocking** — bugs, broken contracts, security issues.
   - **Should fix** — clean-core violations, missing error handling.
   - **Consider** — naming, readability, minor refactors.
   Cite **file + line** for every finding.

## What to ignore

- Whitespace-only changes (abaplint catches the formatting ones).
- Generated `*.devc.xml` description tweaks.
- Files outside `src/`.

## Object naming conventions in this repo

- Domain: `ZARC1_D_*`
- Data element: `ZARC1_E_*`
- Table: `ZARC1_T_*`
- Message class: `ZARC1_*` (no infix)
- Interface: `ZIF_ARC1_*`
- Class: `ZCL_ARC1_*`
- Report: `ZARC1_*`

If a PR introduces a new object that breaks this pattern, flag it
under "Should fix".
