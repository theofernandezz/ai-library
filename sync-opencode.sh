#!/usr/bin/env bash
# ==============================================================================
# sync-opencode.sh — Syncs skills & agents into .opencode/ within this repo.
#
# Run this after making any changes to skills/, agents/, or AGENTS.md so the
# .opencode/ directory stays in sync.
#
# Usage: ./sync-opencode.sh [--dry-run]
# ==============================================================================

set -euo pipefail

LIBRARY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="$LIBRARY_DIR/.opencode"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

DRY_RUN=false
COPIED=0

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

cp_file() {
  local src="$1" dst="$2"
  [[ ! -f "$src" ]] && return
  if $DRY_RUN; then
    echo -e "${YELLOW}  [dry-run]${RESET} ${src#"$LIBRARY_DIR/"} → ${dst#"$LIBRARY_DIR/"}"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    echo -e "${GREEN}  ✔${RESET} ${dst#"$LIBRARY_DIR/"}"
  fi
  ((COPIED++)) || true
}

cp_dir() {
  local src="$1" dst="$2"
  [[ ! -d "$src" ]] && return
  if $DRY_RUN; then
    echo -e "${YELLOW}  [dry-run]${RESET} ${src#"$LIBRARY_DIR/"}/ → ${dst#"$LIBRARY_DIR/"}/"
  else
    mkdir -p "$dst"
    cp -r "$src/." "$dst/"
    echo -e "${GREEN}  ✔${RESET} ${dst#"$LIBRARY_DIR/"}/"
  fi
  ((COPIED++)) || true
}

echo ""
echo -e "${BOLD}Syncing → .opencode/${RESET}"
$DRY_RUN && echo -e "${YELLOW}  DRY RUN — no files will be written${RESET}"
echo ""

# AGENTS.md
cp_file "$LIBRARY_DIR/AGENTS.md"          "$OPENCODE_DIR/AGENTS.md"

# All generic skills
cp_dir  "$LIBRARY_DIR/skills/generic"     "$OPENCODE_DIR/skills/generic"

# Skills index + meta-skills
cp_file "$LIBRARY_DIR/skills/_index.md"  "$OPENCODE_DIR/skills/_index.md"
cp_dir  "$LIBRARY_DIR/skills/skill-creator" "$OPENCODE_DIR/skills/skill-creator"
cp_dir  "$LIBRARY_DIR/skills/skill-sync"    "$OPENCODE_DIR/skills/skill-sync"
cp_dir  "$LIBRARY_DIR/skills/feedback-loop" "$OPENCODE_DIR/skills/feedback-loop"

# Agents (from the root agents/ dir, not .opencode/agents — avoids self-copy)
cp_dir  "$LIBRARY_DIR/agents"            "$OPENCODE_DIR/agents"

echo ""
if $DRY_RUN; then
  echo -e "${YELLOW}Dry run complete.${RESET} Would sync ${BOLD}$COPIED${RESET} items."
else
  echo -e "${GREEN}Done.${RESET} Synced ${BOLD}$COPIED${RESET} items into ${CYAN}.opencode/${RESET}"
fi
echo ""
