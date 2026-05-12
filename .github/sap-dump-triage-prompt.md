Triage SAP short dumps (ST22). Run every 6 hours; on each run, find
dumps that don't already have a tracking GitHub issue, open one issue
per **new** dump with a short Claude triage analysis.

## Strict budget

- Process **at most 5 new dumps** per run. If there are more, sort by
  timestamp (newest first), handle 5, and mention the rest in the
  final summary so the next run can pick them up.
- **Skip duplicates** — for each dump ID, check whether an issue
  already exists before doing anything else with it.
- Aim for **≤ 4 tool calls per new dump**:
  - 1× list dumps
  - 1× `gh issue list` to fetch existing tracker issues (one call total)
  - 1× `SAPDiagnose(id=...)` per new dump for the focused chapter sections
  - 1× `gh issue create` per new dump

## Step-by-step

### Step 1 — list recent dumps

```bash
# Already wired by the workflow; just call the MCP tool.
```

Call `mcp__arc-1__SAPDiagnose` with `action=dumps`, `maxResults=20`.
This returns a JSON array of `{id, timestamp, user, error, program}`.

### Step 2 — fetch existing dump-tracker issues

```bash
gh issue list --repo "$GITHUB_REPOSITORY" \
  --label 'sap:dump' \
  --state all \
  --limit 200 \
  --json number,title,body \
  > /tmp/existing-dumps.json
```

Parse `/tmp/existing-dumps.json` and extract the `dump-id` markers
from each issue body (HTML comment of the form
`<!-- dump-id: <id> -->`). Build a Set of already-tracked dump IDs.

### Step 3 — for each NEW dump (cap at 5), triage + create issue

For each dump in the list whose ID is **not** in the existing set:

1. Fetch focused details with `mcp__arc-1__SAPDiagnose`:
   `{action: "dumps", id: "<dump-id>"}`. This returns kap0 / kap3
   chapter sections (where/when/who/what).
2. Compose an issue body with:
   - HTML comment marker: `<!-- dump-id: <full id> -->` (first line,
     so dedup can find it cheaply).
   - Metadata table (timestamp, user, error, program).
   - **Urgency** line — `**Urgency:** high | medium | low` with a
     1-sentence justification (see rubric below).
   - **Claude triage** (2–4 sentences):
     - Likely cause based on the error class + program.
     - Whether this looks transient (user-action-triggered) or
       systemic (cron / background / heavy).
     - One concrete next step (e.g. "check note 1234567", "inspect
       method X for null-guard", "verify table T000 has client 100").
   - Link to the SAP `vhcala4hci` system / transaction `ST22` for
     manual investigation.
3. Create the issue with the right urgency label:
   ```bash
   gh issue create --repo "$GITHUB_REPOSITORY" \
     --label "sap:dump,needs-triage,urgency:<high|medium|low>" \
     --title "[ST22] <error> in <short-program-name>" \
     --body-file /tmp/issue-body.md
   ```

### Urgency rubric

Pick one of `urgency:high` / `urgency:medium` / `urgency:low` for
every new issue. Default to **medium** if you're truly unsure — but
try hard to classify, the whole point is to triage.

- **`urgency:high`** — at least one of:
  - Runs in **background / cron / scheduled job** (program type "B",
    or job-related stack frames in the dump).
  - **Security-related** (auth/role failure, sandbox escape, anything
    in `SUSR_*`, `SAML*`, `CERT*`, `AUTHORITY-CHECK`).
  - **Recurrence**: ≥ 3 dumps with the same error+program in the
    same 6-hour window (visible from the dump list — check before
    classifying).
  - **Update terminated** (anything from the V1/V2 update task).
  - **Production-like path**: customer-facing transaction, OData
    handler, gateway service.

- **`urgency:medium`** — default. Use when:
  - User-facing dialog (`type` "A" / online), but transient.
  - Single user, one record, looks data-specific.
  - In SAP-standard code (`CL_*`, `/UI2/*`, `/IWFND/*`, etc.) where
    a SAP note likely exists.
  - You're not sure but it's not obviously dev noise.

- **`urgency:low`** — when:
  - The triggering program is a development tool (`SE38`, `SE80`,
    `SAPMSSY*`, ADT classes `CL_ADT_*` / `CL_ENH_ADT_*`, profiler,
    debugger).
  - Single occurrence, user `DEVELOPER` or another dev account,
    timestamp clusters with manual testing.
  - The class name has `_TEST` or `_DEMO` in it.

### Step 4 — print summary

End the run with a one-line summary suitable for the workflow log:

```
Processed N new dumps; M skipped as duplicates; K not yet looked at
(see backlog).
```

## Issue title conventions

- Format: `[ST22] <error_class> in <object_short_name>`
- Strip `=====CP` suffixes from class names for readability.
- Examples:
  - `[ST22] OBJECTS_OBJREF_NOT_ASSIGNED in CL_ART_QUICKFIX_PROVIDER`
  - `[ST22] ASSERTION_FAILED in /UI2/CL_EDM_DA_V06_USAGE`

## What NOT to do

- Don't create one issue per dump-tuple-permutation. Each dump ID is
  one issue.
- Don't paste the full dump text — the focused `SAPDiagnose(id=...)`
  output is enough. Reviewers can open ST22 in SAP for the full blob.
- Don't try to fix the dumps; you have read-only access. The issue
  just documents and triages.
- Don't `@`-mention humans or assign anyone — that's the next person
  in the rotation's call.
