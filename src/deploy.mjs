import { existsSync, mkdirSync, copyFileSync, statSync, readdirSync, writeFileSync, readFileSync, renameSync } from 'node:fs'
import { join, dirname, basename, relative, sep } from 'node:path'
import { createHash } from 'node:crypto'
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

// ── Manifest: tells library-deployed content apart from local edits ─────────
// .ai-library-manifest in the target holds "<sha256>  <path>" for every file the last
// deploy wrote. A file whose hash still matches is untouched and safe to overwrite;
// one that doesn't was edited locally. (mirrors the manifest section in deploy.sh)
const MANIFEST_NAME = '.ai-library-manifest'
const BACKUP_ROOT_NAME = '.ai-library-backup'

function readManifest(file) {
  const entries = new Map()
  if (!existsSync(file)) return entries
  for (const line of readFileSync(file, 'utf8').split('\n')) {
    const i = line.indexOf('  ')
    if (i > 0) entries.set(line.slice(i + 2), line.slice(0, i))
  }
  return entries
}

const pad = (n) => String(n).padStart(2, '0')
function timestamp() {
  const d = new Date()
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}-${pad(d.getHours())}${pad(d.getMinutes())}${pad(d.getSeconds())}`
}

function makeCtx({ dryRun, force, verbose, targetRepo }) {
  const manifestPath = join(targetRepo, MANIFEST_NAME)
  return {
    dryRun,
    force,
    verbose,
    targetRepo,
    hadManifest: existsSync(manifestPath),
    oldManifest: readManifest(manifestPath),
    newManifest: new Map(),
    backupDir: join(targetRepo, BACKUP_ROOT_NAME, timestamp()),
    copied: 0,
    unchanged: 0,
    skipped: 0, // not in profile / CLAUDE.md without marker
    kept: [], // edited locally, library version not applied
    backedUp: [],
    removed: [],
  }
}

const hashFile = (p) => createHash('sha256').update(readFileSync(p)).digest('hex')

// Decide and apply for one file. Honors --dry-run and --force.
//   target missing                 → write
//   identical to library           → unchanged
//   matches last deployed hash     → untouched since last deploy → overwrite
//   no record of a last deploy     → can't tell a local edit from an older library version → back up, overwrite
//   differs from last deployed     → edited locally → keep as-is (--force: back up, overwrite)
function deployFile(ctx, src, dst) {
  const rel = relative(ctx.targetRepo, dst).split(sep).join('/')
  const srcHash = hashFile(src)
  let action = 'write'
  let oldHash

  if (existsSync(dst)) {
    const dstHash = hashFile(dst)
    if (dstHash === srcHash) {
      action = 'unchanged'
    } else {
      oldHash = ctx.oldManifest.get(rel)
      if (oldHash === undefined) action = 'backup'
      else if (dstHash === oldHash) action = 'write'
      else action = ctx.force ? 'backup' : 'keep'
    }
  }

  if (action === 'unchanged') {
    ctx.unchanged++
    ctx.newManifest.set(rel, srcHash)
    return action
  }
  if (action === 'keep') {
    ctx.kept.push(rel)
    ctx.newManifest.set(rel, oldHash)
    if (ctx.verbose) log.message(`keep ${rel}`)
    return action
  }
  if (action === 'backup') ctx.backedUp.push(rel)
  if (!ctx.dryRun) {
    if (action === 'backup') {
      const b = join(ctx.backupDir, rel)
      mkdirSync(dirname(b), { recursive: true })
      copyFileSync(dst, b)
    }
    mkdirSync(dirname(dst), { recursive: true })
    copyFileSync(src, dst)
  }
  ctx.copied++
  ctx.newManifest.set(rel, srcHash)
  if (ctx.verbose) log.message(`${ctx.dryRun ? '[dry-run] ' : ''}${action} ${rel}`)
  return action
}

function copyFile(ctx, src, dst) {
  if (!existsSync(src) || !statSync(src).isFile()) return
  deployFile(ctx, src, dst)
}

function listFiles(dir, base = '') {
  const out = []
  for (const e of readdirSync(join(dir, base), { withFileTypes: true })) {
    const rel = base ? `${base}/${e.name}` : e.name
    if (e.isDirectory()) out.push(...listFiles(dir, rel))
    else if (e.isFile()) out.push(rel)
  }
  return out.sort()
}

function copyDir(ctx, src, dst) {
  if (!existsSync(src) || !statSync(src).isDirectory()) return
  for (const f of listFiles(src)) deployFile(ctx, join(src, f), join(dst, f))
}

// ── Drop paths the library no longer ships (deprecated-paths.txt) ────────────
// Only listed paths are touched — never "whatever isn't in the library", which
// would delete a project's own agents/skills. They are moved to the backup dir.
function removeDeprecated(ctx, libraryDir) {
  const list = join(libraryDir, 'deprecated-paths.txt')
  if (!existsSync(list)) return
  for (const line of readFileSync(list, 'utf8').split('\n')) {
    const p = line.replace(/\s/g, '')
    if (!p || p.startsWith('#') || p.startsWith('/') || p.includes('..')) continue
    const abs = join(ctx.targetRepo, p)
    if (!existsSync(abs)) continue
    ctx.removed.push(p)
    if (ctx.dryRun) continue
    const b = join(ctx.backupDir, p)
    mkdirSync(dirname(b), { recursive: true })
    renameSync(abs, b)
  }
}

// Entries from this run + entries from the old manifest for files not handled this run
// (e.g. a different --mode or --profile) that still exist. Sorted by path.
function writeManifest(ctx) {
  if (ctx.dryRun) return
  const merged = new Map(ctx.newManifest)
  for (const [p, h] of ctx.oldManifest) {
    if (!merged.has(p) && existsSync(join(ctx.targetRepo, p))) merged.set(p, h)
  }
  const lines = [...merged]
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([p, h]) => `${h}  ${p}`)
  writeFileSync(join(ctx.targetRepo, MANIFEST_NAME), lines.length ? `${lines.join('\n')}\n` : '')
}

function printReport(ctx) {
  const would = ctx.dryRun ? 'would be ' : ''
  const list = (items) => items.map((p) => `      ${p}`).join('\n')

  if (ctx.removed.length) {
    log.warn(`${ctx.removed.length} path(s) the library no longer ships ${would}moved to ${BACKUP_ROOT_NAME}/:\n${list(ctx.removed)}`)
  }
  if (ctx.kept.length) {
    log.warn(
      `${ctx.kept.length} file(s) edited locally ${would}kept as-is — library version NOT applied. ` +
        `Re-run with --force to overwrite them (a backup is saved first):\n${list(ctx.kept)}`,
    )
  }
  if (ctx.backedUp.length) {
    const dir = relative(ctx.targetRepo, ctx.backupDir).split(sep).join('/')
    let msg = `${ctx.backedUp.length} file(s) ${would}backed up to ${dir}/ before being overwritten.`
    if (!ctx.hadManifest) {
      msg +=
        `\n      No previous ${MANIFEST_NAME}, so local edits can't be told apart from older library versions:` +
        '\n      every differing file was backed up. From now on only real local edits are flagged.'
    }
    log.warn(msg)
  }
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
// Marker line splitting the project-owned section (above) from the library block (below).
const CLAUDE_MD_MARKER = 'ai-library configuration'
const CLAUDE_MD_UPDATE_NOTE =
  '<!-- Update: re-run the ai-library deploy (no --force needed). Only this block is refreshed; the project context above is never touched. -->'

// Existing CLAUDE.md: keep everything up to and including the marker line
// (project context is never touched, not even with --force), replace only the block below.
function refreshLibraryBlock(ctx, libraryDir, dst) {
  const lines = readFileSync(dst, 'utf8').split('\n')
  const markerIdx = lines.findIndex((l) => l.includes(CLAUDE_MD_MARKER))
  if (markerIdx === -1) {
    log.warn(`CLAUDE.md has no ai-library marker — left untouched. Paste the rules from ${join(libraryDir, 'CLAUDE.md')} by hand if you want them.`)
    ctx.skipped++
    return
  }

  const libraryClaudeMd = readFileSync(join(libraryDir, 'CLAUDE.md'), 'utf8')
  const head = lines.slice(0, markerIdx + 1).join('\n')
  const next = `${head}\n${CLAUDE_MD_UPDATE_NOTE}\n\n${libraryClaudeMd}`
  if (next === readFileSync(dst, 'utf8')) {
    ctx.unchanged++
    return
  }
  ctx.copied++
  if (!ctx.dryRun) writeFileSync(dst, next)
}

// Returns true only when a fresh CLAUDE.md template was generated (drives the "fill in Project Context" next step).
function generateProjectClaudeMd(ctx, libraryDir, target) {
  const dst = join(target, 'CLAUDE.md')
  if (existsSync(dst)) {
    refreshLibraryBlock(ctx, libraryDir, dst)
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
${CLAUDE_MD_UPDATE_NOTE}

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
  // Also at skills/generic — the path CLAUDE.md/AGENTS.md/GEMINI.md document and non-Claude tools read.
  copySkillsFiltered(ctx, join(libraryDir, 'skills', 'generic'), join(target, 'skills', 'generic'), profile, customSkills)

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

  const generateAgentsScript = join(libraryDir, 'generate-agents.sh')
  if (existsSync(generateAgentsScript)) {
    try {
      execSync(`"${generateAgentsScript}" --check`, { stdio: 'ignore' })
    } catch {
      log.warn(
        'agents/ and .opencode/agents/ are stale relative to .claude/agents/. ' +
          `Run ./generate-agents.sh in ${libraryDir} before deploying, or this deploy will ship outdated agents.`,
      )
    }
  }

  const ctx = makeCtx({ dryRun, force, verbose, targetRepo })
  const s = spinner()
  s.start(`Deploying (mode: ${mode}, profile: ${profile})…`)

  removeDeprecated(ctx, libraryDir)

  let claudeMdGenerated = false
  if (mode === 'root' || mode === 'both') {
    claudeMdGenerated = deployRoot(ctx, libraryDir, targetRepo, profile, customSkills)
  }
  if (mode === 'opencode' || mode === 'both') {
    deployOpencode(ctx, libraryDir, targetRepo, profile, customSkills)
  }
  writeVersionFile(ctx, libraryDir, targetRepo)
  writeManifest(ctx)

  s.stop(
    dryRun
      ? `Dry run complete — would write ${ctx.copied} file(s) (${ctx.unchanged} already up to date, ${ctx.kept.length} edited locally would be kept).`
      : `Wrote ${ctx.copied} file(s), ${ctx.unchanged} already up to date, kept ${ctx.kept.length} edited locally (--force to overwrite).`,
  )
  printReport(ctx)

  printNextSteps({ targetRepo, mode, dryRun, claudeMdGenerated })
}
