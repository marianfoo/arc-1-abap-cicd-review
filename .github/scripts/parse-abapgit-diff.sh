#!/usr/bin/env bash
# Map abapGit filenames in a git diff to TAB-separated TYPE\tNAME pairs.
# Output one line per object. Used by sap-tests.yml.
#
# Usage: parse-abapgit-diff.sh <base-sha> <head-sha>
set -euo pipefail

BASE="${1:?missing base sha}"
HEAD="${2:?missing head sha}"

git diff --name-only --diff-filter=ACMR "$BASE...$HEAD" -- 'src/**' \
  | awk -F/ '{print $NF}' \
  | sed -E 's/\.clas\.(testclasses|locals_imp|locals_def|macros)\.abap$/.clas.abap/' \
  | sort -u \
  | while IFS= read -r f; do
      [ -z "$f" ] && continue
      name=$(echo "$f" | sed -E 's/\.[a-z]+\.(abap|xml|json)$//' | tr '[:lower:]' '[:upper:]')
      ext=$(echo "$f" | sed -E 's/^[^.]+\.([a-z]+)\..*/\1/')
      case "$ext" in
        clas) echo -e "CLAS\t$name" ;;
        intf) echo -e "INTF\t$name" ;;
        prog) echo -e "PROG\t$name" ;;
        fugr) echo -e "FUGR\t$name" ;;
        tabl) echo -e "TABL\t$name" ;;
        doma) echo -e "DOMA\t$name" ;;
        dtel) echo -e "DTEL\t$name" ;;
        msag) echo -e "MSAG\t$name" ;;
        ddls) echo -e "DDLS\t$name" ;;
        bdef) echo -e "BDEF\t$name" ;;
        srvd) echo -e "SRVD\t$name" ;;
        srvb) echo -e "SRVB\t$name" ;;
        devc) ;;
        *)    ;;
      esac
    done
