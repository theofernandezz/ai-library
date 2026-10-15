---
name: seo
description: |
  SEO patterns for Next.js applications. Meta tags, structured data, sitemaps, Open Graph.
  Trigger: Activated when working on meta tags, SEO, or search optimization.
license: MIT
metadata:
  author: ai-library
  version: "2.0"
  scope: [root, ui, backend]
  auto_invoke:
    - "Adding meta tags"
    - "SEO optimization"
    - "Open Graph tags"
    - "Structured data"
    - "Creating sitemap"
---

# SEO - Search Engine Optimization

> **Core Principle:** Every page should be discoverable, crawlable, and shareable with rich previews.

---

## 🆕 What's New

> **Instruction for Claude:** When this skill is loaded, check this table and mention any entry relevant to what the developer is working on — before writing code.

| Version | Change | Affects |
|---------|--------|---------|
| — | No tracked changes yet | — |

---

## 🎯 SEO Essentials

| Element | Purpose |
|---------|---------|
| **Title** | ~60 chars, unique per page |
| **Description** | ~160 chars, compelling summary |
| **Open Graph** | Social media previews |
| **Structured Data** | Rich snippets in search results |
| **Sitemap** | Help crawlers find pages |
| **robots.txt** | Control crawler access |

---

## 🚫 FORBIDDEN PATTERNS

### 1. Never Use Duplicate Titles

```typescript
// ❌ FORBIDDEN - Same title everywhere
export const metadata = {
  title: 'My App',
}

// ✅ CORRECT - Unique, descriptive titles
export const metadata = {
  title: 'Dashboard - My App',
}

// ✅ CORRECT - Template pattern
// app/layout.tsx
export const metadata = {
  title: {
    default: 'My App',
    template: '%s | My App',
  },
}

// app/dashboard/page.tsx
export const metadata = {
  title: 'Dashboard', // Renders: "Dashboard | My App"
}
```

### 2. Never Skip Meta Descriptions

```typescript
// ❌ FORBIDDEN - Missing description
export const metadata = {
  title: 'Pricing',
}

// ✅ CORRECT - Descriptive, keyword-rich
export const metadata = {
  title: 'Pricing Plans',
  description: 'Choose from our flexible pricing plans. Start free, upgrade anytime. Enterprise solutions available for large teams.',
}
```

### 3. Never Use `noindex` on Important Pages

```typescript
// ❌ FORBIDDEN - Blocking indexing of main content
export const metadata = {
  robots: 'noindex, nofollow', // On public pages
}

// ✅ CORRECT - Only use for private/duplicate content
// app/(dashboard)/settings/page.tsx (logged-in only)
export const metadata = {
  robots: 'noindex',
}
```

---

## ✅ REQUIRED PATTERNS

### 1. Root Layout Metadata

- `metadataBase` is required: it resolves relative OG image URLs
- `title` uses `default` + `template` (`%s | My App`) so child pages inherit the suffix
- Always define `openGraph` (image 1200x630) and `twitter` with `summary_large_image`
- Set `robots` explicitly

```typescript
// app/layout.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  metadataBase: new URL('https://myapp.com'),
  title: { default: 'My App - The Best Solution', template: '%s | My App' },
  description: 'My App helps you do amazing things. Start free today.',
  openGraph: {
    type: 'website',
    url: 'https://myapp.com',
    siteName: 'My App',
    images: [{ url: '/og-image.jpg', width: 1200, height: 630, alt: 'My App Preview' }],
  },
  twitter: { card: 'summary_large_image', images: ['/og-image.jpg'] },
  robots: { index: true, follow: true },
}
```

### 2. Dynamic Page Metadata

```typescript
// app/blog/[slug]/page.tsx
import type { Metadata } from 'next'
import { getPost } from '@/lib/data/posts'

interface Props {
  params: { slug: string }
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params
  const post = await getPost(slug)

  if (!post) {
    return { title: 'Post Not Found' }
  }

  return {
    title: post.title,
    description: post.excerpt,
    openGraph: {
      title: post.title,
      description: post.excerpt,
      type: 'article',
      publishedTime: post.publishedAt,
      authors: [post.author.name],
      images: [
        {
          url: post.coverImage,
          width: 1200,
          height: 630,
          alt: post.title,
        },
      ],
    },
    twitter: {
      card: 'summary_large_image',
      title: post.title,
      description: post.excerpt,
      images: [post.coverImage],
    },
  }
}
```

### 3. Sitemap Generation

```typescript
// app/sitemap.ts
import type { MetadataRoute } from 'next'
import { getAllPosts } from '@/lib/data/posts'
import { getAllProducts } from '@/lib/data/products'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const baseUrl = 'https://myapp.com'

  // Static pages
  const staticPages: MetadataRoute.Sitemap = [
    {
      url: baseUrl,
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1,
    },
    {
      url: `${baseUrl}/pricing`,
      lastModified: new Date(),
      changeFrequency: 'weekly',
      priority: 0.8,
    },
    {
      url: `${baseUrl}/about`,
      lastModified: new Date(),
      changeFrequency: 'monthly',
      priority: 0.5,
    },
  ]

  // Dynamic blog posts
  const posts = await getAllPosts()
  const blogPages: MetadataRoute.Sitemap = posts.map((post) => ({
    url: `${baseUrl}/blog/${post.slug}`,
    lastModified: new Date(post.updatedAt),
    changeFrequency: 'weekly',
    priority: 0.6,
  }))

  // Dynamic products
  const products = await getAllProducts()
  const productPages: MetadataRoute.Sitemap = products.map((product) => ({
    url: `${baseUrl}/products/${product.slug}`,
    lastModified: new Date(product.updatedAt),
    changeFrequency: 'daily',
    priority: 0.7,
  }))

  return [...staticPages, ...blogPages, ...productPages]
}
```

### 4. Robots.txt

```typescript
// app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  const baseUrl = 'https://myapp.com'

  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/api/', '/dashboard/', '/admin/', '/settings/'],
      },
    ],
    sitemap: `${baseUrl}/sitemap.xml`,
  }
}
```

### 5. Structured Data (JSON-LD)

- One typed component per schema.org type (Organization, Article, Product), rendered in the Server Component that owns the data
- Serialize with `JSON.stringify` and escape `<` as `<`: otherwise a field containing `</script>` breaks out of the tag (XSS)

```tsx
// components/structured-data.tsx
function JsonLd({ data }: { data: Record<string, unknown> }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data).replace(/</g, '\\u003c') }}
    />
  )
}

export function ArticleSchema({ post }: { post: Post }) {
  return (
    <JsonLd
      data={{
        '@context': 'https://schema.org',
        '@type': 'Article',
        headline: post.title,
        datePublished: post.publishedAt,
        dateModified: post.updatedAt,
        author: { '@type': 'Person', name: post.author.name },
      }}
    />
  )
}

// OrganizationSchema / ProductSchema: same pattern with their own '@type' and fields
```

### 6. Canonical URLs

```typescript
// For pages with potential duplicates
export const metadata = {
  alternates: {
    canonical: 'https://myapp.com/products/shoes',
    languages: {
      'en-US': 'https://myapp.com/en/products/shoes',
      'es-ES': 'https://myapp.com/es/products/shoes',
    },
  },
}
```

### 7. Image Alt Tags for SEO

```typescript
// ✅ REQUIRED - Descriptive alt text
<Image
  src="/products/blue-sneakers.jpg"
  alt="Blue Nike Air Max sneakers, size 10"
  width={600}
  height={400}
/>

// ❌ FORBIDDEN - Generic or missing
<Image src="/image.jpg" alt="image" />
<Image src="/product.jpg" alt="" />
```

---

### 8. hreflang for Multi-Language Apps

> ⚠️ **Cross-skill dependency:** Use alongside the [`i18n` skill](../i18n/SKILL.md) for full multi-language SEO coverage.

```typescript
// app/[locale]/layout.tsx
import type { Metadata } from 'next'
import { locales } from '@/i18n/config'

const BASE_URL = 'https://myapp.com'

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  return {
    alternates: {
      canonical: `${BASE_URL}/${params.locale}`,
      languages: Object.fromEntries(
        locales.map((locale) => [locale, `${BASE_URL}/${locale}`])
      ),
    },
  }
}

// Explicit example:
// { 'en': 'https://myapp.com/en', 'es': 'https://myapp.com/es' }
```

### 9. PWA Manifest

```typescript
// app/manifest.ts
import type { MetadataRoute } from 'next'

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'My App',
    short_name: 'MyApp',
    description: 'My App helps you do amazing things.',
    start_url: '/',
    display: 'standalone',
    background_color: '#09090b',
    theme_color: '#09090b',
    icons: [
      {
        src: '/icon-192.png',
        sizes: '192x192',
        type: 'image/png',
        purpose: 'maskable',
      },
      {
        src: '/icon-512.png',
        sizes: '512x512',
        type: 'image/png',
      },
    ],
  }
}
```

```typescript
// app/layout.tsx - Reference the manifest
export const metadata: Metadata = {
  manifest: '/manifest.webmanifest',
  // ... rest of metadata
}
```

---

## 📁 File Structure

```
app/
├── layout.tsx          # Global metadata
├── page.tsx            # Home page metadata
├── sitemap.ts          # Sitemap generation
├── robots.ts           # Robots.txt
├── manifest.ts         # PWA manifest
├── blog/
│   └── [slug]/
│       └── page.tsx    # Dynamic metadata
└── products/
    └── [id]/
        └── page.tsx    # Product metadata

components/
└── seo/
    └── structured-data.tsx

public/
├── og-image.jpg        # Default Open Graph image
└── robots.txt          # (optional static)
```

---

## 🔍 SEO Audit Checklist

### Technical SEO
- [ ] Sitemap exists and is valid
- [ ] robots.txt configured correctly
- [ ] Canonical URLs set for duplicates
- [ ] HTTPS enabled
- [ ] Mobile responsive

### On-Page SEO
- [ ] Unique title for each page (< 60 chars)
- [ ] Meta description for each page (< 160 chars)
- [ ] One H1 per page
- [ ] Heading hierarchy (H1 → H2 → H3)
- [ ] Images have descriptive alt text

### Social SEO
- [ ] Open Graph tags configured
- [ ] Twitter Card tags configured
- [ ] Share image exists (1200x630)

### Structured Data
- [ ] Organization schema on home page
- [ ] Article schema on blog posts
- [ ] Product schema on product pages

---

## 📋 Checklist Before Commit

- [ ] Page has unique title
- [ ] Page has meta description
- [ ] Open Graph image specified
- [ ] Structured data added where applicable
- [ ] All images have alt text
- [ ] New pages added to sitemap

---

*Skill Version: 2.0.0 | Next.js 16.x SEO Patterns*
