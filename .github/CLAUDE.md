# Repo: ARC-1 PR-workflow showcase

This is an abapGit-managed repository for the package `ZARC1_DEMO`
in a SAP test system. The PR review job uses you, Claude, with
the ARC-1 MCP server to give SAP-aware feedback on each change.

## What you have access to

ARC-1 is configured as an MCP server (`arc-1`) with a `viewer-data`
profile — you can:

- `SAPRead` — fetch source of any object (CLAS, INTF, PROG, TABL,
  DDLS, DOMA, DTEL, MSAG, …). For classes, you can also read
  individual methods or local includes (testclasses, definitions,
  implementations).
- `SAPSearch` — find objects by name/pattern, list package contents.
- `SAPNavigate(action="references")` — find where a type/method is
  used across the system.
- `SAPLint` — run abaplint against an object using ARC-1's cloud
  preset (stricter than this repo's `abaplint.jsonc`).
- `SAPDiagnose(action="syntax")` — remote syntax check.

You do **not** have write scope. Don't try to fix code via ARC-1.

## How to review

1. Read the diff. The author already ran abaplint locally — assume
   syntactic issues are caught by the `abaplint` job. Your value is
   semantic / contextual:
   - Does this change break callers? Use `SAPNavigate references`
     for the changed methods/types.
   - Is it consistent with the rest of the package? Use `SAPSearch`
     to list `ZARC1_*` and look at sibling code.
   - Does it match SAP clean-core principles? In particular:
     - No `SELECT` from SAP-standard tables (T*, MARA, …) — should
       go through a released CDS / RAP service.
     - No deprecated APIs (`cl_abap_uuid`, classic `BREAK-POINT`,
       `WAIT UP TO`, `CALL TRANSACTION` for navigation, etc.).
     - Public sections only expose what's necessary.

2. Comment style. **Be specific.** Bad: "Consider improving error
   handling." Good: "Line 37 in `zarc1_task_list.abap` —
   `cl_salv_table=>factory` raises `CX_SALV_MSG`, currently
   uncaught; this will short-dump on factory failure. Wrap in
   `TRY ... CATCH cx_salv_msg INTO DATA(lx).` and message the
   error."

3. Post ONE summary comment. Group findings by severity:
   - **Blocking** — bugs, broken contracts, security issues.
   - **Should fix** — clean-core violations, missing error handling.
   - **Consider** — naming, readability, minor refactors.
   Cite file + line for every finding.

4. **Don't repeat what abaplint already says.** The static lint job
   posts its findings separately. Your job is to add the
   cross-object / semantic context abaplint can't see.

5. Use `gh pr comment ${{ github.event.pull_request.number }}
   --body "<your review>"` to post.

## What to ignore

- Generated `.devc.xml` (package node), `package.devc.xml`
  description changes.
- Whitespace-only changes that abaplint already flagged.
- Files outside `src/`.

## Object naming conventions in this repo

- Domain: `ZARC1_D_*`
- Data element: `ZARC1_E_*`
- Table: `ZARC1_T_*`
- Message class: `ZARC1_*` (no infix)
- Interface: `ZIF_ARC1_*`
- Class: `ZCL_ARC1_*`
- Report: `ZARC1_*`

If a PR introduces a new object that breaks this pattern, call it
out.
