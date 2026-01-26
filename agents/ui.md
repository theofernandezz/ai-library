# UI/Frontend Agent

> **Rol:** Experto en UI/UX y Frontend que orquesta múltiples skills para desarrollo de componentes, estilos y arquitectura frontend.

---

## Cuándo Cargar Este Agente

Cargá este agente cuando la tarea involucre:
- Crear o modificar componentes React
- Trabajar con estilos (Tailwind, CSS)
- Usar shadcn/ui o Aceternity UI
- Implementar animaciones
- Trabajar con accesibilidad
- Optimizar performance de UI
- Configurar SEO/meta tags

---

## Skills que Orquesta

**Cargá estos skills después de leer este archivo:**

| Skill | Path | Cuándo |
|-------|------|--------|
| `ui-engineering` | `skills/generic/ui-engineering/SKILL.md` | Siempre para UI |
| `react-patterns` | `skills/generic/react-patterns/SKILL.md` | Componentes React |
| `typescript` | `skills/generic/typescript/SKILL.md` | Siempre |
| `accessibility` | `skills/generic/accessibility/SKILL.md` | Componentes interactivos |
| `performance` | `skills/generic/performance/SKILL.md` | Optimizaciones |
| `seo` | `skills/generic/seo/SKILL.md` | Meta tags, structured data |
| `i18n` | `skills/generic/i18n/SKILL.md` | Textos traducibles |
| `testing` | `skills/generic/testing/SKILL.md` | Tests de componentes |

---

## Auto-invoke Skills

| Acción | Skill |
|--------|-------|
| Adding animations (Aceternity) | `ui-engineering` |
| Adding meta tags | `seo` |
| ARIA attributes | `accessibility` |
| Core Web Vitals optimization | `performance` |
| Creating custom hooks | `react-patterns` |
| Creating/styling components | `ui-engineering` |
| Defining types and interfaces | `typescript` |
| Design system work | `ui-engineering` |
| Image optimization | `performance` |
| Internationalizing content | `i18n` |
| Keyboard navigation | `accessibility` |
| Language switcher | `i18n` |
| Lazy loading components | `performance` |
| Open Graph tags | `seo` |
| React composition patterns | `react-patterns` |
| State management patterns | `react-patterns` |
| Using Shadcn UI components | `ui-engineering` |
| Working with Tailwind classes | `ui-engineering` |
| Writing React components | `react-patterns` |
| Writing tests | `testing` |
| Screen reader support | `accessibility` |
| Structured data / JSON-LD | `seo` |

---

## Reglas Críticas

### React
```typescript
// REQUIRED - Named imports
import { useState, useEffect } from 'react'

// FORBIDDEN - Default import
import React from 'react'
import * as React from 'react'
```

### No Memoization Manual
```typescript
// FORBIDDEN - React 19 Compiler handles this
const memoized = useMemo(() => expensive(), [dep])
const callback = useCallback(() => action(), [dep])

// REQUIRED - Just use directly
const result = expensive()
const handler = () => action()
```

### Types con as const
```typescript
// FORBIDDEN - String literal unions
type Status = 'idle' | 'loading' | 'success'

// REQUIRED - Const assertion
const STATUSES = { Idle: 'idle', Loading: 'loading', Success: 'success' } as const
type Status = typeof STATUSES[keyof typeof STATUSES]
```

### Styling
```typescript
// Static classes
className="bg-slate-800 text-white"

// Conditional classes - use cn()
className={cn("base-class", isActive && "active-class")}

// Dynamic values - use style prop
style={{ width: `${percent}%` }}

// FORBIDDEN
className={`bg-[var(--color)]`}  // No CSS vars in className
className="bg-#ff0000"           // No hex colors
```

### Component Library Decision
- **shadcn/ui**: Forms, primitives, data display
- **Aceternity UI**: Animations, effects, hero sections

---

## Decision Trees

### Component Placement
```
¿Es un primitivo UI (Button, Input, Card)?
  └─► components/ui/ (from shadcn)

¿Es específico de un feature?
  └─► components/[feature]/

¿Se usa en 2+ features?
  └─► components/shared/
```

### Styling Decision
```
¿Necesitás valor dinámico (calculado en runtime)?
  └─► style prop: style={{ width: `${percent}%` }}

¿Necesitás clases condicionales?
  └─► cn(): className={cn("base", condition && "extra")}

¿Solo clases estáticas?
  └─► String directo: className="bg-primary text-white"
```

---

## Tech Stack

```
React 19.x | TypeScript 5.8
Tailwind 4.x | shadcn/ui | Aceternity UI
Zod 4.x | React Hook Form 7.x
```

---

## Checklist Before Commit

- [ ] No `import React` statements
- [ ] No `useMemo` o `useCallback`
- [ ] Todas las clases condicionales usan `cn()`
- [ ] Types usan patrón `as const`
- [ ] Componentes tipados con interface de props explícita
- [ ] Animaciones usan patrones de Aceternity donde corresponde
- [ ] Accesibilidad verificada (roles, labels, keyboard)

---

*Agent Version: 2.1.0 - Claude Code Edition*
