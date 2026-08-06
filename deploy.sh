#!/usr/bin/env bash
# ==============================================================================
# deploy.sh — AI Library Deployer
# Copies this library's skills, agents, and config files into a target repo.
#
# No local clone? `npx github:theofernandezz/ai-library` does the same thing
# without cloning first — see bin/index.mjs / README.md.
#
# Usage:
#   ./deploy.sh                          → interactive menu
#   ./deploy.sh <TARGET_REPO_PATH>       → interactive menu with target pre-selected
#   ./deploy.sh <TARGET_REPO_PATH> [OPTIONS]
#
# Options:
#   --mode <mode>     Deployment mode (default: auto)
#                       auto       → detect structure and deploy accordingly
#                       root       → deploy to repo root only
#                       opencode   → deploy to .opencode/ only
#                       both       → deploy to root AND .opencode/
#   --profile <name>  Deploy only skills for a specific project type (default: full)
#                       web-app    → nextjs, db, auth, ui, testing, api, email (11 skills)
#                       mobile     → react-native, state, performance, testing (5 skills)
#                       static     → nextjs, ui, seo, performance, a11y (6 skills)
#                       api        → api-design, db, security, error-handling, email (7 skills)
#                       custom     → choose individual skills interactively
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

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Source directory (this library) ────────────────────────────────────────────
LIBRARY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ───────────────────────────────────────────────────────────────────
TARGET_REPO=""
MODE="auto"
PROFILE="full"
DRY_RUN=false
FORCE=false
INTERACTIVE=false
CUSTOM_SKILLS=()
COPIED=0
SKIPPED=0
ERRORS=0

# ── Skill Profiles ─────────────────────────────────────────────────────────────
PROFILE_WEB_APP="nextjs-core database security typescript react-patterns ui-engineering error-handling testing api-design email env-config"
PROFILE_MOBILE="react-native typescript state-management performance testing"
PROFILE_STATIC="nextjs-core ui-engineering seo performance typescript accessibility"
PROFILE_API="api-design database security error-handling typescript email env-config"

# ── All available generic skills (auto-discovered) ─────────────────────────────
get_all_skills() {
  local generic_dir="$LIBRARY_DIR/skills/generic"
  if [[ -d "$generic_dir" ]]; then
    find "$generic_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
  fi
}

# ── Helpers ───────────────────────────────────────────────────────────────────
log()    { echo -e "${BLUE}[deploy]${RESET} $*"; }
ok()     { echo -e "${GREEN}  ✔${RESET} $*"; }
skip()   { echo -e "${YELLOW}  ○${RESET} $*"; }
warn()   { echo -e "${YELLOW}[warn]${RESET} $*"; }
error()  { echo -e "${RED}[error]${RESET} $*" >&2; }
header() { echo -e "\n${BOLD}${CYAN}── $* ──────────────────────────────────────${RESET}"; }
divider(){ echo -e "${DIM}────────────────────────────────────────────────────${RESET}"; }

# ── Interactive UI helpers ───────────────────────────────────────────────────
supports_interactive_ui() {
  [[ -t 0 && -t 1 ]]
}

# Renders a single-choice menu. Result is stored in MENU_SELECTED (1-based).
menu_select() {
  local prompt="$1"
  local default_index="$2"
  shift 2
  local options=("$@")
  local count="${#options[@]}"

  if [[ "$count" -eq 0 ]]; then
    error "menu_select called with no options"
    exit 1
  fi

  if ! supports_interactive_ui; then
    echo -e "  ${DIM}$prompt${RESET}"
    echo ""
    PS3=""
    select _opt in "${options[@]}"; do
      if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 1 && REPLY <= count )); then
        MENU_SELECTED="$REPLY"
        break
      fi
      echo -e "  ${RED}Invalid choice, enter 1-$count.${RESET}"
    done
    return
  fi

  local current="$default_index"
  local rendered=false
  local menu_lines=$((count + 2))

  while true; do
    if $rendered; then
      printf "\033[%dA" "$menu_lines"
    fi

    printf "\033[2K\r  %b\n" "${DIM}${prompt}${RESET}"
    printf "\033[2K\r  %b\n" "${DIM}Use ↑/↓ and Enter to select.${RESET}"

    local i
    for ((i = 1; i <= count; i++)); do
      if (( i == current )); then
        printf "\033[2K\r  %b %b\n" "${CYAN}●${RESET}" "${BOLD}${options[$((i - 1))]}${RESET}"
      else
        printf "\033[2K\r  %b %b\n" "${DIM}○${RESET}" "${options[$((i - 1))]}"
      fi
    done

    rendered=true

    local key
    IFS= read -rsn1 key
    case "$key" in
      "")
        MENU_SELECTED="$current"
        return
        ;;
      $'\x1b')
        IFS= read -rsn2 key
        case "$key" in
          "[A")
            if (( current > 1 )); then
              ((current--))
            else
              current="$count"
            fi
            ;;
          "[B")
            if (( current < count )); then
              ((current++))
            else
              current=1
            fi
            ;;
        esac
        ;;
      [1-9])
        if (( key >= 1 && key <= count )); then
          current="$key"
        fi
        ;;
    esac
  done
}

# Yes/No confirmation helper. Returns 0 for yes, 1 for no.
menu_confirm() {
  local prompt="$1"
  local default_yes="${2:-true}"
  local default_index=1

  if [[ "$default_yes" != "true" ]]; then
    default_index=2
  fi

  local options=(
    "Yes"
    "No"
  )

  menu_select "$prompt" "$default_index" "${options[@]}"
  [[ "$MENU_SELECTED" -eq 1 ]]
}

usage() {
  cat <<'EOF'
Usage:
  ./deploy.sh                          → launch interactive menu
  ./deploy.sh <TARGET_REPO_PATH>       → launch interactive menu with target pre-selected
  ./deploy.sh <TARGET_REPO_PATH> [OPTIONS]

Options:
  --mode <mode>     Deployment mode (default: auto)
                      auto       → detect structure and deploy accordingly
                      root       → deploy to repo root only
                      opencode   → deploy to .opencode/ only
                      both       → deploy to root AND .opencode/
  --profile <name>  Deploy only skills for a specific project type (default: full)
                      web-app    → nextjs, db, auth, ui, testing, api, email (11 skills)
                      mobile     → react-native, state, performance, testing (5 skills)
                      static     → nextjs, ui, seo, performance, a11y (6 skills)
                      api        → api-design, db, security, error-handling, email (7 skills)
                      custom     → choose individual skills interactively
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

# ── Resolve and validate target path ─────────────────────────────────────────
resolve_and_validate_target_repo() {
  if [[ -z "$TARGET_REPO" ]]; then
    error "No target repo specified."
    exit 1
  fi

  TARGET_REPO="$(cd "$TARGET_REPO" 2>/dev/null && pwd)" || {
    error "Target directory does not exist: $TARGET_REPO"
    exit 1
  }

  if [[ "$TARGET_REPO" == "$LIBRARY_DIR" ]]; then
    error "Target is the same as the library directory. Aborting."
    exit 1
  fi
}

# ── Copy a single file, respecting --dry-run and --force ─────────────────────
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

# ── Copy an entire directory recursively ─────────────────────────────────────
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

# ── Resolve the active profile into a skill list ──────────────────────────────
get_profile_skills() {
  case "$PROFILE" in
    web-app) echo "$PROFILE_WEB_APP" ;;
    mobile)  echo "$PROFILE_MOBILE" ;;
    static)  echo "$PROFILE_STATIC" ;;
    api)     echo "$PROFILE_API" ;;
    custom)  echo "${CUSTOM_SKILLS[*]:-}" ;;
    full)    echo "" ;;  # empty = no filtering
    *)
      error "Unknown profile: $PROFILE. Use web-app | mobile | static | api | custom | full"
      exit 1
      ;;
  esac
}

# ── Check if a skill name is in the active profile ────────────────────────────
skill_in_profile() {
  local skill="$1"
  local skills
  skills="$(get_profile_skills)"

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

# ── Copy skills filtered by profile ──────────────────────────────────────────
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

# ── Generate project CLAUDE.md ────────────────────────────────────────────────
generate_project_claude_md() {
  local target="$1"
  local dst="$target/CLAUDE.md"

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

<!-- Claude: if the fields below are still empty, this section hasn't been filled in yet.
     Before starting other work, ask the developer if they want to fill it in now (2-3 min).
     If yes, read skills/project-setup/SKILL.md and run its Interview Protocol — one question
     at a time, editing this file after each answer. If no, drop it and continue normally. -->

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

# ── Deploy to repo root ───────────────────────────────────────────────────────
deploy_root() {
  local target="$1"
  header "Root ($target)"

  copy_file "$LIBRARY_DIR/AGENTS.md"  "$target/AGENTS.md"
  copy_file "$LIBRARY_DIR/GEMINI.md"  "$target/GEMINI.md"
  generate_project_claude_md "$target"

  copy_dir "$LIBRARY_DIR/agents"     "$target/agents"

  # Copy top-level skill files
  for skill_file in "$LIBRARY_DIR"/skills/*.md "$LIBRARY_DIR"/skills/*.sh; do
    [[ -f "$skill_file" ]] || continue
    copy_file "$skill_file" "$target/skills/$(basename "$skill_file")"
  done

  # Copy all non-generic skill directories (meta-skills, governance, project-setup, etc.)
  for skill_dir in "$LIBRARY_DIR"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    local dir_name
    dir_name="$(basename "$skill_dir")"
    # generic/ is handled separately via copy_skills_filtered
    [[ "$dir_name" == "generic" ]] && continue
    copy_dir "$skill_dir" "$target/skills/$dir_name"
  done

  copy_file "$LIBRARY_DIR/ui/AGENTS.md"      "$target/ui/AGENTS.md"
  copy_file "$LIBRARY_DIR/auth/AGENTS.md"    "$target/auth/AGENTS.md"         2>/dev/null || true
  copy_file "$LIBRARY_DIR/backend/AGENTS.md" "$target/backend/AGENTS.md"      2>/dev/null || true
  copy_file "$LIBRARY_DIR/testing/AGENTS.md" "$target/testing/AGENTS.md"      2>/dev/null || true

  copy_dir "$LIBRARY_DIR/.claude/agents"     "$target/.claude/agents"

  copy_skills_filtered "$LIBRARY_DIR/skills/generic" "$target/.claude/skills"
  # Also at skills/generic — the path CLAUDE.md/AGENTS.md/GEMINI.md document and non-Claude tools read.
  copy_skills_filtered "$LIBRARY_DIR/skills/generic" "$target/skills/generic"
}

# ── Deploy to .opencode/ ──────────────────────────────────────────────────────
deploy_opencode() {
  local target="$1/.opencode"
  header ".opencode ($target)"

  copy_dir "$LIBRARY_DIR/.opencode/agents"  "$target/agents"
  copy_skills_filtered "$LIBRARY_DIR/skills/generic" "$target/skills/generic"

  # Copy top-level skill files
  for skill_file in "$LIBRARY_DIR"/skills/*.md "$LIBRARY_DIR"/skills/*.sh; do
    [[ -f "$skill_file" ]] || continue
    copy_file "$skill_file" "$target/skills/$(basename "$skill_file")"
  done

  # Copy all non-generic skill directories (meta-skills, governance, project-setup, etc.)
  for skill_dir in "$LIBRARY_DIR"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    local dir_name
    dir_name="$(basename "$skill_dir")"
    # generic/ is handled separately via copy_skills_filtered above
    [[ "$dir_name" == "generic" ]] && continue
    copy_dir "$skill_dir" "$target/skills/$dir_name"
  done

  copy_file "$LIBRARY_DIR/AGENTS.md"  "$target/AGENTS.md"
}

# ── Auto-detect mode ──────────────────────────────────────────────────────────
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
    echo "root"
  fi
}

# ══════════════════════════════════════════════════════════════════════════════
# ── INTERACTIVE MENU ─────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

print_banner() {
  echo ""
  echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${CYAN}║        🚀  AI Library Deployer             ║${RESET}"
  echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════╝${RESET}"
  echo ""
}

# Ask for target repo interactively
ask_target_repo() {
  echo -e "${BOLD}Step 1 → Target repository${RESET}"
  echo -e "${DIM}Path to the project you want to deploy the library into.${RESET}"
  echo ""
  while true; do
    printf "  Enter path (absolute or relative): "
    read -r input_path
    if [[ -z "$input_path" ]]; then
      echo -e "  ${RED}Path cannot be empty.${RESET}"
      continue
    fi
    # Expand ~ manually
    input_path="${input_path/#\~/$HOME}"
    if [[ ! -d "$input_path" ]]; then
      echo -e "  ${RED}Directory does not exist: $input_path${RESET}"
      continue
    fi
    local resolved
    resolved="$(cd "$input_path" && pwd)"
    if [[ "$resolved" == "$LIBRARY_DIR" ]]; then
      echo -e "  ${RED}Cannot deploy to the library's own directory. Choose a different path.${RESET}"
      continue
    fi
    TARGET_REPO="$resolved"
    echo -e "  ${GREEN}✔${RESET} Target: ${CYAN}$TARGET_REPO${RESET}"
    break
  done
  echo ""
}

# Confirm preselected target from CLI, optionally allow changing it
confirm_or_change_target_repo() {
  echo -e "${BOLD}Step 1 → Target repository${RESET}"
  echo -e "${DIM}Path to the project you want to deploy the library into.${RESET}"
  echo ""
  echo -e "  Pre-selected target: ${CYAN}$TARGET_REPO${RESET}"

  if ! menu_confirm "Use this target?" true; then
    echo ""
    ask_target_repo
    return
  fi

  echo -e "  ${GREEN}✔${RESET} Target: ${CYAN}$TARGET_REPO${RESET}"
  echo ""
}

# Ask for deployment mode
ask_mode() {
  echo -e "${BOLD}Step 2 → Deployment mode${RESET}"
  echo -e "${DIM}Where should the files be placed in the target repo?${RESET}"
  echo ""

  local detected
  detected="$(detect_mode "$TARGET_REPO")"

  local options=(
    "auto     → auto-detect (currently: $detected)"
    "root     → deploy to repo root (AGENTS.md, skills/, etc.)"
    "opencode → deploy to .opencode/ directory only"
    "both     → deploy to root AND .opencode/"
  )

  menu_select "Select deployment mode" 1 "${options[@]}"
  case "$MENU_SELECTED" in
    1) MODE="auto" ;;
    2) MODE="root" ;;
    3) MODE="opencode" ;;
    4) MODE="both" ;;
  esac

  echo -e "  ${GREEN}✔${RESET} Mode: ${CYAN}$MODE${RESET}"
  echo ""
}

# Ask for profile / skills
ask_profile() {
  echo -e "${BOLD}Step 3 → Skills profile${RESET}"
  echo -e "${DIM}Which skills do you want to include?${RESET}"
  echo ""

  local options=(
    "full     → all skills"
    "web-app  → nextjs, db, auth, ui, testing, api, email, typescript, error-handling"
    "mobile   → react-native, typescript, state-management, performance, testing"
    "static   → nextjs, ui, seo, performance, typescript, accessibility"
    "api      → api-design, db, security, error-handling, email, typescript"
    "custom   → pick individual skills from the list"
  )

  menu_select "Select skills profile" 1 "${options[@]}"
  case "$MENU_SELECTED" in
    1) PROFILE="full" ;;
    2) PROFILE="web-app" ;;
    3) PROFILE="mobile" ;;
    4) PROFILE="static" ;;
    5) PROFILE="api" ;;
    6)
      PROFILE="custom"
      ask_custom_skills
      ;;
  esac

  if [[ "$PROFILE" != "custom" ]]; then
    echo -e "  ${GREEN}✔${RESET} Profile: ${CYAN}$PROFILE${RESET}"
  fi
  echo ""
}

# Interactive multi-select for custom skills
ask_custom_skills() {
  echo ""
  echo -e "  ${BOLD}Custom skill selection${RESET}"
  echo -e "  ${DIM}Type skill numbers separated by spaces, then press Enter.${RESET}"
  echo -e "  ${DIM}Example: 1 3 5${RESET}"
  echo ""

  local all_skills
  mapfile -t all_skills < <(get_all_skills)

  if [[ ${#all_skills[@]} -eq 0 ]]; then
    warn "No skills found in skills/generic/. Using full profile."
    PROFILE="full"
    return
  fi

  local i=1
  for skill in "${all_skills[@]}"; do
    printf "    ${CYAN}%2d${RESET}. %s\n" "$i" "$skill"
    ((i++))
  done

  echo ""
  while true; do
    printf "  Your selection (numbers): "
    read -r selection
    if [[ -z "$selection" ]]; then
      echo -e "  ${RED}Please select at least one skill.${RESET}"
      continue
    fi

    CUSTOM_SKILLS=()
    local valid=true
    for num in $selection; do
      if ! [[ "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > ${#all_skills[@]} )); then
        echo -e "  ${RED}Invalid number: $num. Enter numbers between 1 and ${#all_skills[@]}.${RESET}"
        valid=false
        break
      fi
      CUSTOM_SKILLS+=("${all_skills[$((num - 1))]}")
    done

    if $valid && [[ ${#CUSTOM_SKILLS[@]} -gt 0 ]]; then
      echo ""
      echo -e "  ${GREEN}✔${RESET} Selected skills: ${CYAN}${CUSTOM_SKILLS[*]}${RESET}"
      break
    fi
  done
}

# Ask for extra options (dry-run, force)
ask_options() {
  echo -e "${BOLD}Step 4 → Options${RESET}"
  echo -e "${DIM}Choose how the deployment should run.${RESET}"
  echo ""

  local options=(
    "Apply changes now (recommended)"
    "Preview only (--dry-run)"
    "Apply and overwrite newer files (--force)"
    "Preview and overwrite (--dry-run + --force)"
  )

  menu_select "Select execution option" 1 "${options[@]}"

  DRY_RUN=false
  FORCE=false
  case "$MENU_SELECTED" in
    1)
      ;;
    2)
      DRY_RUN=true
      ;;
    3)
      FORCE=true
      ;;
    4)
      DRY_RUN=true
      FORCE=true
      ;;
  esac

  if $DRY_RUN; then
    echo -e "  ${YELLOW}✔${RESET} Dry run enabled (no files will be copied)."
  else
    echo -e "  ${GREEN}✔${RESET} Real deployment enabled (files will be copied now)."
  fi

  if $FORCE; then
    echo -e "  ${YELLOW}✔${RESET} Force enabled (newer files may be overwritten)."
  else
    echo -e "  ${GREEN}✔${RESET} Force disabled (newer destination files are preserved)."
  fi

  echo ""
}

# Confirmation summary before deploy
confirm_deploy() {
  divider
  echo ""
  echo -e "  ${BOLD}Summary${RESET}"
  echo -e "  Library  : ${CYAN}$LIBRARY_DIR${RESET}"
  echo -e "  Target   : ${CYAN}$TARGET_REPO${RESET}"
  echo -e "  Mode     : ${CYAN}$MODE${RESET}"
  echo -e "  Profile  : ${CYAN}$PROFILE${RESET}"
  if [[ "$PROFILE" == "custom" ]]; then
    echo -e "  Skills   : ${CYAN}${CUSTOM_SKILLS[*]}${RESET}"
  fi
  $DRY_RUN && echo -e "  ${YELLOW}Dry run — no files will be written${RESET}"
  $FORCE   && echo -e "  ${YELLOW}Force   — newer destination files overwritten${RESET}"
  echo ""
  divider
  echo ""

  if ! menu_confirm "Proceed with deployment?" true; then
    echo -e "\n  ${YELLOW}Aborted.${RESET}\n"
    exit 0
  fi
  echo ""
}

# ── Run interactive flow if no arguments given ─────────────────────────────────
run_interactive() {
  INTERACTIVE=true
  print_banner
  if [[ -n "$TARGET_REPO" ]]; then
    confirm_or_change_target_repo
  else
    ask_target_repo
  fi
  ask_mode
  ask_profile
  ask_options
  confirm_deploy
}

# ══════════════════════════════════════════════════════════════════════════════
# ── ARGUMENT PARSING ─────────────────────────────────────────────────────────
# ══════════════════════════════════════════════════════════════════════════════

CLI_OPTIONS_PROVIDED=false
POSITIONAL_COUNT=0

if [[ $# -eq 0 ]]; then
  run_interactive
else
  # Parse CLI input. If only target is provided (no options), run interactive wizard.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h) usage ;;
      --dry-run)
        DRY_RUN=true
        CLI_OPTIONS_PROVIDED=true
        shift
        ;;
      --force)
        FORCE=true
        CLI_OPTIONS_PROVIDED=true
        shift
        ;;
      --mode)
        MODE="$2"
        CLI_OPTIONS_PROVIDED=true
        shift 2
        ;;
      --profile)
        PROFILE="$2"
        CLI_OPTIONS_PROVIDED=true
        shift 2
        ;;
      -*)
        error "Unknown option: $1"
        exit 1
        ;;
      *)
        if [[ -n "$TARGET_REPO" ]]; then
          error "Multiple target paths provided. Use a single target directory."
          exit 1
        fi
        TARGET_REPO="$1"
        ((POSITIONAL_COUNT++)) || true
        shift
        ;;
    esac
  done

  resolve_and_validate_target_repo

  if [[ "$POSITIONAL_COUNT" -eq 1 ]] && ! $CLI_OPTIONS_PROVIDED; then
    run_interactive
  fi
fi

# ── Validate target (non-interactive path only needs this) ────────────────────
if [[ -z "$TARGET_REPO" ]]; then
  error "No target repo specified."
  exit 1
fi

# ── Auto-detect mode ──────────────────────────────────────────────────────────
if [[ "$MODE" == "auto" ]]; then
  MODE="$(detect_mode "$TARGET_REPO")"
  if ! $INTERACTIVE; then
    log "Auto-detected mode: ${BOLD}$MODE${RESET}"
  fi
fi

# ── Validate profile ──────────────────────────────────────────────────────────
get_profile_skills > /dev/null

# ── Summary header (non-interactive) ─────────────────────────────────────────
if ! $INTERACTIVE; then
  echo ""
  echo -e "${BOLD}AI Library Deploy${RESET}"
  echo -e "  Library : ${CYAN}$LIBRARY_DIR${RESET}"
  echo -e "  Target  : ${CYAN}$TARGET_REPO${RESET}"
  echo -e "  Mode    : ${CYAN}$MODE${RESET}"
  echo -e "  Profile : ${CYAN}$PROFILE${RESET}"
  $DRY_RUN && echo -e "  ${YELLOW}DRY RUN — no files will be written${RESET}"
  $FORCE   && echo -e "  ${YELLOW}FORCE — newer destination files will be overwritten${RESET}"
  echo ""
fi

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

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
  echo -e "${YELLOW}Dry run complete.${RESET} Would have copied ${BOLD}$COPIED${RESET} items."
else
  echo -e "${GREEN}✔ Done.${RESET} Copied ${BOLD}$COPIED${RESET} items, skipped ${BOLD}$SKIPPED${RESET} (destination was newer — use --force to overwrite)."
fi
echo ""
