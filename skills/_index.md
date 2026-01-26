# Skills Index - Quick Reference

> Índice rápido de todos los skills disponibles. Usá este archivo para identificar qué skills cargar.

---

## Generic Skills

| Skill | Path | Patrones Clave |
|-------|------|----------------|
| `typescript` | `generic/typescript/SKILL.md` | `as const`, no `any`, no `enum`, flat interfaces |
| `react-patterns` | `generic/react-patterns/SKILL.md` | Compound components, hooks, composition |
| `nextjs-core` | `generic/nextjs-core/SKILL.md` | Server Components, Server Actions, streaming |
| `ui-engineering` | `generic/ui-engineering/SKILL.md` | Tailwind v4, shadcn, Aceternity, `cn()` |
| `database` | `generic/database/SKILL.md` | Supabase, RLS obligatorio, Zod schemas, service layer |
| `security` | `generic/security/SKILL.md` | XSS/CSRF, input validation, server-side auth |
| `error-handling` | `generic/error-handling/SKILL.md` | Custom errors, Error Boundaries, logging |
| `testing` | `generic/testing/SKILL.md` | Vitest, Testing Library, MSW, behavior-driven |
| `git-workflow` | `generic/git-workflow/SKILL.md` | Conventional Commits, branching, PRs |
| `api-design` | `generic/api-design/SKILL.md` | REST APIs, webhooks, external integrations |
| `i18n` | `generic/i18n/SKILL.md` | next-intl, locale handling, translations |
| `accessibility` | `generic/accessibility/SKILL.md` | WCAG 2.1, ARIA, keyboard navigation |
| `performance` | `generic/performance/SKILL.md` | Core Web Vitals, lazy loading, optimization |
| `seo` | `generic/seo/SKILL.md` | Meta tags, Open Graph, structured data, sitemap |
| `remotion` | `generic/remotion/SKILL.md` | Video creation in React, frame-based animations |

---

## Meta Skills

| Skill | Path | Propósito |
|-------|------|-----------|
| `skill-creator` | `skill-creator/SKILL.md` | Crear nuevos skills siguiendo el template |
| `skill-sync` | `skill-sync/SKILL.md` | Sincronizar metadata a AGENTS.md |
| `feedback-loop` | `feedback-loop/SKILL.md` | Capturar mejoras y learnings |

---

## Matriz de Decisión: Qué Skill Cargar

### Por Tipo de Archivo

| Extensión | Skills a Cargar |
|-----------|-----------------|
| `.ts` | `typescript` |
| `.tsx` | `typescript`, `react-patterns` |
| `.test.ts` / `.test.tsx` | `testing`, `typescript` |
| `app/**/*.tsx` | `nextjs-core`, `typescript`, `react-patterns` |
| `components/**/*.tsx` | `ui-engineering`, `react-patterns`, `typescript` |
| `lib/actions/**/*.ts` | `nextjs-core`, `security`, `typescript` |
| `lib/supabase/**/*.ts` | `database`, `security`, `typescript` |

### Por Tipo de Tarea

| Tarea | Skills Mínimos |
|-------|----------------|
| Crear componente UI | `ui-engineering`, `react-patterns`, `typescript` |
| Crear Server Action | `nextjs-core`, `security`, `database`, `typescript` |
| Crear página/layout | `nextjs-core`, `typescript` |
| Crear hook custom | `react-patterns`, `typescript` |
| Escribir tests | `testing`, `typescript` |
| Configurar auth | `security`, `database`, `nextjs-core` |
| Hacer commit | `git-workflow` |
| Crear API endpoint | `api-design`, `security`, `typescript` |
| Crear video con Remotion | `remotion`, `react-patterns`, `typescript` |

---

## Cómo Cargar un Skill

Para cargar un skill, lee el archivo SKILL.md correspondiente:

```
Leer: skills/generic/{skill-name}/SKILL.md
```

Cada SKILL.md contiene:
- **Core Principle**: Filosofía central
- **FORBIDDEN PATTERNS**: Lo que NUNCA hacer
- **REQUIRED PATTERNS**: Lo que SIEMPRE hacer
- **Checklist Before Commit**: Verificación final

---

## Composición de Skills

Los skills se pueden combinar. Cuando múltiples skills están activos:

1. Las reglas de TODOS los skills aplican simultáneamente
2. En caso de conflicto, el skill más específico gana
3. Las reglas globales (CLAUDE.md/AGENTS.md) siempre tienen precedencia

---

*Skills Index v1.1 | Total: 18 skills*
