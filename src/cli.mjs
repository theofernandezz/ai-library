import { parseArgs } from 'node:util'
import { resolve, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { log } from '@clack/prompts'
import { runWizard } from './wizard.mjs'
import { deploy } from './deploy.mjs'
import { printHelp } from './help.mjs'

// src/cli.mjs → one level up is the repo root.
const LIBRARY_DIR = join(dirname(fileURLToPath(import.meta.url)), '..')

export async function run(argv) {
  if (argv.includes('--help') || argv.includes('-h')) {
    printHelp()
    return
  }

  const { values, positionals } = parseArgs({
    args: argv,
    options: {
      mode: { type: 'string', default: 'auto' },
      profile: { type: 'string', default: 'full' },
      'dry-run': { type: 'boolean', default: false },
      force: { type: 'boolean', default: false },
      verbose: { type: 'boolean', default: false },
    },
    allowPositionals: true,
  })

  // Matches deploy.sh: a bare target path (no flags) launches the interactive wizard.
  const hasExplicitFlags = argv.some((a) => a.startsWith('-'))

  let opts
  if (!hasExplicitFlags) {
    opts = await runWizard({ libraryDir: LIBRARY_DIR, presetTarget: positionals[0] })
  } else {
    if (positionals.length > 1) {
      log.error('Multiple target paths provided. Use a single target directory.')
      process.exit(1)
    }
    // No positional target with explicit flags → deploy into the current directory.
    opts = {
      targetRepo: positionals.length === 1 ? resolve(positionals[0]) : process.cwd(),
      mode: values.mode,
      profile: values.profile,
      customSkills: [],
      dryRun: values['dry-run'],
      force: values.force,
      verbose: values.verbose,
    }
  }

  await deploy({ ...opts, libraryDir: LIBRARY_DIR })
}
