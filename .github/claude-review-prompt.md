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
hasErrors=false_").

**Whenever you can name the exact replacement lines, INCLUDE a
`suggestion` code block.** This is the most important UX feature of a
review — it gives the human a one-click "Apply" button instead of
making them retype the fix. **Default to including suggestions; only
skip them when the right fix genuinely is ambiguous.**

Two especially good cases — **always** use suggestion blocks here:

- **Code to delete** (debug `BREAK-POINT.`, a stray `WRITE`, a whole
  block of dead code). Use an empty suggestion block — GitHub renders
  this as a "delete these lines" button.
- **Anti-pattern with an obvious replacement** (direct table `SELECT`
  on a SAP-standard table → released CDS view; chained `DATA: BEGIN
  OF` → `TYPES` + `DATA`; obsolete keyword → modern equivalent).

For a multi-line suggestion (replacing lines 55–63 with empty content,
for example) use `start_line:` and `line:` to span the range, and an
empty fenced block for "delete this whole thing."

The block must contain **exactly** what the new content should be for
the line range. Whitespace matters. Example payload — mixing one plain
comment (no fix), one single-line delete-suggestion, and one multi-line
replacement-suggestion:

```bash
cat > /tmp/review.json <<'EOF'
{
  "event": "COMMENT",
  "body": "## Claude review\n\nReviewed using the arc-1 MCP server.\n\n_Overall notes / cross-file findings here._\n\n**Tool calls made:** SAPRead, SAPDiagnose, ...",
  "comments": [
    {
      "path": "src/foo.prog.abap",
      "line": 14,
      "body": "**Consider**: unused. _SAPNavigate found 0 references._"
    },
    {
      "path": "src/foo.prog.abap",
      "line": 27,
      "body": "**Blocking**: leftover debug breakpoint.\n\n```suggestion\n  \" (line removed)\n```"
    },
    {
      "path": "src/bar.clas.abap",
      "start_line": 55,
      "line": 63,
      "body": "**Blocking**: direct MARA SELECT is a clean-core violation. Use the released CDS view instead.\n\n```suggestion\n    select single product from i_product\n      into @data(lv_dummy)\n      where productisexternalitem = 'X'.\n    if sy-subrc <> 0.\n      return.\n    endif.\n```"
    }
  ]
}
EOF
```

Suggestion-block rules:

- The `suggestion` block content is the **exact replacement** for the
  spanned line range. Whitespace matters — preserve indentation as it
  should appear in the file.
- To suggest **deleting** lines, use an empty `suggestion` block (just
  the opening + closing fences). The "Apply suggestion" button will
  remove the spanned lines.
- Only **skip** a suggestion block when (a) the right fix needs human
  product decisions (which CDS view? which exception type?) or (b) it
  would span too many lines to be safe. For "delete this debug code"
  or "replace MARA with the standard CDS lookup" — both are obvious
  enough that a suggestion is the right call. Default to suggesting.
- Only suggest changes on **lines in this PR's diff**. GitHub rejects
  suggestions on unchanged lines anyway, but check `gh pr diff` first
  if uncertain.

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
