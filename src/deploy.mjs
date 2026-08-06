import { existsSync, mkdirSync, copyFileSync, statSync, readdirSync, writeFileSync, readFileSync, cpSync } from 'node:fs'
import { join, dirname, basename } from 'node:path'
import { execSync } from 'node:child_process'
import { spinner, log } from '@clack/prompts'
import { resolveProfileSkills } from './profiles.mjs'
import { printNextSteps } from './next-steps.mjs'

// ── Mode auto-detection (mirrors detect_mode() in deploy.sh) ─────────────────
export function detectMode(target) {
  const hasRoot = existsSync(join(target, 'AGENTS.md')) || existsSync(join(target, 'CLAUDE.md'))
  const hasOpencode = existsSync(join(target, '.opencode')) && statSync(join(target, '.opencode')).isDirectory()
  if (hasRoot && hasOpencode) return 'both'
  if (hasOpencode) return 'opencode'
  return 'root'
}

function makeCtx({ dryRun, force, verbose }) {
  return { dryRun, force, verbose, copied: 0, skipped: 0 }
}

function copyFile(ctx, src, dst) {
  if (!existsSync(src) || !statSync(src).isFile()) return
  if (ctx.dryRun) {
    ctx.copied++
    if (ctx.verbose) log.message(`[dry-run] ${src} → ${dst}`)
    return
  }
  mkdirSync(dirname(dst), { recursive: true })
  if (existsSync(dst) && !ctx.force) {
    const srcTime = statSync(src).mtimeMs
    const dstTime = statSync(dst).mtimeMs
    if (dstTime > srcTime) {
      ctx.skipped++
      return
    }
  }
  copyFileSync(src, dst)
  ctx.copied++
}

function copyDir(ctx, src, dst) {
  if (!existsSync(src) || !statSync(src).isDirectory()) return
  if (ctx.dryRun) {
    ctx.copied++
    if (ctx.verbose) log.message(`[dry-run] ${src}/ → ${dst}/`)
    return
  }
  cpSync(src, dst, { recursive: true, force: true })
  ctx.copied++
}

function copyTopLevelSkillFiles(ctx, libraryDir, target) {
  const skillsDir = join(libraryDir, 'skills')
  for (const name of readdirSync(skillsDir)) {
    if (!(name.endsWith('.md') || name.endsWith('.sh'))) continue
    copyFile(ctx, join(skillsDir, name), join(target, 'skills', name))
  }
  for (const name of readdirSync(skillsDir)) {
    const p = join(skillsDir, name)
    if (!statSync(p).isDirectory() || name === 'generic') continue
    copyDir(ctx, p, join(target, 'skills', name))
  }
}

function copySkillsFiltered(ctx, src, dst, profile, customSkills) {
  if (!existsSync(src)) return
  const allowed = resolveProfileSkills(profile, customSkills) // null = no filtering
  for (const name of readdirSync(src)) {
    const skillDir = join(src, name)
    if (!statSync(skillDir).isDirectory()) continue
    if (allowed === null || allowed.includes(name)) {
      copyDir(ctx, skillDir, join(dst, name))
    } else {
      ctx.skipped++
    }
  }
}

// ── Project CLAUDE.md (mirrors generate_project_claude_md() in deploy.sh) ────
function generateProjectClaudeMd(ctx, libraryDir, target) {
  const dst = join(target, 'CLAUDE.md')
  if (existsSync(dst) && !ctx.force) {
    ctx.skipped++
    return false
  }
  if (ctx.dryRun) {
    ctx.copied++
    return true
  }

  const projectName = basename(target)
  const libraryClaudeMd = readFileSync(join(libraryDir, 'CLAUDE.md'), 'utf8')
  const content = `# ${projectName}

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
<!-- Update by re-running: npx github:theofernandezz/ai-library ${target} --force -->

${libraryClaudeMd}`

  mkdirSync(dirname(dst), { recursive: true })
  writeFileSync(dst, content)
  ctx.copied++
  return true
}

function writeVersionFile(ctx, libraryDir, target) {
  if (ctx.dryRun) return
  let commit = 'unknown'
  try {
    commit = execSync('git rev-parse --short HEAD', { cwd: libraryDir }).toString().trim()
  } catch {
    // not a git checkout (e.g. npx-extracted tarball) — leave as "unknown"
  }
  const date = new Date().toISOString().slice(0, 10)
  writeFileSync(
    join(target, '.ai-library-version'),
    `deployed: ${date}\ncommit:   ${commit}\nsource:   ${libraryDir}\n`,
  )
}

// ── Deploy to repo root (mirrors deploy_root() in deploy.sh) ─────────────────
function deployRoot(ctx, libraryDir, target, profile, customSkills) {
  copyFile(ctx, join(libraryDir, 'AGENTS.md'), join(target, 'AGENTS.md'))
  copyFile(ctx, join(libraryDir, 'GEMINI.md'), join(target, 'GEMINI.md'))
  const claudeMdGenerated = generateProjectClaudeMd(ctx, libraryDir, target)

  copyDir(ctx, join(libraryDir, 'agents'), join(target, 'agents'))
  copyTopLevelSkillFiles(ctx, libraryDir, target)

  for (const scope of ['ui', 'auth', 'backend', 'testing']) {
    copyFile(ctx, join(libraryDir, scope, 'AGENTS.md'), join(target, scope, 'AGENTS.md'))
  }

  copyDir(ctx, join(libraryDir, '.claude', 'agents'), join(target, '.claude', 'agents'))
  copySkillsFiltered(ctx, join(libraryDir, 'skills', 'generic'), join(target, '.claude', 'skills'), profile, customSkills)

  return claudeMdGenerated
}

// ── Deploy to .opencode/ (mirrors deploy_opencode() in deploy.sh) ────────────
function deployOpencode(ctx, libraryDir, targetRoot, profile, customSkills) {
  const target = join(targetRoot, '.opencode')
  copyDir(ctx, join(libraryDir, '.opencode', 'agents'), join(target, 'agents'))
  copySkillsFiltered(ctx, join(libraryDir, 'skills', 'generic'), join(target, 'skills', 'generic'), profile, customSkills)
  copyTopLevelSkillFiles(ctx, libraryDir, target)
  copyFile(ctx, join(libraryDir, 'AGENTS.md'), join(target, 'AGENTS.md'))
}

export async function deploy(opts) {
  const { libraryDir, targetRepo, dryRun, force, verbose } = opts
  let { mode, profile, customSkills } = opts

  if (!existsSync(targetRepo) || !statSync(targetRepo).isDirectory()) {
    log.error(`Target directory does not exist: ${targetRepo}`)
    process.exit(1)
  }
  if (targetRepo === libraryDir) {
    log.error('Target is the same as the library directory. Aborting.')
    process.exit(1)
  }
  if (mode === 'auto') mode = detectMode(targetRepo)
  resolveProfileSkills(profile, customSkills) // throws on unknown profile before we touch anything

  const ctx = makeCtx({ dryRun, force, verbose })
  const s = spinner()
  s.start(`Deploying (mode: ${mode}, profile: ${profile})…`)

  let claudeMdGenerated = false
  if (mode === 'root' || mode === 'both') {
    claudeMdGenerated = deployRoot(ctx, libraryDir, targetRepo, profile, customSkills)
  }
  if (mode === 'opencode' || mode === 'both') {
    deployOpencode(ctx, libraryDir, targetRepo, profile, customSkills)
  }
  writeVersionFile(ctx, libraryDir, targetRepo)

  s.stop(
    dryRun
      ? `Dry run complete — would copy ${ctx.copied} items.`
      : `Copied ${ctx.copied} items, skipped ${ctx.skipped} (destination was newer — use --force to overwrite).`,
  )

  printNextSteps({ targetRepo, mode, dryRun, claudeMdGenerated })
}
