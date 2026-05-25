# HookCard Component Specification

## Overview

HookCard is a UI card component that displays a single Claude Code Hook entry.
Each variant shows the same data in a completely different visual layout.

## Data Shape (always the same)

```ts
interface Hook {
  id: string
  name: string
  category: string       // UTILITY / SECURITY / WORKFLOW / MONITORING / TESTING / LEARNING
  description: string
  githubUrl: string
  author: string
  stars: number
  language: string       // Python / TypeScript / PHP / Go / JavaScript
  hookTypes: string[]    // PRE_TOOL_USE / POST_TOOL_USE / STOP / NOTIFICATION / etc.
  featured: boolean
}
```

## File Conventions

- Filename: `HookCard<Variant>.tsx`
- Location: `src/components/cards/`
- Must be `'use client'`
- Props: `interface Props { hook: Hook }` — single hook object
- Export: `export default function HookCard<Variant>({ hook }: Props)`
- No external imports (Tailwind + React only)

## Color Palette

| Category | Color |
|----------|-------|
| UTILITY | `#6a9bcc` (blue) |
| SECURITY | `#dc2626` (red) |
| WORKFLOW | `#d97757` (orange) |
| MONITORING | `#7c3aed` (purple) |
| TESTING | `#059669` (green) |
| LEARNING | `#788c5d` (olive) |

Language badge colors: Python→`#3b82f6`, TypeScript→`#8b5cf6`, Go→`#06b6d4`, JavaScript→`#f59e0b`, PHP→`#a855f7`

## Required Elements (every variant must show)

1. Hook name (prominent)
2. Category badge (colored by category)
3. Description (truncated to 2 lines)
4. Author + GitHub link
5. Stars count (formatted: 1200 → "1.2k")
6. Language badge
7. hookTypes chips (max 3 shown)
8. Featured indicator (if hook.featured = true)

## Variation Guidelines

Each variant must have a clearly distinct visual layout:
- Different card shape / border style
- Different information hierarchy
- Different hover interaction
- Same data, different UX feel
