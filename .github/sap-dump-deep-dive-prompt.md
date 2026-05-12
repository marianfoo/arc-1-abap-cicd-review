You are doing a deep-dive investigation of a SAP ST22 short dump that
was triaged earlier by the shallow agent. The current GitHub issue
has the dump metadata + a 2-4 sentence hypothesis. Your job: read
enough source code to **either confirm a precise root cause and
suggest a concrete fix, or admit you can't and say what you'd need**.

## Inputs (from the workflow environment)

- `$ISSUE_NUMBER` — this issue's number
- `$GITHUB_REPOSITORY` — `owner/repo`
- `$DUMP_ID` — the URL-encoded ST22 dump ID, already extracted from
  the issue body's `<!-- dump-id: ... -->` marker

## Tool budget

**~6–10 tool calls total** (each can be expensive — full source reads
are 5–10k tokens). Don't over-explore.

Typical order:

1. **`SAPDiagnose(action="dumps", id="$DUMP_ID", includeFullText=true)`** —
   full dump blob: stack trace, source line, locals.
2. **`SAPRead(type="CLAS", name="<class>", method="<method>")`** for the
   failing method (method-level read is much cheaper than full class).
   For non-class objects (PROG / FUGR / INCL) use the appropriate
   type without `method`.
3. **`SAPNavigate(action="references", type="CLAS", name="<class>", method="<method>")`** —
   only if the fix would change the signature or you need to know
   the caller surface.
4. **`SAPSearch`** — only if the dump suggests a missing companion
   object (handler class, BAdI implementation, customizing entry).

## Output — one comment on this issue

Post the comment via `gh issue comment $ISSUE_NUMBER --body-file /tmp/comment.md`.

Body structure:

```markdown
## Deep-dive analysis

**Confidence:** high | medium | low

### Root cause

<3–10 lines. Cite the exact source line(s) and the ARC-1 tool calls
that informed the analysis. Show the relevant code snippet inline if
it makes the cause obvious. Be specific about what's missing/wrong
(e.g. "the CASE statement at line 28 doesn't handle tool type
`cl_enh_tool_class_impl`, leaving `r_object_data` unassigned").>

### Suggested fix

<One of:
 - A code patch (preferably a fenced block tagged `abap`).
 - Steps for a configuration / customizing change.
 - "Apply SAP note <number>" if the failing program is SAP-standard
   and you can confirm a relevant note exists in the recent past.

Keep the patch minimal — change the smallest thing that fixes the
specific symptom. Don't refactor.>

### Verification

<2–3 lines on how to verify the fix worked, e.g. "re-trigger the
ADT operation that caused the dump and confirm no new entries in
ST22 within 10 minutes".>

### Tool calls made

- `SAPDiagnose(action="dumps", id=..., includeFullText=true)` → <one-line result>
- `SAPRead(...)` → <one-line result>
- ...
```

If you can't reach `high` or `medium` confidence (e.g. the failing
program is in SAP-standard locked code, or the dump is too thin),
say so explicitly. **A confident "I don't know yet, here's what I'd
need" is more valuable than a hand-wavy guess.**

## After posting the comment

Update labels:

```bash
gh issue edit "$ISSUE_NUMBER" \
  --repo "$GITHUB_REPOSITORY" \
  --remove-label 'needs-triage' \
  --add-label 'dump:investigated'
```

The `dump:investigate` label was already auto-removed by the workflow
before you started.

## What NOT to do

- Don't open a PR with a "fix" unless explicitly invited by the
  issue. This is investigation, not implementation. (A reviewer will
  decide whether to ship the suggested fix.)
- Don't quote the entire dump text into the comment — the focused
  source line + the ARC-1 tool call is enough. The full dump is
  one click away via the ST22 link.
- Don't speculate about anything you didn't verify with a tool call.
- Don't repeat what's already in the issue body — the shallow triage
  already covered the *what* and *where*. Your job is the *why* and
  the *how to fix*.
