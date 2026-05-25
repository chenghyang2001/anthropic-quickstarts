# Hook Detail Page Specification

## Overview

The Hook Detail page is the **deep-dive experience** for a single Hook.
It gives developers everything they need to evaluate, understand, and install a hook —
without leaving HookHub.

This is a **full-page component** showing one hook's complete profile.
Each variant takes a completely different approach to information hierarchy and user flow.

## Business Goal

A developer who lands on this page should be able to:
1. Understand what the hook does in under 10 seconds
2. See the exact installation command (copy with one click)
3. View source code preview (key file) without visiting GitHub
4. Read community reviews and star ratings
5. Discover related hooks

## Data Shape

```ts
interface HookDetail extends Hook {
  readme: string           // Markdown content of the hook's README
  installCommand: string   // e.g. "npx hookhub install security-scanner"
  sourcePreview: {         // Key source file preview
    filename: string
    language: string
    content: string        // First 50 lines of main hook file
  }
  reviews: Review[]
  relatedHooks: Hook[]     // 3 hooks from same category
  changelog: ChangelogEntry[]
}

interface Review {
  id: string
  author: string
  avatarInitials: string   // e.g. "JL" (no img URLs needed)
  rating: 1 | 2 | 3 | 4 | 5
  body: string
  createdAt: string        // ISO 8601
  helpful: number          // "X people found this helpful"
}

interface ChangelogEntry {
  version: string
  date: string             // ISO 8601
  changes: string[]        // List of changes for this version
}
```

All data **hardcoded inside the component** (no props, no API call).
Use realistic mock data that matches a real security scanning hook.

## File Conventions

- Filename: `HookDetailPage<Variant>.tsx`
- Location: `src/components/pages/`
- Must be `'use client'` (tab switching, copy button state)
- No props (all data hardcoded)
- Export: `export default function HookDetailPage<Variant>()`
- No external imports (Tailwind + React only)

## Required Sections (every variant must include all 7)

### 1. Hero / Header
- Hook name (H1), large and prominent
- Category badge + language badge
- Author with GitHub link
- Stars + Downloads counters
- "Featured" badge if applicable
- **Install Command Block**: `npx hookhub install <id>` with copy-to-clipboard button
  - Copy button toggles between "Copy" → "Copied!" for 2 seconds (useState)

### 2. Overview Tab / Section
- Hook description (full, not truncated)
- Hook types supported (visual chips showing all lifecycle events)
- Version + License + Last updated metadata row
- Tags as clickable badges

### 3. Source Code Preview
- Filename header (e.g. `hook.py` or `hook.ts`)
- Code block with syntax highlighting (CSS only, no library — use `<pre><code>`)
- Language label
- Link to full file on GitHub
- Minimum 20 lines of realistic hook source code (hardcoded)

### 4. README Section
- Rendered as styled HTML (use Tailwind prose-like styles, no external library)
- Must include: description paragraph, usage example, configuration options table
- "View on GitHub" link at bottom

### 5. Reviews Section
- Star rating summary: average (e.g. 4.3 ★) + distribution bar chart (CSS only)
- At least 4 individual review cards with: avatar initials, rating stars, body text, date, helpful count
- "Was this helpful?" thumbs up/down buttons (visual only, no state needed)

### 6. Changelog
- Version history table or timeline
- At least 3 versions with realistic change notes
- Most recent version highlighted

### 7. Related Hooks
- 3 hook cards from same category
- Compact card design (name + description only)
- "Browse more SECURITY hooks →" link

## Color Palette

- Primary: `#d97757`
- Secondary: `#6a9bcc`
- Background: `var(--background)`
- Foreground: `var(--foreground)`
- Border: `var(--border)`
- Slate Light: `var(--slate-light)`
- Code background: `#1e1e2e` (dark, always — even in light mode)
- Code text: `#cdd6f4`

## Variation Guidelines

Each variant must choose a distinct **navigation/layout paradigm**:

- **Tabbed Layout** — all 7 sections behind tabs (Overview / Source / Reviews / Changelog / Related)
- **Single Scroll** — all sections stacked vertically with sticky section nav on left
- **Split Panel** — left: metadata + install + tabs; right: persistent sticky install card + related hooks
- **Magazine Layout** — hero spans full width, sections in asymmetric 3-col grid below

## Interactive Requirements

1. **Copy Button** — install command clipboard copy with "Copied!" feedback (useState)
2. **Tab/Section switching** — if using tabbed layout, smooth content swap (useState activeTab)
3. **Review helpfulness** — "Helpful" button visual click state per review (useState per review id)
4. **Star display** — filled/empty SVG stars for ratings (no library)

## Mock Data to Hardcode

Use this hook as the example:
- **Name**: "Security Scanner Pro"
- **ID**: `security-scanner-pro`
- **Category**: SECURITY
- **Author**: `alex-devops`
- **Stars**: 2847
- **Downloads**: 18432
- **Language**: Python
- **Hook Types**: `["PRE_TOOL_USE"]`
- **Version**: `2.1.0`
- **License**: MIT
- **Featured**: true
- **Average Rating**: 4.6 (from 89 reviews)

The source preview should be a realistic Python hook that:
- Intercepts tool use before execution
- Checks for dangerous patterns (rm -rf, DROP TABLE, etc.)
- Returns a block response if threat detected
- Logs all checks to `~/.claude/security-log.json`
