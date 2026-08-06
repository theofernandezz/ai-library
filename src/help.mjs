export function printHelp() {
  console.log(`
🚀 AI Library — deploy skills & agents into a project

Usage:
  npx github:theofernandezz/ai-library                      → interactive wizard
  npx github:theofernandezz/ai-library <TARGET_REPO_PATH>   → interactive wizard, target pre-filled
  npx github:theofernandezz/ai-library <TARGET_REPO_PATH> [OPTIONS]

Options:
  --mode <mode>      auto | root | opencode | both       (default: auto)
  --profile <name>   web-app | mobile | static | api | full   (default: full)
                      (use the interactive wizard for "custom" — picking individual skills)
  --dry-run          Preview what would be copied without writing anything
  --force            Overwrite even if the target has newer files
  --verbose          Print every file copied, not just the summary
  --help, -h         Show this help message

Examples:
  npx github:theofernandezz/ai-library ../my-project
  npx github:theofernandezz/ai-library ../my-project --profile web-app
  npx github:theofernandezz/ai-library ../my-project --dry-run
  npx github:theofernandezz/ai-library ../my-project --force

Already have the repo cloned locally? ./deploy.sh works the same way and has
a few more power-user flags (see ./deploy.sh --help).
`)
}
