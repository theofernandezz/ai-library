---
name: Security Best Practices
description: |
  Security patterns for SaaS applications: input validation, XSS/CSRF prevention, auth, and secure headers.
  Trigger: Activated when handling user input, auth, or security-related code.
license: MIT
metadata:
  author: ai-library
  version: "2.2"
  scope: [root, backend, auth]
  auto_invoke:
    - "Handling user input"
    - "Authentication patterns"
    - "Authorization checks"
    - "Security headers"
    - "Input validation/sanitization"
---

# Security Best Practices

> **Core Principle:** Never trust user input. Defense in depth. Fail secure, not open.

---

## What's New

| Version | Change | Affects |
|---------|--------|---------|
| 2.2 (2026-09-23) | Next.js 16 renamed `middleware.ts` → `proxy.ts` (export `proxy`, Node.js runtime) — security-headers example updated; on Next.js 15 or earlier keep `middleware.ts` | proxy.ts |
| 2.1 (2026-03-31) | `X-XSS-Protection` removed — OWASP 2025 recommends omitting it (can introduce XSS in IE/Chrome <78) | middleware.ts |
| 2.1 (2026-03-31) | In-memory rate limiter is serverless-unsafe — use Upstash/Redis in production | rate-limit.ts |
| 2.1 (2026-03-31) | CSP `unsafe-eval` + `unsafe-inline` flagged by OWASP 2025 — prefer nonce-based CSP | middleware.ts |
| 2.1 (2026-03-31) | `headers()` in Next.js 15+ must be `await`-ed — CSRF helper updated | lib/security/csrf.ts |
| 2.0 | `javascript:` URLs blocked automatically in Next.js 16.2.1 for router/Link/redirect | router, Link |

> **Check this table before writing security code** and surface any applicable changes to the user.

---

## 🚫 FORBIDDEN PATTERNS

### 1. Never Render User Input Directly as HTML

```typescript
// ❌ FORBIDDEN - XSS vulnerability
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// ❌ FORBIDDEN - Even with "sanitization"
<div dangerouslySetInnerHTML={{ __html: sanitize(userInput) }} />

// ✅ CORRECT - React escapes by default
<div>{userInput}</div>

// ✅ If HTML is needed, use a trusted library with strict config
import DOMPurify from 'isomorphic-dompurify'

const cleanHTML = DOMPurify.sanitize(userInput, {
  ALLOWED_TAGS: ['p', 'b', 'i', 'em', 'strong', 'a'],
  ALLOWED_ATTR: ['href'],
})
<div dangerouslySetInnerHTML={{ __html: cleanHTML }} />
```

### 2. Never Interpolate User Input in SQL

```typescript
// ❌ FORBIDDEN - SQL Injection
const query = `SELECT * FROM users WHERE id = '${userId}'`

// ❌ FORBIDDEN - Even with "escaping"
const query = `SELECT * FROM users WHERE id = '${escape(userId)}'`

// ✅ CORRECT - Use parameterized queries (Supabase handles this)
const { data } = await supabase
  .from('users')
  .select('*')
  .eq('id', userId)

// ✅ CORRECT - If raw SQL needed, use parameters
const { data } = await supabase.rpc('get_user', { user_id: userId })
```

### 3. Never Store Secrets in Client Code

```typescript
// ❌ FORBIDDEN - Exposed to client
const API_KEY = 'sk_live_abc123' // In client component

// ❌ FORBIDDEN - NEXT_PUBLIC_ prefix exposes to client
process.env.NEXT_PUBLIC_SECRET_KEY

// ✅ CORRECT - Server-only environment variables
// In Server Component or Server Action
const apiKey = process.env.SECRET_API_KEY

// ✅ CORRECT - Check for client exposure
if (typeof window !== 'undefined') {
  throw new Error('This code should not run on client')
}
```

### 4. Never Trust Client-Side Auth Checks Alone

```typescript
// ❌ FORBIDDEN - Client-only protection
'use client'
export function AdminPanel() {
  const { user } = useAuth()
  if (!user?.isAdmin) return <Redirect to="/" />
  // Attacker can bypass by modifying JS
  return <SecretData />
}

// ✅ CORRECT - Server-side verification
// app/admin/page.tsx (Server Component)
export default async function AdminPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  
  if (!user) redirect('/login')
  
  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()
  
  if (profile?.role !== 'admin') redirect('/')
  
  return <AdminPanel />
}
```

---

## ✅ REQUIRED PATTERNS

### 1. Input Validation with Zod

```typescript
// lib/validations/user.ts
import { z } from 'zod'

// Strict schemas for all user input
export const userInputSchema = z.object({
  email: z.string()
    .email('Invalid email format')
    .max(255, 'Email too long')
    .toLowerCase()
    .trim(),
  
  name: z.string()
    .min(1, 'Name is required')
    .max(100, 'Name too long')
    .trim()
    .regex(/^[\p{L}\p{N}\s'-]+$/u, 'Name contains invalid characters'),
  
  bio: z.string()
    .max(500, 'Bio too long')
    .optional()
    .transform(val => val?.trim()),
  
  website: z.string()
    .url('Invalid URL')
    .optional()
    .refine(
      url => !url || url.startsWith('https://'),
      'URL must use HTTPS'
    ),
})

// Validate EVERY user input
export function validateUserInput(data: unknown) {
  return userInputSchema.safeParse(data)
}
```

### 2. Security Headers (Proxy)

- Set security headers in `proxy.ts`: `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, `Permissions-Policy`
- Do NOT set `X-XSS-Protection`: OWASP 2025 advises against it (it can introduce XSS in old browsers); protection comes from CSP
- CSP: prefer a nonce-based `script-src` (`'nonce-${nonce}'`, nonce passed to the layout for `<Script nonce>`). `'unsafe-inline'`/`'unsafe-eval'` defeat XSS protection; `'unsafe-inline'` is acceptable only for `style-src` when nonces aren't possible
- HSTS in production only

```typescript
// proxy.ts (middleware.ts on Next.js 15 and earlier — see `nextjs-core`)
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function proxy(request: NextRequest) {
  const response = NextResponse.next()
  const headers = response.headers

  headers.set('X-Frame-Options', 'DENY')
  headers.set('X-Content-Type-Options', 'nosniff')
  headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  headers.set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()')
  headers.set(
    'Content-Security-Policy',
    [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'", // fallback: replace with a nonce (see rules above)
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: https:",
      "connect-src 'self' https://*.supabase.co",
      "frame-ancestors 'none'",
    ].join('; ')
  )

  if (process.env.NODE_ENV === 'production') {
    headers.set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload')
  }

  return response
}
```

### 3. JavaScript URL Blocking

As of Next.js 16.2.1, `javascript:` URLs are blocked automatically in `router.push()`, `router.replace()`, `<Link href>`, and `redirect()`. No manual sanitization needed for these cases.

```typescript
// ✅ These are now blocked automatically by Next.js 16.2.1+
router.push('javascript:alert(1)')   // throws
redirect('javascript:alert(1)')      // throws

// ⚠️ Still sanitize user-supplied URLs going into OTHER sinks
const safeUrl = url.startsWith('https://') ? url : '/fallback'
```

### 4. CSRF Protection for Server Actions

```typescript
// Server Actions have built-in CSRF protection in Next.js.
// For custom API routes, add explicit origin checks.
// Next.js 15+: headers() returns a Promise — always await it.

// lib/security/csrf.ts
import { headers } from 'next/headers'

export async function validateOrigin(): Promise<void> {
  const headersList = await headers() // required await in Next.js 15+
  const origin = headersList.get('origin')
  const host = headersList.get('host')

  if (!origin || !host) {
    throw new Error('Missing origin or host header')
  }

  const originUrl = new URL(origin)
  if (originUrl.host !== host) {
    throw new Error('Origin mismatch - possible CSRF')
  }
}

// Usage in API route
export async function POST(request: Request) {
  await validateOrigin()
  // ... handle request
}
```

### 5. Rate Limiting

- Production on Vercel/edge: Upstash Redis. An in-memory `Map` resets on every cold start and isn't shared across instances: use it only for local dev or a single long-lived Node server, behind the same `checkRateLimit` signature
- Key by route + IP (`form:${ip}`); `headers()` must be awaited on Next.js 15+
- Return a generic "too many requests" error, never internals

```typescript
// lib/security/rate-limit.ts — Install: pnpm add @upstash/ratelimit @upstash/redis
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const ratelimit = new Ratelimit({
  redis: Redis.fromEnv(),
  limiter: Ratelimit.slidingWindow(10, '1 m'),
})

export async function checkRateLimit(key: string): Promise<{ allowed: boolean; remaining: number }> {
  const { success, remaining } = await ratelimit.limit(key)
  return { allowed: success, remaining }
}

// Usage in a Server Action
export async function submitForm(formData: FormData) {
  const ip = (await headers()).get('x-forwarded-for') ?? 'unknown'
  const { allowed } = await checkRateLimit(`form:${ip}`)
  if (!allowed) return { error: 'Too many requests. Please wait a moment.' }

  // Process form...
}
```

### 6. Secure Authentication Pattern

```typescript
// lib/auth/server.ts
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import { cache } from 'react'

// Cached auth check - deduplicated per request
export const getUser = cache(async () => {
  const supabase = await createClient()
  const { data: { user }, error } = await supabase.auth.getUser()
  
  if (error || !user) {
    return null
  }
  
  return user
})

// Require auth - redirect if not authenticated
export async function requireAuth() {
  const user = await getUser()
  
  if (!user) {
    redirect('/login')
  }
  
  return user
}

// Require role - check specific permission
export async function requireRole(allowedRoles: string[]) {
  const user = await requireAuth()
  const supabase = await createClient()
  
  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('id', user.id)
    .single()
  
  if (!profile || !allowedRoles.includes(profile.role)) {
    redirect('/unauthorized')
  }
  
  return { user, role: profile.role }
}

// Usage in Server Component
export default async function AdminPage() {
  const { user, role } = await requireRole(['admin', 'superadmin'])
  
  return <div>Welcome, {role}!</div>
}
```

### 7. Secure Cookie Configuration

```typescript
// For custom cookies (Supabase handles auth cookies)
import { cookies } from 'next/headers'

export async function setSecureCookie(name: string, value: string) {
  const cookieStore = await cookies()
  
  cookieStore.set(name, value, {
    httpOnly: true,      // Not accessible via JavaScript
    secure: process.env.NODE_ENV === 'production', // HTTPS only in prod
    sameSite: 'lax',     // CSRF protection
    maxAge: 60 * 60 * 24 * 7, // 1 week
    path: '/',
  })
}
```

---

## 🔐 Environment Variables Security

```bash
# .env.local (NEVER commit this)
# Server-only secrets (no NEXT_PUBLIC_ prefix)
SUPABASE_SERVICE_ROLE_KEY=eyJhb...
STRIPE_SECRET_KEY=sk_live_...
ENCRYPTION_KEY=...

# Public variables (safe to expose)
NEXT_PUBLIC_SUPABASE_URL=https://...
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhb...
```

```typescript
// lib/env.ts - Validate env at startup
import { z } from 'zod'

const envSchema = z.object({
  // Server-only
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  
  // Public
  NEXT_PUBLIC_SUPABASE_URL: z.string().url(),
  NEXT_PUBLIC_SUPABASE_ANON_KEY: z.string().min(1),
})

// Validate at build time
export const env = envSchema.parse(process.env)
```

---

## 📁 File Structure

```
lib/
├── security/
│   ├── csrf.ts            # CSRF validation
│   ├── rate-limit.ts      # Rate limiting
│   └── sanitize.ts        # Input sanitization
├── auth/
│   ├── server.ts          # Server auth helpers
│   └── client.ts          # Client auth hooks
├── validations/
│   └── *.ts               # Zod schemas for all inputs
└── env.ts                 # Environment validation

proxy.ts                   # Security headers, auth refresh
```

---

## 📋 Security Checklist

- [ ] All user input validated with Zod before use
- [ ] No `dangerouslySetInnerHTML` with user content
- [ ] Parameterized queries only (no string interpolation)
- [ ] Server-side auth checks on all protected routes
- [ ] Security headers configured in `proxy.ts`
- [ ] `X-XSS-Protection` NOT set (OWASP 2025 recommendation)
- [ ] CSP uses nonces instead of `unsafe-inline`/`unsafe-eval` where possible
- [ ] Rate limiting on sensitive endpoints (Upstash/Redis in serverless)
- [ ] `headers()` and `cookies()` are `await`-ed (Next.js 15+)
- [ ] Secrets never exposed to client
- [ ] HTTPS enforced in production
- [ ] Cookies marked as HttpOnly and Secure

---

*Skill Version: 2.1.0 | SaaS Security Standards 2026 | Last verified: 2026-03-31*
