# Claude reviewer instructions (alternative AI reviewer)

> Copilot is the primary AI reviewer in this repo
> ([copilot-instructions.md](copilot-instructions.md)). These
> instructions are only used if you've installed the
> [Claude GitHub App](https://github.com/apps/claude) and trigger
> a review with `@claude` in a PR comment.

When invoked, follow the same flow as the Copilot instructions —
the tooling and review criteria are identical:

- ARC-1 is your MCP server (configure under the Claude GitHub App's
  per-repo settings with the same JSON shape as Copilot, but with
  `Authorization: Bearer ${{ secrets.ARC1_API_KEY }}` directly —
  no `COPILOT_MCP_` prefix).
- Allowlisted tools: `SAPRead`, `SAPSearch`, `SAPNavigate`,
  `SAPContext`, `SAPDiagnose`, `SAPLint`, `SAPQuery`. Read-only.
- The `abaplint` workflow already covers static checks — your value
  is cross-object semantic context.

See [copilot-instructions.md](copilot-instructions.md) for the
review job description, severity groupings, naming conventions,
and what to ignore.
