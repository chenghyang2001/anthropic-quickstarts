# FAQ Section Specification

## Overview

FAQ (Frequently Asked Questions) section for the HookHub landing page.
Each variant displays the same Q&A content in a different interactive layout.

## Content (fixed — same across all variants)

### 8 Questions to include:

1. **What is a Claude Code hook?**
   A: Hooks are scripts that run automatically at Claude Code lifecycle events (PreToolUse, PostToolUse, Stop, etc.). They let you add custom logic like security checks, logging, notifications, and automated testing to every AI session.

2. **Is HookHub free to use?**
   A: Yes, completely free. HookHub is an open-source community platform. All hooks are free to browse, install, and use under their respective licenses (mostly MIT).

3. **How do I install a hook?**
   A: Run `npx hookhub install <hook-id>` in your terminal. The CLI automatically adds the hook configuration to your `~/.claude/settings.json` file. No manual editing required.

4. **Are hooks safe to install?**
   A: Each hook's source code is publicly visible on GitHub. We display the author, stars, and community reviews. For production use, always review the source code before installing — especially hooks with `PreToolUse` access.

5. **Can I publish my own hooks?**
   A: Yes! Submit a PR to the HookHub registry with your hook's GitHub URL and metadata. Community reviews happen within 48 hours.

6. **Which hook types are supported?**
   A: PreToolUse, PostToolUse, Stop, Notification, SubagentStart, SubagentStop, and SubagentStream — all 8 Claude Code lifecycle events.

7. **Do hooks work with Claude Code sub-agents?**
   A: Yes. Hooks with `SubagentStart` / `SubagentStop` / `SubagentStream` types fire for each sub-agent invocation, giving you full observability into multi-agent pipelines.

8. **How do I uninstall a hook?**
   A: Run `npx hookhub uninstall <hook-id>` or manually remove the entry from `~/.claude/settings.json`.

## File Conventions

- Filename: `SectionFaq<Variant>.tsx`
- Location: `src/components/sections/`
- Must be `'use client'`
- No props (all Q&A hardcoded)
- Export: `export default function SectionFaq<Variant>()`
- No external imports (Tailwind + React only)
- Interactive: clicking a question toggles its answer (useState)

## Required Elements

1. Section label: "FAQ"
2. H2 headline (each variant chooses its own wording)
3. All 8 Q&A pairs (must all be present)
4. Toggle interaction (open/close each answer on click)
5. Subtle visual indicator showing open/closed state (arrow, plus, etc.)

## Color Palette

- Primary: `#d97757`
- Secondary: `#6a9bcc`
- Background: `var(--background)`
- Foreground: `var(--foreground)`
- Border: `var(--border)`
- Slate Light: `var(--slate-light)`

## Variation Guidelines

Each variant must use a clearly different layout/interaction pattern:
- **Accordion** — classic single-open accordion list
- **Two-column grid** — 4+4 split, all open by default, click to collapse
- **Minimal** — borderless, open-by-default, inline answers with fade animation
- **Card grid** — each Q&A as its own card that expands on hover/click
- Animations: open/close must have smooth transition (max-height or opacity)
