# ai-library

AI development library -- skills and agents for Claude Code, Cursor, Copilot, and OpenCode.

---

## What is this

ai-library is a portable set of coding standards, patterns, and specialized agents that you deploy into any project. Instead of repeating the same instructions in every repository ("use Zod for validation", "no `any` types", "Server Components by default"), you deploy the library once and the AI already knows how to work.

The core idea: **code patterns should be version-controlled and shared, not typed into chat every session.** Each pattern is a "skill" -- a self-contained document that tells the AI exactly how to write code in a specific domain. Skills are loaded on demand, so the AI only reads what it needs for the current task.

This works with Claude Code (CLI, desktop, web), VS Code with Copilot, Cursor, and OpenCode. The library adapts to each tool's configuration format.

## How it works

The library has three layers:

### Skills

Skills are domain-specific coding standards. Each skill covers one area -- TypeScript, database queries, security, testing, etc. -- and contains the rules, required patterns, forbidden patterns, and examples for that domain.

Skills are loaded lazily: the AI consults a lightweight index to know what exists, then loads a specific skill only when it's about to write code in that domain.

### Agents

Agents are specialists that orchestrate multiple skills. Instead of loading 5 skills manually for a backend task, the `backend` agent knows which skills apply and loads them as needed. Agents are lean (~75 lines) -- they define the role, core rules, and a checklist. The detailed patterns live in the skills.

### Agent Teams

For larger tasks, agents work as a team. The developer acts as Team Lead, coordinating specialized agents (ui, backend, auth, testing, etc.) that work in parallel on different parts of the feature. Each agent follows the same skills and standards, ensuring consistency across the codebase.

## Skills included

| Skill | What it covers |
|-------|---------------|
| `typescript` | Strict types, no `any`, no `enum`, `as const` patterns |
| `react-patterns` | Component composition, custom hooks, compound components |
| `nextjs-core` | App Router, Server Components, Server Actions, streaming |
| `ui-engineering` | Tailwind v4, shadcn/ui, Aceternity, design tokens |
| `ux` | User flows, CRUD dashboards, validation UX, recovery states |
| `database` | Supabase queries, RLS policies, service layer |
| `prisma` | Prisma ORM, PostgreSQL, Neon serverless, migrations |
| `security` | Auth checks, input validation, XSS/CSRF prevention |
| `error-handling` | Custom error classes, Error Boundaries, structured logging |
| `testing` | Vitest, Testing Library, MSW, behavior-driven tests |
| `api-design` | Route Handlers, webhooks, external API integrations |
| `email` | Resend + React Email, typed templates, idempotent sends |
| `hexagonal-architecture` | Ports & adapters for external integrations, ESLint-enforced boundaries |
| `git-workflow` | Conventional Commits, branching strategy, PR standards |
| `i18n` | next-intl, locale routing, translation keys |
| `accessibility` | WCAG 2.1, ARIA, keyboard navigation, screen readers |
| `performance` | Core Web Vitals, lazy loading, bundle optimization |
| `seo` | Meta tags, Open Graph, structured data, sitemaps |
| `state-management` | Zustand, React Context, global/shared state |
| `react-native` | Expo, React Navigation, native APIs, mobile patterns |
| `env-config` | Zod env validation, server/public var separation |

## Agents included

| Agent | Specialization | When to use |
|-------|---------------|-------------|
| `ui` | React, Tailwind, animations, accessibility | Creating or modifying UI components |
| `backend` | Server Actions, APIs, database, business logic | Server-side code in `lib/` |
| `auth` | Supabase Auth, RLS, sessions, middleware | Login flows, route protection, permissions |
| `data` | Prisma schema, migrations, service layer | Database modeling and queries |
| `testing` | Vitest, Playwright, MSW | Writing or fixing tests |
| `mobile` | React Native, Expo, native APIs | Mobile app development |
| `git` | Conventional Commits, branching, PRs | Commits, branches, pull requests |
| `verifier` | Fresh-context diff review against the request/spec | After any agent finishes, before calling it done |

## Quick start

No clone needed — run it straight from any project directory:

```bash
# Interactive wizard (asks for target, mode, profile, dry-run/force)
npx github:theofernandezz/ai-library

# Or pass the target and flags directly
npx github:theofernandezz/ai-library ../my-project --profile web-app

# Preview what would be deployed
npx github:theofernandezz/ai-library ../my-project --profile mobile --dry-run
```

Requires Node.js ≥18.17. This runs `deploy.sh`'s logic through a small Node CLI (`@clack/prompts`) so it works with a single `npx` command from anywhere, without cloning the repo first.

### Alternative: clone + `deploy.sh`

If you already have the repo cloned locally, or want the extra power-user flags (`--mode`, interactive `custom` profile via arrow keys), the original bash script still works identically:

```bash
git clone https://github.com/theofernandezz/ai-library.git
cd ai-library

./deploy.sh ../my-project
./deploy.sh ../my-project --profile web-app
./deploy.sh ../my-project --profile mobile --dry-run
```

Both tools produce the exact same output — pick whichever fits your workflow. After deploying, open your project with Claude Code (or your preferred AI tool) and follow the "Next steps" printed at the end.

### Updating a project that already has the library

Re-run the same command (preview first with `--dry-run`).

- **`CLAUDE.md`**: everything above the `ai-library configuration` marker (your Project Context: stack, decisions, conventions, constraints) is never touched — not even with `--force`. Only the library block below the marker is refreshed. A `CLAUDE.md` with no marker is left as-is with a warning.
- **Local edits**: each deploy writes `.ai-library-manifest` (a hash of every file it deployed — commit it). A skill/agent you edited by hand no longer matches its hash, so the next deploy keeps your version and lists it. `--force` overwrites those files, saving your version to `.ai-library-backup/<timestamp>/` first.
- **First run on a project without a manifest** (deployed before this existed): local edits can't be told apart from older library versions, so every differing file is backed up to `.ai-library-backup/` before being overwritten. Review it, then delete it (or gitignore it).
- **Removed from the library**: paths listed in `deprecated-paths.txt` (e.g. the `feature` agent, the `remotion` skill) are moved to `.ai-library-backup/`. Only listed paths are touched — your own agents and skills are never removed.

## Deploy profiles

Not every project needs all 21 skills. Profiles deploy only the skills relevant to your project type:

| Profile | Skills | Best for |
|---------|--------|----------|
| `web-app` | nextjs-core, database, security, typescript, react-patterns, ui-engineering, error-handling, testing, api-design, email, env-config | Full-stack Next.js applications |
| `mobile` | react-native, typescript, state-management, performance, testing | React Native / Expo apps |
| `static` | nextjs-core, ui-engineering, seo, performance, typescript, accessibility | Marketing sites, blogs, landing pages |
| `api` | api-design, database, security, error-handling, typescript, email, env-config | API-only backends |
| `full` | All 21 skills | When you need everything (default) |

## Agent Teams

For complex features, you can use Agent Teams -- a persistent team where the developer is the Team Lead and agents are specialized developers.

```
Team Lead (you)
  |-- ui agent        -> components, styles, animations
  |-- backend agent   -> server actions, business logic
  |-- auth agent      -> authentication, RLS policies
  |-- testing agent   -> tests for all layers
  |-- verifier agent  -> reviews the diff against the spec
```

The Team Lead breaks down the task, assigns work to agents, and reviews their output. Agents work in parallel, each following the same skills and standards.

## Requirements

- **Claude Code** v2.1.32 or later
- For Agent Teams: set `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
- Works with any project that uses an AI coding assistant

## Contributing

To add a new skill:

1. Read `skills/skill-creator/SKILL.md` -- it has the template and guidelines
2. Create your skill in `skills/generic/<skill-name>/SKILL.md`
3. Add it to `skills/_index.md`
4. Add it to the relevant agent's `skills:` frontmatter in `.claude/agents/`
5. Run `./skills/skill-sync/assets/sync.sh` to update AGENTS.md

When removing a skill or agent from the library, add every path it was deployed to (root, `.claude/`, `.opencode/`) to `deprecated-paths.txt` — deploys only clean up what is listed there.

When updating an existing skill: **replace the old pattern, don't append.** The file should stay the same length or get shorter. Always update the What's New table in the skill.

## License

MIT
