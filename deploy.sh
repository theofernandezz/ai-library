#!/usr/bin/env bash
# ==============================================================================
# deploy.sh — AI Library Deployer
# Copies this library's skills, agents, and config files into a target repo.
#
# Usage:
#   ./deploy.sh <TARGET_REPO_PATH> [OPTIONS]
#
# Options:
#   --mode <mode>     Deployment mode (default: auto)
#                       auto       → detect structure and deploy accordingly
#                       root       → deploy to repo root only
#                       opencode   → deploy to .opencode/ only
#                       both       → deploy to root AND .opencode/
#   --profile <name>  Deploy only skills for a specific project type (default: full)
#                       web-app    → nextjs, db, auth, ui, testing, api (10 skills)
#                       mobile     → react-native, state, performance, testing (5 skills)
#                       static     → nextjs, ui, seo, performance, a11y (6 skills)
#                       api        → api-design, db, security, error-handling (6 skills)
#                       full       → all skills (default)
#   --dry-run         Show what would be copied without actually copying
#   --force           Overwrite even if target files are newer
#   --help            Show this help message
#
# Examples:
#   ./deploy.sh ../my-project
#   ./deploy.sh ../my-project --mode both
#   ./deploy.sh ../my-project --profile web-app
#   ./deploy.sh ../my-project --dry-run
# ==============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Source directory (this library) ─────────────────────────────────────────
LIBRARY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ────────────────────────────────────────────────────────────────
TARGET_REPO=""
MODE="auto"
PROFILE="full"
DRY_RUN=false
FORCE=false
COPIED=0
SKIPPED=0
ERRORS=0

# ── Skill Profiles ─────────────────────────────────────────────────────────
# Each profile is a space-separated list of skill directory names.
PROFILE_WEB_APP="nextjs-core database security typescript react-patterns ui-engineering error-handling testing api-design env-config"
PROFILE_MOBILE="react-native typescript state-management performance testing"
PROFILE_STATIC="nextjs-core ui-engineering seo performance typescript accessibility"
PROFILE_API="api-design database security error-handling typescript env-config"
# "full" = all skills (no filtering)

# ── Helpers ─────────────────────────────────────────────────────────────────
log()    { echo -e "${BLUE}[deploy]${RESET} $*"; }
ok()     { echo -e "${GREEN}  ✔${RESET} $*"; }
skip()   { echo -e "${YELLOW}  ○${RESET} $*"; }
warn()   { echo -e "${YELLOW}[warn]${RESET} $*"; }
error()  { echo -e "${RED}[error]${RESET} $*" >&2; }
header() { echo -e "\n${BOLD}${CYAN}── $* ──────────────────────────────────────${RESET}"; }

usage() {
  cat <<'EOF'
Usage:
  ./deploy.sh <TARGET_REPO_PATH> [OPTIONS]

Options:
  --mode <mode>     Deployment mode (default: auto)
                      auto       → detect structure and deploy accordingly
                      root       → deploy to repo root only
                      opencode   → deploy to .opencode/ only
                      both       → deploy to root AND .opencode/
  --profile <name>  Deploy only skills for a specific project type (default: full)
                      web-app    → nextjs, db, auth, ui, testing, api (10 skills)
                      mobile     → react-native, state, performance, testing (5 skills)
                      static     → nextjs, ui, seo, performance, a11y (6 skills)
                      api        → api-design, db, security, error-handling (6 skills)
                      full       → all skills (default)
  --dry-run         Show what would be copied without actually copying
  --force           Overwrite even if target files are newer
  --help            Show this help message

Examples:
  ./deploy.sh ../my-project
  ./deploy.sh ../my-project --mode both
  ./deploy.sh ../my-project --profile web-app
  ./deploy.sh ../my-project --dry-run
  ./deploy.sh ../my-project --mode opencode --force
EOF
  exit 0
}

# Copy a single file, respecting --dry-run and --force
copy_file() {
  local src="$1"
  local dst="$2"

  if [[ ! -f "$src" ]]; then
    warn "Source not found, skipping: $src"
    return
  fi

  local dst_dir
  dst_dir="$(dirname "$dst")"

  if $DRY_RUN; then
    echo -e "${YELLOW}  [dry-run]${RESET} cp $src → $dst"
    ((COPIED++)) || true
    return
  fi

  mkdir -p "$dst_dir"

  # Skip if destination is newer (unless --force)
  if [[ -f "$dst" ]] && ! $FORCE; then
    if [[ "$dst" -nt "$src" ]]; then
      skip "Newer, skipped: ${dst#"$TARGET_REPO/"}"
      ((SKIPPED++)) || true
      return
    fi
  fi

  cp "$src" "$dst"
  ok "${dst#"$TARGET_REPO/"}"
  ((COPIED++)) || true
}

# Copy an entire directory recursively
copy_dir() {
  local src="$1"
  local dst="$2"

  if [[ ! -d "$src" ]]; then
    warn "Source dir not found, skipping: $src"
    return
  fi

  if $DRY_RUN; then
    echo -e "${YELLOW}  [dry-run]${RESET} cp -r $src → $dst"
    ((COPIED++)) || true
    return
  fi

  mkdir -p "$dst"
  cp -r "$src/." "$dst/"
  ok "${dst#"$TARGET_REPO/"}"
  ((COPIED++)) || true
}

# Resolve the active profile into a skill list
get_profile_skills() {
  case "$PROFILE" in
    web-app) echo "$PROFILE_WEB_APP" ;;
    mobile)  echo "$PROFILE_MOBILE" ;;
    static)  echo "$PROFILE_STATIC" ;;
    api)     echo "$PROFILE_API" ;;
    full)    echo "" ;;  # empty = no filtering
    *)
      error "Unknown profile: $PROFILE. Use web-app | mobile | static | api | full"
      exit 1
      ;;
  esac
}

# Check if a skill name is in the active profile
skill_in_profile() {
  local skill="$1"
  local skills
  skills="$(get_profile_skills)"

  # "full" profile → no filtering, all skills pass
  if [[ -z "$skills" ]]; then
    return 0
  fi

  for s in $skills; do
    if [[ "$s" == "$skill" ]]; then
      return 0
    fi
  done
  return 1
}

# Copy skills from a source dir to a destination, respecting --profile
copy_skills_filtered() {
  local src="$1"
  local dst="$2"

  if [[ ! -d "$src" ]]; then
    warn "Source dir not found, skipping: $src"
    return
  fi

  for skill_dir in "$src"/*/; do
    [[ -d "$skill_dir" ]] || continue
    local skill_name
    skill_name="$(basename "$skill_dir")"
    if skill_in_profile "$skill_name"; then
      copy_dir "$skill_dir" "$dst/$skill_name"
    else
      skip "Skill '$skill_name' not in profile '$PROFILE', skipped"
      ((SKIPPED++)) || true
    fi
  done
}

# ── Generate project CLAUDE.md (only for new projects) ──────────────────────
generate_project_claude_md() {
  local target="$1"
  local dst="$target/CLAUDE.md"

  # Never overwrite an existing CLAUDE.md unless --force is set
  if [[ -f "$dst" ]] && ! $FORCE; then
    skip "CLAUDE.md already exists — skipping (run with --force to overwrite)"
    ((SKIPPED++)) || true
    return
  fi

  if $DRY_RUN; then
    echo -e "${YELLOW}  [dry-run]${RESET} generate CLAUDE.md → $dst"
    ((COPIED++)) || true
    return
  fi

  local project_name
  project_name="$(basename "$target")"

  cat > "$dst" << EOF
# $project_name

> Claude Code configuration for this project.
> Top section: project-specific context. Bottom section: ai-library rules (don't edit manually).

---

## 📋 Project Context

<!-- Fill this in. Claude uses this to make decisions consistent with your project. -->

### Stack
- Framework:
- Database:
- Auth:
- Styling:

### Key decisions
<!-- Why did you choose this stack? Any non-obvious architectural decisions? -->

### Domain conventions
<!-- Naming, patterns, or rules specific to this project -->

### Constraints
<!-- Performance requirements, compliance, deadlines, etc. -->

---

<!-- ⬇️ ai-library configuration — do not edit below this line ⬇️ -->
<!-- Update by re-running: ./deploy.sh $(pwd) --force -->

$(cat "$LIBRARY_DIR/CLAUDE.md")
EOF

  ok "CLAUDE.md (generated from template)"
  ((COPIED++)) || true
}

# ── Write version file ────────────────────────────────────────────────────────
write_version_file() {
  local target="$1"
  local dst="$target/.ai-library-version"
  local commit date
  commit="$(git -C "$LIBRARY_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  date="$(date +%Y-%m-%d)"

  if $DRY_RUN; then
    echo -e "${YELLOW}  [dry-run]${RESET} → .ai-library-version"
    return
  fi

  {
    echo "deployed: $date"
    echo "commit:   $commit"
    echo "source:   $LIBRARY_DIR"
  } > "$dst"
  ok ".ai-library-version"
}

# ── Deploy to repo root ──────────────────────────────────────────────────────
deploy_root() {
  local target="$1"
  header "Root ($target)"

  # Entry point files
  copy_file "$LIBRARY_DIR/AGENTS.md"  "$target/AGENTS.md"
  copy_file "$LIBRARY_DIR/GEMINI.md"  "$target/GEMINI.md"
  generate_project_claude_md "$target"

  # Agents
  copy_dir "$LIBRARY_DIR/agents"     "$target/agents"

  # Skills — meta skills and index (always deployed)
  copy_file "$LIBRARY_DIR/skills/_index.md"    "$target/skills/_index.md"
  copy_file "$LIBRARY_DIR/skills/README.md"    "$target/skills/README.md"
  copy_dir "$LIBRARY_DIR/skills/skill-creator" "$target/skills/skill-creator"
  copy_dir "$LIBRARY_DIR/skills/skill-sync"    "$target/skills/skill-sync"
  copy_dir "$LIBRARY_DIR/skills/feedback-loop" "$target/skills/feedback-loop"

  # Sub-agent AGENTS.md files (legacy — kept for backward compat)
  copy_file "$LIBRARY_DIR/ui/AGENTS.md"      "$target/ui/AGENTS.md"
  copy_file "$LIBRARY_DIR/auth/AGENTS.md"    "$target/auth/AGENTS.md"         2>/dev/null || true
  copy_file "$LIBRARY_DIR/backend/AGENTS.md" "$target/backend/AGENTS.md"      2>/dev/null || true
  copy_file "$LIBRARY_DIR/testing/AGENTS.md" "$target/testing/AGENTS.md"      2>/dev/null || true

  # Native Claude Code subagents (also read by VS Code Copilot from .claude/agents/)
  copy_dir "$LIBRARY_DIR/.claude/agents"     "$target/.claude/agents"

  # Native Claude Code skills — enables `skills:` field in subagent definitions
  # Copies skills/generic/* → .claude/skills/* (filtered by --profile)
  copy_skills_filtered "$LIBRARY_DIR/skills/generic" "$target/.claude/skills"
}

# ── Deploy to .opencode/ ─────────────────────────────────────────────────────
deploy_opencode() {
  local target="$1/.opencode"
  header ".opencode ($target)"

  # .opencode has its own agents/ and skills/ (same content, different location)
  copy_dir "$LIBRARY_DIR/.opencode/agents"  "$target/agents"
  copy_skills_filtered "$LIBRARY_DIR/skills/generic" "$target/skills/generic"
  copy_file "$LIBRARY_DIR/skills/_index.md" "$target/skills/_index.md"
  copy_dir "$LIBRARY_DIR/skills/skill-creator" "$target/skills/skill-creator"
  copy_dir "$LIBRARY_DIR/skills/skill-sync"    "$target/skills/skill-sync"
  copy_dir "$LIBRARY_DIR/skills/feedback-loop" "$target/skills/feedback-loop"

  # Root AGENTS.md for opencode is placed directly in .opencode/
  copy_file "$LIBRARY_DIR/AGENTS.md"  "$target/AGENTS.md"
}

# ── Auto-detect mode ─────────────────────────────────────────────────────────
detect_mode() {
  local target="$1"
  local has_root=false
  local has_opencode=false

  [[ -f "$target/AGENTS.md" || -f "$target/CLAUDE.md" ]] && has_root=true
  [[ -d "$target/.opencode" ]]                            && has_opencode=true

  if $has_root && $has_opencode; then
    echo "both"
  elif $has_opencode; then
    echo "opencode"
  else
    echo "root"   # Default: deploy to root for new repos
  fi
}

# ── Parse arguments ──────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  error "No target repo specified."
  echo ""
  usage
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h) usage ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force)   FORCE=true;   shift ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    -*)
      error "Unknown option: $1"
      exit 1
      ;;
    *)
      TARGET_REPO="$1"
      shift
      ;;
  esac
done

# ── Validate target ──────────────────────────────────────────────────────────
if [[ -z "$TARGET_REPO" ]]; then
  error "No target repo specified."
  exit 1
fi

# Resolve absolute path
TARGET_REPO="$(cd "$TARGET_REPO" 2>/dev/null && pwd)" || {
  error "Target directory does not exist: $TARGET_REPO"
  exit 1
}

if [[ "$TARGET_REPO" == "$LIBRARY_DIR" ]]; then
  error "Target is the same as the library directory. Aborting."
  exit 1
fi

# ── Auto-detect if not specified ─────────────────────────────────────────────
if [[ "$MODE" == "auto" ]]; then
  MODE="$(detect_mode "$TARGET_REPO")"
  log "Auto-detected mode: ${BOLD}$MODE${RESET}"
fi

# ── Summary header ───────────────────────────────────────────────────────────
echo ""
# ── Validate profile ──────────────────────────────────────────────────────────
get_profile_skills > /dev/null  # exits with error if invalid

echo -e "${BOLD}AI Library Deploy${RESET}"
echo -e "  Library : ${CYAN}$LIBRARY_DIR${RESET}"
echo -e "  Target  : ${CYAN}$TARGET_REPO${RESET}"
echo -e "  Mode    : ${CYAN}$MODE${RESET}"
echo -e "  Profile : ${CYAN}$PROFILE${RESET}"
$DRY_RUN && echo -e "  ${YELLOW}DRY RUN — no files will be written${RESET}"
$FORCE   && echo -e "  ${YELLOW}FORCE — newer destination files will be overwritten${RESET}"
echo ""

# ── Execute ───────────────────────────────────────────────────────────────────
case "$MODE" in
  root)
    deploy_root "$TARGET_REPO"
    write_version_file "$TARGET_REPO"
    ;;
  opencode)
    deploy_opencode "$TARGET_REPO"
    write_version_file "$TARGET_REPO"
    ;;
  both)
    deploy_root     "$TARGET_REPO"
    deploy_opencode "$TARGET_REPO"
    write_version_file "$TARGET_REPO"
    ;;
  *)
    error "Unknown mode: $MODE. Use root | opencode | both | auto"
    exit 1
    ;;
esac

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo -e "${YELLOW}Dry run complete.${RESET} Would have copied ${BOLD}$COPIED${RESET} items."
else
  echo -e "${GREEN}Done.${RESET} Copied ${BOLD}$COPIED${RESET} items, skipped ${BOLD}$SKIPPED${RESET} (destination was newer — use --force to overwrite)."
fi
echo ""
