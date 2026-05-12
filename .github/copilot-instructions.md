# GitHub Copilot review instructions

This is an abapGit-managed SAP ABAP repository. When you (Copilot)
are assigned as a reviewer on a PR:

1. The same SAP-aware review applies as documented in
   `.github/CLAUDE.md` — read that file first; it has the canonical
   review guidance.

2. If your Copilot configuration includes the ARC-1 MCP server (set
   up via Repository → Settings → Copilot → MCP servers), use the
   same tools described there: `SAPRead`, `SAPSearch`,
   `SAPNavigate`, `SAPLint`, `SAPDiagnose`.

3. Without the ARC-1 MCP server, you are limited to the diff and
   in-repo files — say so explicitly in your review rather than
   guessing about objects you can't see.

4. Post ONE summary review with findings grouped by severity
   (Blocking / Should fix / Consider). Cite file + line.
