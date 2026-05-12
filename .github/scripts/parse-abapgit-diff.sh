#!/usr/bin/env bash
# Map abapGit filenames in a git diff to (TYPE, NAME) pairs.
#
# Input:  $1 = base SHA, $2 = head SHA (both required)
# Output: tab-separated TYPE<TAB>NAME on stdout, one per changed object
#
# Convention (abapGit file layout):
#   src/zcl_foo.clas.abap              → CLAS  ZCL_FOO
#   src/zarc1_demo.prog.abap           → PROG  ZARC1_DEMO
#   src/zif_foo.intf.abap              → INTF  ZIF_FOO
#   src/zarc1_t_task.tabl.xml          → TABL  ZARC1_T_TASK
#   src/zarc1_e_status.dtel.xml        → DTEL  ZARC1_E_STATUS
#   src/zarc1_d_status.doma.xml        → DOMA  ZARC1_D_STATUS
#   src/zarc1_task.msag.xml            → MSAG  ZARC1_TASK
#   src/zarc1_demo.devc.xml            → DEVC  ZARC1_DEMO   (skipped — package node)
#
# Sub-includes of a class (`.clas.testclasses.abap`, `.clas.locals_imp.abap`)
# collapse to the parent CLAS; the LLM/lint pulls the whole class anyway.

set -euo pipefail

BASE="${1:?missing base sha}"
HEAD="${2:?missing head sha}"

git diff --name-only --diff-filter=ACMR "$BASE...$HEAD" -- 'src/**' \
  | awk -F/ '{print $NF}' \
  | sed -E 's/\.clas\.(testclasses|locals_imp|locals_def|macros)\.abap$/.clas.abap/' \
  | sort -u \
  | while IFS= read -r f; do
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
        devc) ;;  # package — skip
        *)    ;;  # unknown — skip
      esac
    done
