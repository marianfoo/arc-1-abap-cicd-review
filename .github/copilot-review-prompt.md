@copilot review this PR using the **arc-1** MCP server.

For each changed ABAP object in the diff, do these in order before commenting:

1. **`SAPRead`** the activated version of the object from the live SAP
   system. Compare against the diff — note any drift between what's in
   GitHub and what's active in SAP.
2. **`SAPDiagnose(action="syntax")`** on each changed object to verify
   it compiles. Cite the result.
3. **`SAPNavigate(action="references")`** on changed methods, types,
   or fields. Name any callers that would break.
4. **`SAPLint`** with the cloud preset for a second opinion vs. the
   repo's `abaplint.jsonc`. **Don't repeat findings the abaplint check
   already posted** (it has its own annotations on the diff). Flag only
   what the cloud preset surfaces *additionally*.
5. **`SAPQuery`** sparingly — only when it adds signal (customizing-
   table spot checks, BAdI registration checks). Don't dump rows of
   business data into the comment.

Then post **one** summary review comment, grouped by severity:

- **Blocking** — bugs, broken contracts, security issues, clean-core
  violations that would be rejected by ATC.
- **Should fix** — missing error handling, deprecated APIs, dead code,
  inconsistencies with the rest of the package.
- **Consider** — naming, readability, minor refactors.

For each finding, cite **file:line** and **quote the ARC-1 tool result**
that informed it (e.g. `SAPDiagnose returned hasErrors=false`,
`SAPNavigate found 3 callers: ZARC1_TASK_LIST, ...`). That makes the
review auditable — anyone reading later can trace which MCP call backed
each claim.

Repo conventions to apply:

- Domain: `ZARC1_D_*` · Data element: `ZARC1_E_*` · Table: `ZARC1_T_*`
- Message class: `ZARC1_*` · Interface: `ZIF_ARC1_*` · Class: `ZCL_ARC1_*`
- Report: `ZARC1_*`

If a PR introduces a new object that violates these, flag it under
"Should fix".
