# AI Development Library - Claude Code

> This file configures how Claude Code should use the skills library for development.

---

## Skills System

This library contains **skills** (code patterns) and **specialized agents** (domain-specific context) that guide how code should be written.

### Skill Loading (Lazy)

**Load skills on demand — not all upfront.**

1. Consult `skills/_index.md` to know what skills exist (lightweight)
2. Load a skill ONLY when you are about to write code in that domain
3. If the task touches multiple domains, load each skill at the moment you need to write in that domain — not all at the beginning

Code is reviewed against the skill patterns.

---

## Automatic Skill Detection

When about to write code in these areas, **load the corresponding skill at that moment**:

| If you're...                         | Skill                      | Path                                       |
| ------------------------------------ | -------------------------- | ------------------------------------------ |
| Creating/editing .ts or .tsx files   | `typescript`               | `skills/generic/typescript/SKILL.md`       |
| Working in the app/ directory        | `nextjs-core`              | `skills/generic/nextjs-core/SKILL.md`      |
| Creating React components            | `react-patterns`           | `skills/generic/react-patterns/SKILL.md`   |
| Using Tailwind/shadcn/Aceternity     | `ui-engineering`           | `skills/generic/ui-engineering/SKILL.md`   |
| Designing UX flows / CRUD dashboards | `ux`                       | `skills/generic/ux/SKILL.md`               |
| Working with Supabase/DB             | `database`                 | `skills/generic/database/SKILL.md`         |
| Working with Prisma/PostgreSQL       | `prisma`                   | `skills/generic/prisma/SKILL.md`           |
| Working with env vars / secrets      | `env-config`               | `skills/generic/env-config/SKILL.md`       |
| Creating Server Actions              | `nextjs-core` + `security` | Read both skills                           |
| Handling authentication              | `security`                 | `skills/generic/security/SKILL.md`         |
| Writing tests                        | `testing`                  | `skills/generic/testing/SKILL.md`          |
| Making commits/PRs                   | `git-workflow`             | `skills/generic/git-workflow/SKILL.md`     |
| Creating API routes/webhooks         | `api-design`               | `skills/generic/api-design/SKILL.md`       |
| Sending transactional emails         | `email`                    | `skills/generic/email/SKILL.md`            |
| Integrating external services (payments, etc.) | `hexagonal-architecture`   | `skills/generic/hexagonal-architecture/SKILL.md` |
| Writing Dockerfile/docker-compose    | `docker`                   | `skills/generic/docker/SKILL.md`           |
| Writing GitHub Actions workflows     | `ci-cd`                    | `skills/generic/ci-cd/SKILL.md`            |
| Handling errors                      | `error-handling`           | `skills/generic/error-handling/SKILL.md`   |
| Internationalizing content           | `i18n`                     | `skills/generic/i18n/SKILL.md`             |
| Working on accessibility             | `accessibility`            | `skills/generic/accessibility/SKILL.md`    |
| Optimizing performance               | `performance`              | `skills/generic/performance/SKILL.md`      |
| Configuring SEO                      | `seo`                      | `skills/generic/seo/SKILL.md`              |
| Managing global/shared state         | `state-management`         | `skills/generic/state-management/SKILL.md` |
| Building React Native apps/features  | `react-native`             | `skills/generic/react-native/SKILL.md`     |

---

## Domain Delegation

When a task belongs to a specific domain, **invoke the corresponding subagent** — do not read its file into your own context:

| Domain              | Subagent  | When to use                                                    |
| ------------------- | --------- | --------------------------------------------------------------- |
| **UI/Frontend**     | `ui`      | Components, styles, animations, accessibility                 |
| **Backend/Server**  | `backend` | Server Actions, APIs, database (Supabase), business logic     |
| **Auth**            | `auth`    | Authentication, authorization, RLS, sessions                   |
| **Testing**         | `testing` | Unit tests, integration, E2E                                    |
| **Data/Prisma**     | `data`    | Prisma schema, migrations, service layer, PostgreSQL/Neon      |
| **Git**             | `git`     | Commits, branching, pull requests                                |
| **Mobile**          | `mobile`  | React Native/Expo screens, navigation, native APIs               |

Each subagent is defined in `.claude/agents/<name>.md` — that's the source of truth. `agents/<name>.md` is a **generated** doc for humans and non-subagent tools (Gemini, Cursor); never edit it by hand, it gets overwritten.

### Before designing: smallest solution that holds

Read the code the change touches, then stop at the first rung that holds — before sizing a spec or counting files:

1. Does it need to exist at all?
2. Already in this codebase (a component, helper, service)?
3. Native platform or standard library (`<input type="date">`, `Intl`, `URL`)?
4. A dependency that's already installed?
5. Only then: the minimum that works — scoped to what was asked:
   - No props, options, config, messages, formatters, or "for later" code nobody requested. Name what you left out in one line of the reply, so the user can ask for it.
   - An open-ended request ("add an X") gets the smallest version that does the core job. If it has several plausible readings, ask instead.
   - Keep values in the form the platform already gives you — no wrapper, type layer, or abstraction around a single use.
   - Finish everything the change itself must reach: callers, tests, fixtures.

Never cut validation at trust boundaries, error handling, security, or accessibility to get there. A new dependency is the user's call: name it and why, then ask — don't install it.

### Size the spec to the risk

Pick the mode with skill `spec-driven` (`skills/spec-driven/SKILL.md`): **inline** (no spec) for clear, reversible, single-domain work; **incremental** (mini-spec: Outcome + 1–3 criteria) for reversible but uncertain work; **spec-first** (full `specs/<slug>.md`) for anything costly to revert — schema, auth, payments, public contracts — and for *any* task split across two or more subagents. Whatever you hand to a subagent or to `verifier` must be persisted at `specs/<slug>.md`: a spec that only lived inside a delegation prompt can't be checked against later or reused.

### How to delegate

1. **Delegate = invoke the `Agent` tool with `subagent_type: <domain>`.** Don't read the agent's file first — that defeats the isolation and reloads a full domain's worth of rules into your own context for no reason.
2. **What to pass:** the relevant slice of the spec (or the original request verbatim for something small enough to skip a spec) plus the specific paths involved. **Never** your own reasoning or conclusions about the code — the subagent starts with zero context, and handing it your analysis reintroduces the exact blind spots isolation is meant to avoid. The prompt has to be self-contained.
3. **Inline or delegate — count files, per action, for the solution the rungs above left** (starting thresholds, adjust with use): inline if understanding the change needs 1–3 files, or it's one mechanical, already-understood file. Delegate if understanding needs reading 4+ files, or if it writes 2+ non-trivial files. A fresh subagent re-derives all context from scratch — real cost in tokens and latency — so below those thresholds it isn't worth it.
4. **Parallel delegation only with disjoint file sets.** Two subagents editing the same files can silently overwrite each other's work. If domains overlap on the same files, delegate sequentially instead.
5. **Past the inline threshold (item 3), you route — you don't write domain code.** Pass context, and once a subagent reports back, review its diff against the spec (or the original request). If it drifted from what was asked, say so before accepting it. Inline work stays yours to write, following the loaded skills.

### Verification before "done"

`verifier` is not a domain — it doesn't write code (no `Edit`/`Write`). It's a fresh-context review pass: invoke it after a domain subagent (or you) finishes a fix, feature, or refactor, before calling the task done — especially when a previously-failing gate (tests, build, lint) now passes, since that's exactly the case where the implementer's own context can't be trusted to have caught scope drift or a test quietly weakened to pass.

**When to skip it:** changes that only touch documentation, comments, or formatting — there's no behavior to drift. **Always run it**, regardless of how small the diff looks, for anything touching auth, payments, data mutations, or migrations — and for auth, payments, and migrations invoke it with `model: opus`: its default Sonnet is enough for routine diffs, but a missed flaw there is costly to revert.

**Freeze the candidate before invoking.** Capture `git diff` yourself right after the subagent reports done, and paste that exact output into the prompt — don't tell `verifier` to go compute its own from the live repo. The window between "subagent finished" and "verifier ran" is exactly where something could shift; a diff you captured is reproducible, not something `verifier` might re-derive differently a moment later.

Pass it the spec (or the original request) + that captured diff. Never the implementer's reasoning — that's the whole point of fresh context. If it reports a failure, send the specific delta back to the subagent that owns the file — **one correction, exactly**. If `verifier` fails the same criterion again after that single correction, stop and report the diagnosis to the user instead of retrying a third time.

### Full-stack features (sequential delegation)

A feature spanning schema → backend → UI → tests has real dependencies between steps — delegate sequentially, never in parallel, passing each step's output (paths, exported names) to the next. Worked example in skill `spec-driven`.

---

## Local Delegation (Herdr + opencode)

Tasks too small to be worth Claude tokens (boilerplate, mechanical renames, test stubs) can go to a local model through Herdr — load skill `local-delegation` (`skills/local-delegation/SKILL.md`) before handing anything off.

---

## Pending Improvements

**Only when the session is working on the `ai-library` repo itself — not in projects it's deployed to — check:**
- **Open issues** — `gh issue list --repo theofernandezz/ai-library --state open` — signals filed from real usage, not yet merged into skills
- **`skills/improvements.md`** — fallback signals from sessions where `gh` wasn't available
- **`skills/changelog.md`** — recent breaking changes and new APIs across all skills

Apply pending improvements when relevant.

In every project: before writing code, mention any `skills/changelog.md` entry that applies to the current task.

---

## Self-Improvement Signals

When a loaded skill is missing a pattern, outdated, ambiguous, or contradicts another — or a needed skill doesn't exist — load skill `feedback-loop` (`skills/feedback-loop/SKILL.md`) and file the signal immediately, not at the end of the task.

---

## Meta-Skills

For special library tasks:

| Task                | Skill           | Instructions                                                 |
| ------------------- | --------------- | ------------------------------------------------------------ |
| Create new skill    | `skill-creator` | Read `skills/skill-creator/SKILL.md` and follow the template |
| Check skill registration | `skill-sync` | Run `./skills/skill-sync/assets/sync.sh` (fails if a skill isn't registered) |
| Record improvements | `feedback-loop` | Read `skills/feedback-loop/SKILL.md`                         |
| Fill in Project Context (interview) | `project-setup` | Read `skills/project-setup/SKILL.md` and run its Interview Protocol |
| Size a spec before delegating | `spec-driven` | Read `skills/spec-driven/SKILL.md`, pick the mode, write `specs/<slug>.md` if delegating |
| Hand a small task to a local model | `local-delegation` | Read `skills/local-delegation/SKILL.md`, confirm Herdr is up, `verifier` on every diff |

---

## Global Rules (Always Apply)

These rules are **NON-NEGOTIABLE** and apply to ALL code:

### Type Safety

```typescript
// FORBIDDEN
const data: any = await fetch(...)
function process(input: any): any

// REQUIRED - Always explicit types
const data: UserResponse = await fetchUser(id)
function process(input: ProcessInput): ProcessOutput
```

### No Enums

```typescript
// FORBIDDEN
enum UserRole {
  Admin = "ADMIN",
  User = "USER",
}

// REQUIRED - const assertion
const USER_ROLES = { Admin: "ADMIN", User: "USER" } as const;
type UserRole = (typeof USER_ROLES)[keyof typeof USER_ROLES];
```

### Server-First (Next.js)

- Server Components by default
- Client Components only for interactivity
- NEVER use useEffect for data fetching
- NEVER use API routes for internal operations

### Security

- Validate ALL input with Zod
- RLS on ALL Supabase tables
- NEVER trust client-side checks
- NEVER expose internal errors to the user

### Tests

- A test that already existed and now fails is never edited to make it pass. Stop and report: either the diagnosis or the test is wrong, and that's the user's call. Exception: the task or spec explicitly changes that test or behavior.

### Imports

```typescript
// 1. React/Next.js core
import { Suspense } from "react";
import { notFound } from "next/navigation";

// 2. External libraries
import { z } from "zod";

// 3. Internal aliases (alphabetical)
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";
```

### Naming Conventions

| Entity             | Convention             | Example                 |
| ------------------ | ---------------------- | ----------------------- |
| Files (components) | `kebab-case.tsx`       | `user-profile-card.tsx` |
| Files (utilities)  | `kebab-case.ts`        | `format-date.ts`        |
| React Components   | `PascalCase`           | `UserProfileCard`       |
| Functions          | `camelCase`            | `formatUserDate`        |
| Constants          | `SCREAMING_SNAKE_CASE` | `MAX_RETRY_ATTEMPTS`    |
| Types/Interfaces   | `PascalCase`           | `UserProfile`           |
| Zod Schemas        | `camelCase` + `Schema` | `userProfileSchema`     |

---

## Quick Skills Index

See `skills/_index.md` for a complete table of all available skills.

## Full Reference

For detailed rules, auto-invoke tables, and full architecture: `AGENTS.md`
