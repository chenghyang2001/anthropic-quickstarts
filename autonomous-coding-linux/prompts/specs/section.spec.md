# Section Component Specification

## Overview

Section components are content blocks placed **below the Hero** on the HookHub landing page.
Each section communicates a different value proposition of the platform.

## Content Context (HookHub)

HookHub is a community platform for discovering, sharing, and installing Claude Code hooks.
- Hooks are automation scripts that run at lifecycle events (PRE_TOOL_USE, POST_TOOL_USE, STOP, etc.)
- Community-driven: anyone can submit hooks
- Target users: developers using Claude Code

## Structure Requirements

Every section must include:
1. **Section label** — small uppercase category tag (e.g. "WHY HOOKHUB", "TESTIMONIALS")
2. **Headline** — bold H2, 1–2 lines
3. **Supporting text** — 1–2 sentences description
4. **Main content area** — the unique visual (grid, cards, quotes, timeline, etc.)
5. **Optional CTA** — link or button at bottom

## Color Palette

| Token | Value | Use |
|-------|-------|-----|
| Primary | `#d97757` | Accents, highlights |
| Secondary | `#6a9bcc` | Secondary accents |
| Tertiary | `#788c5d` | Tertiary accents |
| Background | `var(--background)` | Section bg |
| Foreground | `var(--foreground)` | Text |
| Slate Light | `var(--slate-light)` | Muted text |
| Border | `var(--border)` | Dividers |

## Layout Guidelines

- Max width: `max-w-6xl mx-auto px-6 lg:px-8`
- Section padding: `py-20 lg:py-28`
- Responsive: mobile-first, use `sm:` / `md:` / `lg:` breakpoints
- Use CSS Grid or Flexbox for content layout

## Animation Classes Available

`animate-fade-in`, `animate-slide-up`, `animate-float`, `animate-pulse-slow`, `animate-ping-slow`

## File Conventions

- Filename: `Section<Name>.tsx`
- Location: `src/components/sections/`
- Must be `'use client'` directive
- No external imports (Tailwind + React only)
- Export: `export default function Section<Name>()`

## Variation Guidelines

When creating new Section variations:
1. **Unique content layout** — each section should look clearly different
2. **Consistent branding** — use the color palette tokens
3. **Real content** — use actual HookHub-relevant text (not lorem ipsum)
4. **Self-contained** — no props required, all data hardcoded inside component
