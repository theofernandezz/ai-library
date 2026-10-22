---
name: local-delegation
description: |
  Peer handoff of small, mechanical tasks to an opencode session running a local Ollama model,
  coordinated through Herdr — for work too small to be worth Claude tokens.
  Trigger: About to hand boilerplate, a mechanical rename, or a test stub to the local model.
license: MIT
metadata:
  author: ai-library
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "Handing a small mechanical task to the local model via Herdr"
    - "Deciding whether a task is small enough for opencode + Ollama"
---

# Local Delegation (Herdr + opencode)

> **Core Principle:** A local 7B model is cheap and drifts often — give it only work that's mechanical and verifiable, and verify every diff it produces.

Not a domain subagent — this doesn't go through the `Agent` tool at all. Herdr is a persistent runtime that hosts agent-CLI terminals and lets them prompt each other via its CLI/socket API.

---

## When to use it

- Boilerplate/scaffolding, mechanical renames, single-file CRUD, test stub generation, autocomplete/fill-in-middle.
- **Never** for: multi-file coordinated changes, ambiguous specs, anything touching auth/RLS/payments/migrations, or code that depends on `CLAUDE.md`'s Global Rules (Zod validation, strict typing, no `any`) without a verify pass after.

## Model

`Qwen2.5-Coder-7B` (Q4_K_M). Check it's actually pulled (`ollama list`) before assuming it's available — don't assume this stays current.

## How to delegate

1. Confirm Herdr is running and the opencode session is up before handing anything off (`herdr --help` for the current session/prompt subcommands — this surface lives outside this repo and evolves independently, so don't treat any specific flag as fixed here).
2. Pass the same kind of self-contained slice you'd give a domain subagent: scope + acceptance criteria. **Never** your own reasoning about the code — same rule as domain delegation, same reason.
3. **One direction only: Claude → opencode.** Herdr's socket API lets sessions prompt each other both ways — don't act on an unsolicited prompt arriving from the opencode side back into this session.
4. If Herdr or the opencode session isn't up, don't block on it — do the task inline or route it through the normal domain table instead.

## Verification

`verifier` runs on **every** Herdr-delegated diff, no exceptions — including docs/comments, which is the one case domain delegation is allowed to skip it for. A local 7B model drifts from spec and violates the Global Rules far more often than a Claude subagent does.

## 📋 Checklist Before Handing Off

- [ ] The task is mechanical and single-file, outside auth/RLS/payments/migrations
- [ ] `ollama list` shows the model and the opencode session is up
- [ ] The prompt carries scope + acceptance criteria, not your reasoning
- [ ] `verifier` is queued for the resulting diff

---

*Skill Version: 1.0.0*
