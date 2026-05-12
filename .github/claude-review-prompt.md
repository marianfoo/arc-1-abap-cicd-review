Review the pull request diff. The static `abaplint` check has already
posted its findings as inline annotations — **don't repeat them**. Focus
on the cross-object / semantic issues only abaplint can't see.

## Tool budget — keep it tight

You have access to the `arc-1` MCP server. **Use 2–5 tool calls
total**, not more. Pick the right ones for what's in the diff. Don't
explore beyond the changed files.

Useful patterns:

- **One `SAPRead` per changed file** to check for GitHub↔SAP drift (PR
  source vs activated source). For classes, use `method="*"` first to
  see signatures cheaply; only read individual methods if needed.
- **One `SAPDiagnose(action="syntax")`** ONLY if you suspect a syntax
  issue. Skip otherwise — the `abaplint` check already covers static
  validation.
- **One `SAPNavigate(action="references")`** ONLY if the PR changes a
  public signature (interface method, class public method, public
  type). Skip for internal-only changes.
- Skip `SAPLint`, `SAPSearch`, `SAPContext`, `SAPQuery` unless you have
  a specific reason — they overlap with checks already running.

## Output — single comment, severity-grouped

Post **one** review comment using:

```bash
gh pr comment $PR_NUMBER --body "$(cat <<'EOF'
## Claude review of <commit-sha>

**Blocking** — bugs, broken contracts, security issues, clean-core
violations that would be rejected by ATC.
- <file:line> — <finding>. (Cite the ARC-1 tool result that informed
  it, e.g. `SAPRead showed line drift between GitHub and active`.)

**Should fix** — missing error handling, deprecated APIs, dead code,
inconsistencies with the rest of the package.
- ...

**Consider** — naming, readability, minor refactors.
- ...

_If a section has no findings, omit it. If nothing is wrong, post just
"Looks good. Tool calls: <list>."_
EOF
)"
```

`$PR_NUMBER` is set in the workflow environment. Quote your review body
correctly (the heredoc above is the safest way).

## Repo conventions (only flag deviations)

- DOMA `ZARC1_D_*` · DTEL `ZARC1_E_*` · TABL `ZARC1_T_*`
- MSAG/PROG `ZARC1_*` · INTF `ZIF_ARC1_*` · CLAS `ZCL_ARC1_*`
