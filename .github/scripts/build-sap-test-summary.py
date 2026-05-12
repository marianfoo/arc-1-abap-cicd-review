#!/usr/bin/env python3
"""Render unit-test + ATC results as a sticky markdown comment.

Inputs:
  argv[1] = path to unit-tests JSONL (one MCP response per line, wrapped as
            {"name": "<CLAS_NAME>", "result": <MCP result>})
  argv[2] = path to ATC JSONL (one per line, wrapped as
            {"type": "<TYPE>", "name": "<NAME>", "result": <MCP result>})

Output: markdown body on stdout.
Exit code: 0 always (gating is done separately).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Iterable


def _content_payload(rec: dict) -> dict | list | None:
    """MCP responses wrap a JSON string inside .result.content[0].text."""
    try:
        text = rec["result"]["content"][0]["text"]
    except (KeyError, IndexError, TypeError):
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def _read_jsonl(path: str) -> Iterable[dict]:
    p = Path(path)
    if not p.exists() or p.stat().st_size == 0:
        return []
    return [json.loads(line) for line in p.read_text().splitlines() if line.strip()]


def render_unit_tests(records: list[dict]) -> str:
    if not records:
        return "_No CLAS objects in this PR's diff — unit tests skipped._"

    lines = [
        "### ABAP Unit tests",
        "",
        "| CLAS | Passed | Failed | Errors | Total |",
        "|---|---|---|---|---|",
    ]
    any_failed = False
    for rec in records:
        name = rec.get("name", "?")
        payload = _content_payload(rec)
        if not isinstance(payload, list):
            lines.append(f"| `{name}` | — | — | — | _no test class_ |")
            continue
        total = len(payload)
        passed = sum(1 for t in payload if t.get("status") == "passed")
        failed = sum(1 for t in payload if t.get("status") == "failed")
        errors = sum(1 for t in payload if t.get("status") == "error")
        if failed or errors:
            any_failed = True
        marker = "❌" if (failed or errors) else ("⚠️" if total == 0 else "✅")
        lines.append(
            f"| {marker} `{name}` | {passed} | {failed} | {errors} | {total} |"
        )
    if any_failed:
        lines.append("")
        lines.append("_At least one test did not pass. Job gated._")
    return "\n".join(lines)


def render_atc(records: list[dict]) -> str:
    if not records:
        return "_No object types eligible for ATC in this diff._"

    rows: list[tuple[int, str, str, int, str, str]] = []
    for rec in records:
        kind = rec.get("type", "?")
        name = rec.get("name", "?")
        payload = _content_payload(rec)
        if not isinstance(payload, dict):
            continue
        for f in payload.get("findings", []) or []:
            rows.append(
                (
                    int(f.get("priority", 9)),
                    kind,
                    name,
                    int(f.get("line", 0) or 0),
                    str(f.get("checkTitle", "")),
                    str(f.get("messageTitle", "")),
                )
            )
    if not rows:
        return "### ATC\n\n_No findings._"
    rows.sort(key=lambda r: (r[0], r[2], r[3]))
    lines = [
        "### ATC findings",
        "",
        "| Prio | Object | Line | Check | Message |",
        "|---|---|---|---|---|",
    ]
    icon = {1: "🟥", 2: "🟧", 3: "🟨", 4: "🟦", 5: "⬜"}
    for prio, kind, name, line, check, msg in rows:
        lines.append(
            f"| {icon.get(prio, '⬜')} P{prio} | `{kind} {name}` | {line or '—'} | {check} | {msg} |"
        )
    return "\n".join(lines)


def main() -> int:
    unit_path = sys.argv[1] if len(sys.argv) > 1 else ""
    atc_path = sys.argv[2] if len(sys.argv) > 2 else ""
    unit_records = list(_read_jsonl(unit_path)) if unit_path else []
    atc_records = list(_read_jsonl(atc_path)) if atc_path else []

    out = [
        "## SAP test gate (unit tests + ATC)",
        "",
        "Run against the **activated objects in the live SAP system** for "
        "every CLAS/INTF/PROG/FUGR touched by this PR. "
        "_Read-only — no writes to SAP from this workflow._",
        "",
        render_unit_tests(unit_records),
        "",
        render_atc(atc_records),
    ]
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
