---
name: Transactional Email - Resend & React Email
description: |
  Patterns for transactional emails with Resend and React Email: typed templates, sending from
  Server Actions/services, idempotency, and delivery event handling.
  Trigger: Activated when sending transactional emails or building email templates.
license: MIT
metadata:
  author: ai-library
  version: "1.0"
  scope: [root, backend]
  auto_invoke:
    - "Sending transactional emails"
    - "Building email templates"
    - "Working with Resend"
    - "React Email components"
    - "Handling email delivery webhooks"
---

# Transactional Email - Resend & React Email

> **Core Principle:** Emails are typed components, not string templates. Sending is a service-layer concern with the same validation and error handling as any other side effect.

---

## 🆕 What's New

> **Instruction for Claude:** When this skill is loaded, check this table and mention any entry relevant to what the developer is working on — before writing code.

| Version | Change | Affects |
|---------|--------|---------|
| 1.0 | Initial skill | — |

---

## 🚫 FORBIDDEN PATTERNS

### 1. Never Send Emails Directly from Server Actions

```typescript
// ❌ FORBIDDEN - email logic mixed into the action
'use server'

export async function signUp(formData: FormData) {
  const user = await createUser(formData)
  await resend.emails.send({
    from: 'Acme <onboarding@acme.com>',
    to: user.email,
    subject: 'Welcome',
    html: `<p>Hi ${user.name}, welcome!</p>`, // unstyled, untyped, untested
  })
}

// ✅ CORRECT - dedicated email service, typed template
'use server'
import { sendWelcomeEmail } from '@/lib/email/send'

export async function signUp(formData: FormData) {
  const user = await createUser(formData)
  await sendWelcomeEmail({ to: user.email, name: user.name })
}
```

### 2. Never Skip Idempotency on Retriable Sends

```typescript
// ❌ FORBIDDEN - a retry (network error, action re-run) sends a duplicate email
await resend.emails.send({ from, to, subject, react: <WelcomeEmail /> })

// ✅ CORRECT - idempotency key scoped to the event + entity
await resend.emails.send(
  { from, to, subject, react: <WelcomeEmail /> },
  { idempotencyKey: `welcome-email/${user.id}` },
)
```

### 3. Never Swallow Send Errors

```typescript
// ❌ FORBIDDEN - failure is silent, user never gets their email and nobody knows
const { data } = await resend.emails.send({ ... })

// ✅ CORRECT - check the error, throw a typed AppError so the caller can handle it
const { data, error } = await resend.emails.send({ ... })
if (error) {
  throw new EmailDeliveryError(`Failed to send welcome email: ${error.message}`)
}
```

### 4. Never Style Emails with Plain CSS Files or `<style>` Blocks

Email clients strip `<style>` tags and external stylesheets inconsistently. Use the `Tailwind` wrapper from `react-email`, which inlines styles at render time.

```tsx
// ❌ FORBIDDEN - unreliable across email clients (Outlook, Gmail app)
<style>{`.title { color: blue; }`}</style>
<h1 className="title">Welcome</h1>

// ✅ CORRECT - Tailwind wrapper inlines styles
<Tailwind config={{ presets: [pixelBasedPreset] }}>
  <Heading className="text-2xl font-bold text-brand">Welcome</Heading>
</Tailwind>
```

---

## ✅ REQUIRED PATTERNS

### 1. Typed Email Template

```tsx
// emails/welcome-email.tsx
import {
  Html, Head, Preview, Body, Container, Heading, Text, Button,
  Tailwind, pixelBasedPreset,
} from '@react-email/components'

interface WelcomeEmailProps {
  name: string
  verificationUrl: string
}

export function WelcomeEmail({ name, verificationUrl }: WelcomeEmailProps) {
  return (
    <Html lang="en">
      <Tailwind config={{ presets: [pixelBasedPreset] }}>
        <Head />
        <Body className="bg-gray-100 font-sans">
          <Preview>Welcome — verify your email</Preview>
          <Container className="max-w-xl mx-auto p-5">
            <Heading className="text-2xl font-bold text-gray-800">Welcome, {name}!</Heading>
            <Text className="text-base text-gray-700">
              Thanks for signing up. Verify your email to get started.
            </Text>
            <Button
              href={verificationUrl}
              className="bg-blue-600 text-white px-6 py-3 rounded-lg block text-center no-underline box-border"
            >
              Verify Email
            </Button>
          </Container>
        </Body>
      </Tailwind>
    </Html>
  )
}

// REQUIRED - preview props for the local preview server (`npx email dev`)
WelcomeEmail.PreviewProps = {
  name: 'Jane Doe',
  verificationUrl: 'https://example.com/verify/abc123',
} satisfies WelcomeEmailProps
```

### 2. Service Layer for Sending

```typescript
// lib/email/send.ts
import { Resend } from 'resend'
import { WelcomeEmail } from '@/emails/welcome-email'
import { EmailDeliveryError } from '@/lib/errors'

const resend = new Resend(process.env.RESEND_API_KEY)

interface SendWelcomeEmailInput {
  to: string
  name: string
}

export async function sendWelcomeEmail({ to, name }: SendWelcomeEmailInput): Promise<void> {
  const verificationUrl = await buildVerificationUrl(to)

  const { error } = await resend.emails.send(
    {
      from: 'Acme <onboarding@acme.com>',
      to: [to],
      subject: 'Welcome to Acme',
      react: <WelcomeEmail name={name} verificationUrl={verificationUrl} />,
    },
    { idempotencyKey: `welcome-email/${to}` },
  )

  if (error) {
    throw new EmailDeliveryError(`Failed to send welcome email to ${to}: ${error.message}`)
  }
}
```

### 3. Idempotency Key Convention

Keys must be unique per logical event, ≤256 chars, and expire after 24h server-side (Resend dedupes retries within that window).

```typescript
// REQUIRED - pattern: <event-type>/<entity-id>
`welcome-email/${userId}`
`password-reset/${resetTokenId}`
`invoice-receipt/${invoiceId}`

// FORBIDDEN - random or timestamp-based keys defeat the purpose
`email-${Date.now()}`
`email-${crypto.randomUUID()}` // unless you deliberately want no deduplication
```

### 4. Rendering to Static HTML (non-Resend transports, tests)

```typescript
import { render } from '@react-email/render'
import { WelcomeEmail } from '@/emails/welcome-email'

const html = await render(<WelcomeEmail name="Jane" verificationUrl="https://..." />)
```

### 5. Delivery Webhook Handler (bounces, complaints)

```typescript
// app/api/webhooks/resend/route.ts
export async function POST(request: Request) {
  const payload = await request.text()
  const id = request.headers.get('svix-id')
  const timestamp = request.headers.get('svix-timestamp')
  const signature = request.headers.get('svix-signature')

  if (!id || !timestamp || !signature) {
    return Response.json({ error: 'Missing headers' }, { status: 400 })
  }

  let event: ResendWebhookEvent
  try {
    event = resend.webhooks.verify({
      payload,
      headers: { id, timestamp, signature },
      webhookSecret: process.env.RESEND_WEBHOOK_SECRET!,
    })
  } catch {
    return Response.json({ error: 'Invalid signature' }, { status: 401 })
  }

  if (event.type === 'email.bounced') {
    await markEmailInvalid(event.data.to[0])
  }

  return Response.json({ received: true })
}
```

---

## 📁 File Structure

```
emails/                       # React Email templates (one per email type)
├── welcome-email.tsx
├── password-reset-email.tsx
└── invoice-receipt-email.tsx

lib/
├── email/
│   ├── send.ts                # Service layer — one exported function per email
│   └── resend.ts               # Resend client singleton
└── errors.ts                   # EmailDeliveryError (AppError subclass)

app/
└── api/
    └── webhooks/
        └── resend/
            └── route.ts        # Bounce/complaint/delivery event handler
```

---

## 🔧 Configuration

```bash
# .env
RESEND_API_KEY=re_...
RESEND_WEBHOOK_SECRET=whsec_...
```

Local preview server for template development: `npx email dev` (reads `emails/` by default, `--dir` to override).

---

## 📋 Checklist Before Commit

- [ ] Emails sent through a service function, never inline in a Server Action/route
- [ ] `idempotencyKey` set on every send, following `<event-type>/<entity-id>`
- [ ] Send errors checked and thrown as a typed `EmailDeliveryError`, never swallowed
- [ ] Templates styled with the `Tailwind` wrapper, not `<style>` blocks
- [ ] `PreviewProps` defined on every template for the local preview server
- [ ] Bounce/complaint webhook verified with `resend.webhooks.verify` before processing

---

*Skill Version: 1.0.0 | Compatible with Resend Node SDK, react-email 4.x*
