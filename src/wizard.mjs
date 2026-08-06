import { existsSync, statSync } from 'node:fs'
import { resolve } from 'node:path'
import { intro, text, select, multiselect, confirm, note, isCancel, cancel } from '@clack/prompts'
import { PROFILES, getAllSkills } from './profiles.mjs'
import { detectMode } from './deploy.mjs'

function bail(value) {
  if (isCancel(value)) {
    cancel('Cancelled.')
    process.exit(0)
  }
  return value
}

function expandHome(p) {
  return p.startsWith('~') ? p.replace('~', process.env.HOME ?? '') : p
}

export async function runWizard({ libraryDir, presetTarget }) {
  intro('🚀 AI Library — deploy skills & agents into a project')

  let targetRepo
  if (presetTarget) {
    const resolved = resolve(expandHome(presetTarget))
    const useIt = bail(
      await confirm({ message: `Use "${resolved}" as the target?`, initialValue: true }),
    )
    if (useIt) targetRepo = resolved
  }

  if (!targetRepo) {
    const cwd = process.cwd()
    if (cwd !== libraryDir) {
      const useCwd = bail(
        await confirm({
          message: `Deploy into the current directory? (${cwd})`,
          initialValue: true,
        }),
      )
      if (useCwd) targetRepo = cwd
    }
  }

  if (!targetRepo) {
    const input = bail(
      await text({
        message: 'Path to the project you want to deploy into',
        placeholder: '../my-project',
        validate: (value) => {
          if (!value) return 'Path is required.'
          const resolved = resolve(expandHome(value))
          if (!existsSync(resolved) || !statSync(resolved).isDirectory()) {
            return `Directory does not exist: ${resolved}`
          }
          if (resolved === libraryDir) return 'Cannot deploy into the library itself.'
        },
      }),
    )
    targetRepo = resolve(expandHome(input))
  }

  const detected = detectMode(targetRepo)
  const mode = bail(
    await select({
      message: 'Where should the files go?',
      options: [
        { value: 'auto', label: 'Auto-detect', hint: `currently: ${detected}` },
        { value: 'root', label: 'Repo root', hint: 'AGENTS.md, skills/, agents/' },
        { value: 'opencode', label: '.opencode/ only' },
        { value: 'both', label: 'Root AND .opencode/' },
      ],
      initialValue: 'auto',
    }),
  )

  const allSkills = getAllSkills(libraryDir)
  const profile = bail(
    await select({
      message: 'Which skills do you want?',
      options: [
        { value: 'full', label: 'full', hint: `all ${allSkills.length} skills (default)` },
        { value: 'web-app', label: 'web-app', hint: PROFILES['web-app'].join(', ') },
        { value: 'mobile', label: 'mobile', hint: PROFILES.mobile.join(', ') },
        { value: 'static', label: 'static', hint: PROFILES.static.join(', ') },
        { value: 'api', label: 'api', hint: PROFILES.api.join(', ') },
        { value: 'custom', label: 'custom', hint: 'pick skills individually' },
      ],
      initialValue: 'full',
    }),
  )

  let customSkills = []
  if (profile === 'custom') {
    customSkills = bail(
      await multiselect({
        message: 'Select the skills to include',
        options: allSkills.map((s) => ({ value: s, label: s })),
        required: true,
      }),
    )
  }

  const dryRun = bail(
    await confirm({ message: 'Dry run first? (preview only, writes nothing)', initialValue: false }),
  )

  let force = false
  if (!dryRun) {
    force = bail(
      await confirm({ message: 'Overwrite files even if the target has newer versions?', initialValue: false }),
    )
  }

  const summaryLines = [
    `Target   ${targetRepo}`,
    `Mode     ${mode}`,
    `Profile  ${profile}${profile === 'custom' ? ` (${customSkills.join(', ')})` : ''}`,
  ]
  if (dryRun) summaryLines.push('Dry run — no files will be written')
  if (force) summaryLines.push('Force — newer destination files will be overwritten')
  note(summaryLines.join('\n'), 'Summary')

  const proceed = bail(await confirm({ message: 'Proceed with deployment?', initialValue: true }))
  if (!proceed) {
    cancel('Aborted.')
    process.exit(0)
  }

  return { targetRepo, mode, profile, customSkills, dryRun, force, verbose: false }
}
