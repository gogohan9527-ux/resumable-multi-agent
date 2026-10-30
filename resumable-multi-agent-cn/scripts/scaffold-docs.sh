#!/usr/bin/env bash
# scaffold-docs.sh — bootstrap docs/ for a resumable-multi-agent project (macOS / Linux / WSL)
#
# Usage:
#   ./scaffold-docs.sh --root /path/to/project --name my-app \
#                      [--lane-a backend] [--lane-b frontend] [--contract interface]
#
# What it does:
#   1. Creates <root>/docs/ if missing.
#   2. Copies the four asset templates into docs/ (subagent-prompt.template.md is copied as
#      _subagent-prompt.template.md — orchestrator reference, deleted in Phase C cleanup).
#   3. Replaces the most common placeholders (<项目名>, <Lane A 名称>, <Lane B 名称>, <contract>)
#      across the four files in one pass.
#
# It does NOT fill in PRD content, explanation §3+ (naming/run-commands/etc.), or todolist rows —
# those require human/orchestrator judgement per project. This script just removes the mechanical
# copy-and-replace toil so the orchestrator can start writing actual content immediately.
#
# This script is for FIRST-RUN initialization only. On follow-up runs the script refuses to
# overwrite — that is intentional. The orchestrator should instead:
#   - Read the existing persistent docs (prd.md, explanation.md, contract, todolist.md).
#   - Have lanes write contract additions to docs/<contract>.draft.md (not the persistent file).
#   - In Phase C, merge drafts into persistent files with deprecation/version markers and append
#     a new dated section to docs/todolist.md. See SKILL.md "Phase C — Merge & cleanup".

set -euo pipefail

ROOT=""
NAME=""
LANE_A="<Lane A 名称>"
LANE_B="<Lane B 名称>"
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
    echo "error: $DOCS_DIR already exists — refusing to overwrite. Delete or move it first." >&2
    exit 1
fi

if [[ ! -d "$ASSETS_DIR" ]]; then
    echo "error: assets directory not found at $ASSETS_DIR — is the skill installed correctly?" >&2
    exit 1
fi

mkdir -p "$DOCS_DIR"

# Portable in-place edit: write to a temp file, then mv. Avoids GNU vs BSD sed -i differences.
copy_and_substitute() {
    local src="$1"
    local dst="$2"
    # Use a Python one-liner for cross-platform string replacement that handles UTF-8 reliably.
    python3 - "$src" "$dst" "$NAME" "$LANE_A" "$LANE_B" "$CONTRACT" <<'PY'
import sys, pathlib
src, dst, name, lane_a, lane_b, contract = sys.argv[1:7]
text = pathlib.Path(src).read_text(encoding="utf-8")
text = (text
    .replace("<项目名>", name)
    .replace("<Lane A 名称>", lane_a)
    .replace("<Lane B 名称>", lane_b)
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
  1. Fill in docs/prd.md sections 1–10 from the user dialogue.
  2. Fill in docs/explanation.md §1 (repo tree), §3 (naming), §4 (per-lane conventions),
     §7 (testing), §8 (run commands).
  3. Draft docs/todolist.md rows for each lane (run the row-granularity self-check
     in SKILL.md before finalising).
  4. docs/_subagent-prompt.template.md is a reference for writing each subagent's
     launch prompt — not a doc the project tracks. Move or delete after Phase B.
EOF
