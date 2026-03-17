---
name: Project Setup - Context Documentation
description: |
  Meta-skill for documenting project-specific context in CLAUDE.md so Claude
  can make decisions consistent with the project's history, stack, and constraints.
  Trigger: When starting a new project or onboarding to an existing one.
license: MIT
metadata:
  author: ai-library
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Setting up a new project"
    - "Onboarding to an existing project"
    - "Filling in CLAUDE.md project context"
---

# Project Setup - Context Documentation

> **Core Principle:** Claude is only as useful as the context you give it. Generic rules are in the library — your job is to document what Claude can't infer from the code.

---

## What to Document (and What Not To)

### ✅ Document this — Claude can't infer it

| Category | Examples |
|----------|---------|
| **Why this stack** | "We use Supabase instead of Prisma because we needed RLS without custom middleware" |
| **Non-obvious decisions** | "All Server Actions return `ActionResult<T>` — this was standardized after a prod incident" |
| **Domain vocabulary** | "A 'listing' is not a 'product' — they have different lifecycle rules" |
| **Constraints** | "No external API calls in Server Components — latency SLA is 200ms" |
| **Compliance/legal** | "PII must never be logged — GDPR requirement from legal" |
| **Team conventions** | "Feature branches use `feat/ticket-id-description` format" |

### ❌ Don't document this — Claude already knows it or can read the code

- TypeScript best practices
- Framework conventions (Next.js, React)
- General testing patterns
- File naming (already in CLAUDE.md from the library)
- Anything visible in `package.json` or config files

---

## CLAUDE.md Template

Fill in the **Project Context** section of your `CLAUDE.md`. Each field below is optional but high-value:

```markdown
## 📋 Project Context

### Stack
- Framework: Next.js 15 App Router
- Database: Supabase (PostgreSQL)
- Auth: Supabase Auth + custom middleware
- Styling: Tailwind v4 + shadcn/ui

### Key decisions
- Supabase over Prisma: needed RLS at the DB level, not app level
- No Redux/Zustand: Server Components handle most state, Zustand only for UI state
- Monorepo: decided against it — team is small and the overhead wasn't worth it

### Domain conventions
- `listing` ≠ `product`: listings are marketplace entries with their own lifecycle
- `workspace` is the top-level entity, not `organization` or `team`
- All monetary values are stored in cents (integer), never floats

### Constraints
- Server Component data fetching must complete in < 300ms
- No client-side data fetching except for real-time subscriptions
- PII (name, email) must never appear in logs — legal requirement
- Feature freeze the week before each monthly release
```

---

## When to Update

Update your `CLAUDE.md` project context when:

- A significant architectural decision is made
- A domain term is clarified or renamed
- A new constraint is added (legal, performance, team)
- Claude repeatedly makes the same wrong assumption

The signal that context is missing: Claude gives you technically correct code that doesn't fit the project.

---

## Checklist

- [ ] Stack documented with the *why*, not just the *what*
- [ ] At least one non-obvious architectural decision explained
- [ ] Domain vocabulary that differs from common terms is defined
- [ ] Active constraints are listed (performance, compliance, team rules)
- [ ] CLAUDE.md committed to the repo so the whole team benefits

---

*Skill Version: 1.0.0 | Meta-skill — not technology-specific*
