#!/usr/bin/env bash
# scaffold-docs.sh - bootstrap docs/ for a resumable-multi-agent project (macOS / Linux / WSL)
#
# Usage:
#   ./scaffold-docs.sh --root /path/to/project --name my-app \
#                      [--lane-a backend] [--lane-b frontend] [--contract interface]
#
# What it does:
#   1. Creates <root>/docs/ if missing.
#   2. Copies the four asset templates into docs/ (subagent-prompt.template.md is copied as
#      _subagent-prompt.template.md, an orchestrator reference deleted during Phase C cleanup).
#   3. Replaces the most common placeholders (<Project Name>, <Lane A Name>, <Lane B Name>, <contract>)
#      across the four files in one pass.
#
# It does not fill in PRD content, explanation sections 3+ (naming/run-commands/etc.), or todolist rows.
# Those require human/orchestrator judgement per project. This script only removes the mechanical
# copy-and-replace work so the orchestrator can start writing actual content immediately.
#
# This script is for first-run initialization only. On follow-up runs, the script refuses to overwrite.
# The orchestrator should instead:
#   - Read the existing persistent docs (prd.md, explanation.md, contract, todolist.md).
#   - Have lanes write contract additions to docs/<contract>.draft.md, not the persistent file.
#   - In Phase C, merge drafts into persistent files with deprecation/version markers and append
#     a new dated section to docs/todolist.md. See SKILL.md "Phase C - Merge and Cleanup".

set -euo pipefail

ROOT=""
NAME=""
LANE_A="<Lane A Name>"
LANE_B="<Lane B Name>"
CONTRACT="interface"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)     ROOT="$2"; shift 2 ;;
        --name)     NAME="$2"; shift 2 ;;
        --lane-a)   LANE_A="$2"; shift 2 ;;
        --lane-b)   LANE_B="$2"; shift 2 ;;
        --contract) CONTRACT="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,18p' "$0"
            exit 0
            ;;
        *)
            echo "unknown flag: $1" >&2
            exit 2
            ;;
    esac
done

if [[ -z "$ROOT" || -z "$NAME" ]]; then
    echo "error: --root and --name are required" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
ASSETS_DIR="$SKILL_DIR/assets"
DOCS_DIR="$ROOT/docs"

if [[ -e "$DOCS_DIR" ]]; then
    echo "error: $DOCS_DIR already exists; refusing to overwrite. Delete or move it first." >&2
    exit 1
fi

if [[ ! -d "$ASSETS_DIR" ]]; then
    echo "error: assets directory not found at $ASSETS_DIR. Is the skill installed correctly?" >&2
    exit 1
fi

mkdir -p "$DOCS_DIR"

# Portable in-place edit: write to a temp file, then mv. Avoids GNU vs BSD sed -i differences.
copy_and_substitute() {
    local src="$1"
    local dst="$2"
    # Use Python for cross-platform string replacement with reliable UTF-8 handling.
    python3 - "$src" "$dst" "$NAME" "$LANE_A" "$LANE_B" "$CONTRACT" <<'PY'
import sys, pathlib
src, dst, name, lane_a, lane_b, contract = sys.argv[1:7]
text = pathlib.Path(src).read_text(encoding="utf-8")
text = (text
    .replace("<Project Name>", name)
    .replace("<Lane A Name>", lane_a)
    .replace("<Lane B Name>", lane_b)
    .replace("<Lane A>", lane_a)
    .replace("<Lane B>", lane_b)
    .replace("<contract>", contract))
pathlib.Path(dst).write_text(text, encoding="utf-8")
PY
}

declare -a SRCS=(prd.template.md explanation.template.md todolist.template.md subagent-prompt.template.md)
declare -a DSTS=(prd.md           explanation.md           todolist.md           _subagent-prompt.template.md)

for i in "${!SRCS[@]}"; do
    src="$ASSETS_DIR/${SRCS[$i]}"
    dst="$DOCS_DIR/${DSTS[$i]}"
    copy_and_substitute "$src" "$dst"
    echo "  wrote ${DSTS[$i]}"
done

cat <<EOF

Scaffolded docs at: $DOCS_DIR

Next steps for the orchestrator:
  1. Fill in docs/prd.md sections 1-10 from the user dialogue.
  2. Fill in docs/explanation.md section 1 (repo tree), section 3 (naming),
     section 4 (per-lane conventions), section 7 (testing), and section 8 (run commands).
  3. Draft docs/todolist.md rows for each lane. Run the row-granularity self-check
     in SKILL.md before finalizing.
  4. docs/_subagent-prompt.template.md is a reference for writing each subagent's
     launch prompt, not a doc the project tracks. Move or delete it after Phase B.
EOF
