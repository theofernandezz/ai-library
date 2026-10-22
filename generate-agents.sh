#!/usr/bin/env bash
# ==============================================================================
# generate-agents.sh — Generates agents/*.md and .omp/agents/*.md from
# .claude/agents/*.md, the single source of truth for subagent definitions.
#
# .claude/agents/*.md are real Claude Code subagents (frontmatter: name,
# description, tools, model, skills). This script derives:
#   - agents/<name>.md         — plain doc (no frontmatter) for humans and
#                                 tools without subagent support (Cursor, Copilot)
#   - .omp/agents/<name>.md    — omp subagent (frontmatter: name, description,
#                                 tools, model, thinking-level, autoload-skills —
#                                 omp doesn't scan .claude/agents)
#
# Usage: ./generate-agents.sh [--check]
#   --check  don't write anything; exit 1 if generated output would differ
#            from what's on disk (used by the pre-commit hook and CI)
# ==============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$REPO_ROOT/.claude/agents"
ROOT_OUT_DIR="$REPO_ROOT/agents"
OMP_OUT_DIR="$REPO_ROOT/.omp/agents"

CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

STALE=0
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

title_case() {
  case "$1" in
    ui) echo "UI" ;;
    *) echo "$(tr '[:lower:]' '[:upper:]' <<<"${1:0:1}")${1:1}" ;;
  esac
}

# Claude Code model alias → omp selector. Claude Code's alias tracks the latest
# model; omp needs a concrete provider/model-id (see `omp models anthropic`).
# TODO: bump these IDs when a new Claude generation ships — omp won't follow the alias.
omp_model() {
  case "$1" in
    sonnet) echo "anthropic/claude-sonnet-5-5" ;;
    opus) echo "anthropic/claude-opus-5-5" ;;
    haiku) echo "anthropic/claude-haiku-5-5" ;;
    *) echo "generate-agents.sh: no omp mapping for model '$1'" >&2; exit 1 ;;
  esac
}

for src in "$SRC_DIR"/*.md; do
  name="$(basename "$src" .md)"

  # Assumes frontmatter is the only "---" block in the file (no horizontal
  # rules in the body) — true for all current .claude/agents/*.md.
  frontmatter="$(awk '/^---$/{c++; next} c==1{print}' "$src")"
  body="$(awk '/^---$/{c++; next} c>=2{print}' "$src" | sed '1{/^$/d;}')"
  description="$(grep '^description:' <<<"$frontmatter" | sed 's/^description: *//')"
  skills_inline="$(sed -n '/^skills:/,$p' <<<"$frontmatter" | tail -n +2 | sed -n 's/^  - \(.*\)/`\1`/p' | paste -sd, - | sed 's/,/, /g')"

  title="$(title_case "$name") Agent"

  root_file="$TMP_DIR/root-$name.md"
  {
    echo "<!-- GENERATED FILE — edit .claude/agents/$name.md instead. Run ./generate-agents.sh to regenerate. -->"
    echo ""
    echo "# $title"
    echo ""
    echo "> **Rol:** $description"
    echo ""
    if [[ -n "$skills_inline" ]]; then
      echo "**Skills:** $skills_inline"
      echo ""
    fi
    echo "---"
    echo ""
    echo "$body"
  } >"$root_file"

  # omp: same tools lowercased plus `yield` (how an omp subagent submits its result —
  # omp 18.8.9 adds it on its own, listing it keeps older versions working), effort → thinking-level,
  # skills → autoload-skills. description is double-quoted — it contains ": ",
  # which breaks a plain YAML scalar.
  tools_csv="$(grep '^tools:' <<<"$frontmatter" | sed 's/^tools: *//' | tr '[:upper:]' '[:lower:]'), yield"
  model="$(omp_model "$(grep '^model:' <<<"$frontmatter" | sed 's/^model: *//')")"
  effort="$(grep '^effort:' <<<"$frontmatter" | sed 's/^effort: *//')"
  skills_csv="$(sed -n '/^skills:/,$p' <<<"$frontmatter" | tail -n +2 | sed -n 's/^  - \(.*\)/\1/p' | paste -sd, - | sed 's/,/, /g')"
  description_quoted="\"$(sed 's/\\/\\\\/g; s/"/\\"/g' <<<"$description")\""

  omp_file="$TMP_DIR/omp-$name.md"
  {
    echo "---"
    echo "name: $name"
    echo "description: $description_quoted"
    echo "tools: $tools_csv"
    echo "model: $model"
    [[ -n "$effort" ]] && echo "thinking-level: $effort"
    [[ -n "$skills_csv" ]] && echo "autoload-skills: $skills_csv"
    echo "---"
    echo ""
    echo "$body"
  } >"$omp_file"

  for pair in "$root_file:$ROOT_OUT_DIR/$name.md" "$omp_file:$OMP_OUT_DIR/$name.md"; do
    new="${pair%%:*}"
    dst="${pair##*:}"
    if [[ "$CHECK" == "1" ]]; then
      if [[ ! -f "$dst" ]] || ! diff -q "$new" "$dst" >/dev/null 2>&1; then
        echo "STALE: ${dst#"$REPO_ROOT/"}"
        STALE=1
      fi
    else
      mkdir -p "$(dirname "$dst")"
      cp "$new" "$dst"
    fi
  done
done

# .claude/agents/feature.md was removed — drop any stale generated leftovers.
for stale in "$ROOT_OUT_DIR/feature.md"; do
  if [[ -f "$stale" ]]; then
    if [[ "$CHECK" == "1" ]]; then
      echo "STALE: ${stale#"$REPO_ROOT/"} (source removed)"
      STALE=1
    else
      rm "$stale"
    fi
  fi
done

if [[ "$CHECK" == "1" ]]; then
  if [[ "$STALE" == "1" ]]; then
    echo "Generated agents are stale. Run ./generate-agents.sh to fix." >&2
    exit 1
  fi
  echo "agents/ and .omp/agents/ are up to date."
else
  echo "Generated $(ls "$SRC_DIR"/*.md | wc -l | tr -d ' ') agents → agents/, .omp/agents/"
fi
