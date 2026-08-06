import { note, outro } from '@clack/prompts'

export function printNextSteps({ targetRepo, mode, dryRun, claudeMdGenerated }) {
  if (dryRun) {
    note(
      'Run the same command again and answer "No" to dry run (or drop --dry-run)\nto actually write the files.',
      'Next step',
    )
    outro('Dry run finished — nothing was written.')
    return
  }

  const lines = []
  lines.push(`1. Open ${targetRepo} in Claude Code (or Cursor / Copilot / OpenCode).`)

  if (claudeMdGenerated) {
    lines.push('')
    lines.push('2. Fill in the "Project Context" section at the top of CLAUDE.md — Stack,')
    lines.push('   Key decisions, Domain conventions, Constraints. That\'s what the AI')
    lines.push('   can\'t infer on its own; everything below it is the library, don\'t edit it.')
  } else {
    lines.push('')
    lines.push('2. CLAUDE.md already existed, so it was left untouched — re-run with --force')
    lines.push('   if you want it regenerated with the project-context template.')
  }

  lines.push('')
  lines.push('3. Try a first prompt, e.g. "create a Server Action to update a user\'s name" —')
  lines.push('   the AI should load the matching skill on its own before writing code.')
  lines.push('')
  lines.push(`4. Full skill list: ${mode === 'opencode' ? '.opencode/skills/_index.md' : 'skills/_index.md'}`)
  lines.push('')
  lines.push('5. To update later: re-run this same command with --force.')

  note(lines.join('\n'), 'Next steps')
  outro('✔ Done. Happy shipping.')
}
