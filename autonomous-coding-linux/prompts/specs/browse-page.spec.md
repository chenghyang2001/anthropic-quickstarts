# Browse Page Specification

## Overview

The Browse / Discover page is the **core experience** of HookHub — where users explore,
filter, and find Claude Code hooks to install. Each variant represents a completely
different approach to information architecture and discovery UX.

This is a **full-page component** (`src/app/browse/page.tsx` or a standalone TSX page),
not a single section or card.

## Business Goal

Allow developers to:
1. Quickly find hooks relevant to their workflow
2. Filter by category, language, hook type, and sort order
3. Preview hook metadata before visiting GitHub
4. Install with one CLI command

## Data Shape

```ts
interface Hook {
  id: string
  name: string
  category: 'UTILITY' | 'SECURITY' | 'WORKFLOW' | 'MONITORING' | 'TESTING' | 'LEARNING' | 'INTEGRATION' | 'TEAM'
  description: string
  githubUrl: string
  author: string
  stars: number
  downloads: number
  language: 'Python' | 'TypeScript' | 'Go' | 'JavaScript' | 'PHP' | 'Rust'
  hookTypes: string[]
  featured: boolean
  lastUpdated: string   // ISO 8601
  tags: string[]
  version: string
  license: string
}
```

All data sourced from `@/data/hooks.json` (already exists in project).

## File Conventions

- Filename: `BrowsePage<Variant>.tsx`
- Location: `src/components/pages/`
- Must be `'use client'` (needs useState for filters)
- No props (loads data internally from hooks.json)
- Export: `export default function BrowsePage<Variant>()`
- No external imports (Tailwind + React only)

## Required Features (every variant must include)

### 1. Search Bar
- Full-text search across name, description, author, tags
- Debounced input (no library — implement with useEffect + setTimeout)
- Clear button when search has text
- Result count display ("Showing 12 of 18 hooks")

### 2. Filter Panel
Must support all of the following filters simultaneously:
- **Category** — multi-select checkboxes or toggle buttons (UTILITY, SECURITY, WORKFLOW, MONITORING, TESTING, LEARNING)
- **Language** — multi-select (Python, TypeScript, Go, JavaScript, PHP)
- **Hook Type** — multi-select (PRE_TOOL_USE, POST_TOOL_USE, STOP, NOTIFICATION, SUBAGENT_*)
- **Sort** — single-select dropdown: Stars ↓, Downloads ↓, Recently Updated, Name A-Z

### 3. Results Grid
- Responsive: 1 col (mobile) → 2 col (tablet) → 3 col (desktop)
- Uses the `HookCard` component from `@/components/HookCard`
- Empty state when no results match filters
- "Featured" hooks shown first (or clearly marked)

### 4. Filter State Summary
- Show active filters as dismissible chips/tags
- "Clear all filters" button when any filter is active
- Filter count badge on the filter panel toggle (mobile)

### 5. Mobile Filter Drawer (optional but recommended)
- On mobile: filters collapse behind a "Filter" button
- On desktop: filters shown as a sidebar or top bar

## Color Palette

- Primary: `#d97757`
- Secondary: `#6a9bcc`
- Background: `var(--background)`
- Foreground: `var(--foreground)`
- Border: `var(--border)`
- Slate Light: `var(--slate-light)`

## Variation Guidelines

Each variant must choose a clearly different layout paradigm:

- **Sidebar Layout** — vertical filter panel on left (240px), results grid fills right
- **Top-bar Layout** — horizontal filter row above results, no sidebar
- **Command Palette Style** — search-first, filters as dropdown menus, results as compact list
- **Magazine Layout** — featured hooks large top banner, rest in asymmetric grid

## Performance Expectations

All filtering and search must happen **client-side** (no API call).
React state: `hooks` array loaded once, derived `filteredHooks` computed on each render.
No useEffect for filtering — compute synchronously from filter state.

## Page Structure

```
<BrowsePage>
  ├── PageHeader (title + description + install count stat)
  ├── SearchBar
  ├── FilterArea (sidebar or top-bar depending on variant)
  │   ├── CategoryFilter
  │   ├── LanguageFilter
  │   ├── HookTypeFilter
  │   └── SortControl
  ├── ActiveFiltersBar (chips for active filters)
  ├── ResultsGrid
  │   ├── ResultCount
  │   └── HookCard × N
  └── EmptyState (shown when filteredHooks.length === 0)
</BrowsePage>
```
