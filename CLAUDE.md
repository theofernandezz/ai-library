# AI Development Library - Claude Code

Skills (`.claude/skills/`) and subagents (`.claude/agents/`) are listed for you natively, each with when to use it. Load a skill only at the moment you write code in its domain — not upfront.

---

## Before designing: smallest solution that holds

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

---

## Delegation

- **Inline or delegate — count files for the solution the rungs above left.** Inline if understanding the change needs 1–3 files, or it's one mechanical, already-understood file. Delegate (`Agent` tool, `subagent_type: <domain>`) if it needs 4+ files or writes 2+ non-trivial files. Past that threshold you route and review diffs; you don't write domain code.
- **Size the spec to the risk** with skill `spec-driven`: none for clear reversible work, a mini-spec for uncertain work, a full `specs/<slug>.md` for anything costly to revert (schema, auth, payments, public contracts) or split across 2+ subagents. Anything handed to a subagent or `verifier` is persisted there.
- **What to pass:** the spec slice (or the request verbatim) plus paths — never your own reasoning about the code. Don't read the agent's file first.
- **Parallel only with disjoint file sets.**
- **Local model:** boilerplate, mechanical renames, and test stubs can go to opencode via Herdr — skill `local-delegation`.

### Full-stack features

Sequential (`data`/`backend` → `ui` → `testing` → `verifier`), each step getting the previous step's paths and exported names. Worked example in `spec-driven`.

## Verification before "done"

Run `verifier` after a fix, feature, or refactor — skip it for docs/comments/formatting only. Always run it for auth, payments, data mutations, and migrations (`model: opus` for auth, payments, migrations). Freeze the candidate first: capture `git diff` yourself and pass it with the spec — never the implementer's reasoning. One correction round; if the same criterion fails again, stop and report to the user. Details in `spec-driven`.

---

## Library upkeep

- **Only inside the `ai-library` repo:** check open issues (`gh issue list --repo theofernandezz/ai-library --state open`), `skills/improvements.md`, and `skills/changelog.md`, and apply what's relevant. In other projects, each skill's "What's New" table covers its changes when it loads.
- When a loaded skill is missing a pattern, outdated, ambiguous, or contradicts another — or a needed skill doesn't exist — load skill `feedback-loop` and file the signal immediately.
- Library maintenance: `skill-creator` (new skill), `./skills/skill-sync/assets/sync.sh` (registration check).

---

## Global Rules (Always Apply)

- **Types:** no `any` — explicit types everywhere. No `enum` — `as const` object + derived union type.
- **Next.js:** Server Components by default; Client Components only for interactivity. Never `useEffect` for data fetching, never API routes for internal operations.
- **Security:** validate all input with Zod; RLS on all Supabase tables; never trust client-side checks; never expose internal errors to the user.
- **Tests:** a test that already existed and now fails is never edited to make it pass — stop and report (the diagnosis or the test is wrong — the user's call), unless the task or spec explicitly changes that behavior.
- **Imports:** React/Next core → external libraries → internal `@/` aliases (alphabetical).
- **Naming:** files `kebab-case`; components and types `PascalCase`; functions `camelCase`; constants `SCREAMING_SNAKE_CASE`; Zod schemas `camelCase` + `Schema`.
