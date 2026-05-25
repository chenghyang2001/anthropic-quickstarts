# API Routes Specification

## Overview

HookHub backend API routes built with **Next.js App Router Route Handlers**.
Each variant is a **complete, self-contained API module** covering one domain area
(hooks discovery, user profiles, or hook submission workflow).

This spec generates TypeScript API route files + shared type definitions.

## Tech Stack

- Runtime: Next.js 15 App Router (`app/api/...route.ts`)
- Language: TypeScript (strict mode)
- Data: JSON files in `src/data/` (no database in this phase)
- Auth: Simulated via `x-api-key` header (no real auth — mock only)
- Response format: `{ data, meta, success, error?, timestamp }`

## File Conventions

Each variant is a **bundle** of related files:

```
src/app/api/<domain>/
├── route.ts          — collection endpoint (GET list, POST create)
├── [id]/
│   └── route.ts     — single resource endpoint (GET, PUT, DELETE)
└── _types.ts         — shared TypeScript interfaces for this domain
```

Export pattern: Route Handlers use named exports `GET`, `POST`, `PUT`, `DELETE`.

## Shared Response Envelope (all routes must use)

```ts
// Success
{ "success": true, "data": <payload>, "meta": { "total": N, ... }, "timestamp": "ISO8601" }

// Error
{ "success": false, "error": { "code": "NOT_FOUND", "message": "Human-readable" }, "timestamp": "ISO8601" }
```

HTTP status codes must be correct (200/201/400/404/422/500 — see tech-stack.md).

## Required API Behaviors (every variant must implement)

1. **Input validation** — validate query params and body fields, return 400 with field-level errors
2. **Error handling** — all try/catch, no unhandled promise rejections
3. **Pagination** — all list endpoints support `?page=1&perPage=20`
4. **Sorting** — list endpoints support `?sortBy=stars|downloads|lastUpdated&order=asc|desc`
5. **Filtering** — list endpoints support domain-specific query params (e.g. `?category=SECURITY`)
6. **CORS headers** — `Access-Control-Allow-Origin: *` on all responses
7. **No hardcoded paths** — data loaded via `path.join(process.cwd(), 'src/data/...')`

## Variation Guidelines

Each variant covers a **different domain** of the HookHub API:

### Variant A — Hooks Discovery API
Endpoints:
- `GET /api/hooks` — list all hooks (pagination + filter by category, language, hookType + sort)
- `GET /api/hooks/[id]` — single hook detail
- `GET /api/hooks/featured` — featured hooks only
- `GET /api/hooks/search?q=...` — full-text search across name, description, tags

TypeScript types: `Hook`, `HookListResponse`, `HookDetailResponse`, `SearchResponse`

### Variant B — User Profiles API
Endpoints:
- `GET /api/users` — list community contributors (pagination + sort by stars, hookCount)
- `GET /api/users/[username]` — single user profile
- `GET /api/users/[username]/hooks` — hooks published by this user
- `GET /api/users/[username]/stats` — contribution stats (total stars, downloads, hook count)

TypeScript types: `UserProfile`, `UserStats`, `UserListResponse`, `UserHooksResponse`

### Variant C — Hook Submission Workflow API
Endpoints:
- `POST /api/submissions` — submit a new hook (body: githubUrl + metadata)
- `GET /api/submissions` — list pending submissions (admin mock — requires x-api-key)
- `GET /api/submissions/[id]` — single submission status
- `PUT /api/submissions/[id]/review` — approve/reject (body: `{ action: 'approve'|'reject', reason?: string }`)
- `GET /api/submissions/[id]/validate` — validate GitHub URL + fetch repo metadata

TypeScript types: `HookSubmission`, `SubmissionStatus`, `ReviewAction`, `ValidationResult`

## Error Code Enum

All variants must use this shared error vocabulary:
```ts
type ApiErrorCode =
  | 'NOT_FOUND'
  | 'INVALID_INPUT'
  | 'MISSING_REQUIRED_FIELD'
  | 'UNAUTHORIZED'
  | 'RATE_LIMITED'
  | 'INTERNAL_ERROR'
```

## Data Source

Read from existing JSON files:
- `src/data/hooks.json` — hook entries (already exists)
- `src/data/mocks/*.mock.json` — extended mock data (if generated)

For Variant B & C, fabricate realistic in-memory mock data (no external file needed).

## Example Route Handler Pattern

```ts
// src/app/api/hooks/route.ts
import { NextRequest, NextResponse } from 'next/server'
import path from 'path'
import fs from 'fs'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const page = parseInt(searchParams.get('page') ?? '1')
    const perPage = parseInt(searchParams.get('perPage') ?? '20')
    const category = searchParams.get('category')

    // Load data
    const dataPath = path.join(process.cwd(), 'src/data/hooks.json')
    const raw = JSON.parse(fs.readFileSync(dataPath, 'utf-8'))
    let hooks: Hook[] = raw.hooks

    // Filter
    if (category) hooks = hooks.filter(h => h.category === category)

    // Paginate
    const total = hooks.length
    const items = hooks.slice((page - 1) * perPage, page * perPage)

    return NextResponse.json({
      success: true,
      data: items,
      meta: { total, page, perPage, totalPages: Math.ceil(total / perPage) },
      timestamp: new Date().toISOString()
    })
  } catch (error) {
    return NextResponse.json(
      { success: false, error: { code: 'INTERNAL_ERROR', message: 'Failed to fetch hooks' }, timestamp: new Date().toISOString() },
      { status: 500 }
    )
  }
}
```
