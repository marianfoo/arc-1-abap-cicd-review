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
- Skip `SAPLint` unless you have a specific reason — it overlaps with
  the abaplint job that already ran.

## Output — Pull Request Review with inline comments

Post your findings as **one Pull Request Review** that contains:

- An **overall body** for cross-file / general findings.
- **Inline comments** for findings attached to specific changed lines.

**Important constraint:** GitHub only accepts inline comments on lines
that are in the PR's diff hunks. If you can't attach a finding to a
specific changed line, put it in the overall body instead.

Step 1 — see which lines are eligible for inline comments:

```bash
gh pr diff $PR_NUMBER
```

Step 2 — build the review payload. Severity prefixes go in the comment
body itself (`**Blocking**:`, `**Should fix**:`, `**Consider**:`).
Cite the ARC-1 tool result that informed each finding (e.g. "_SAPRead
showed line drift between repo and active_", "_SAPDiagnose returned
hasErrors=false_"):

```bash
cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "body": "## Claude review\n\nReviewed using the arc-1 MCP server.\n\n_Overall notes / cross-file findings here. If everything's covered inline, write a short summary instead._\n\n**Tool calls made:** SAPRead, SAPDiagnose, ...",
  "comments": [
    {
      "path": "src/zarc1_task_list.prog.abap",
      "line": 27,
      "body": "**Should fix**: <one-line finding>. _Cite which ARC-1 tool result backs this._"
    }
  ]
}
EOF
```

Step 3 — post it:

```bash
gh api --method POST \
  repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews \
  --input /tmp/review.json
```

`event: "COMMENT"` posts a non-blocking review (use `REQUEST_CHANGES`
only if you actually want to gate the merge). `{owner}` and `{repo}`
are auto-resolved by `gh`.

## If there are no findings

Skip the inline comments and post just an approval-style summary:

```bash
gh pr comment $PR_NUMBER --body "✅ Looks good. Tool calls: SAPRead, SAPDiagnose. No findings beyond what abaplint already flagged."
```

## Repo conventions (only flag deviations)

- DOMA `ZARC1_D_*` · DTEL `ZARC1_E_*` · TABL `ZARC1_T_*`
- MSAG/PROG `ZARC1_*` · INTF `ZIF_ARC1_*` · CLAS `ZCL_ARC1_*`
