# App Specification: DailyMind — AI-Powered Personal Journal

## Project Overview

Build a fully-featured **desktop journal application** powered by Claude AI.
DailyMind combines rich-text daily journaling with intelligent AI features:
mood analysis, automatic tagging, reflection prompts, and habit tracking —
all stored locally with no cloud dependency.

Target users: developers, writers, and knowledge workers who want a private,
AI-enhanced personal journal on their desktop.

---

## Technology Stack

### Runtime & Language
- **Python 3.12+** (primary language — no JavaScript)
- **PyQt6** — desktop GUI framework
- **SQLite + SQLAlchemy** — local persistent storage

### AI Integration
- **Anthropic SDK** (`anthropic`) — Claude API for all AI features
- Default model: `claude-haiku-4-5-20251001` (fast, low-cost for real-time suggestions)
- Premium mode: `claude-sonnet-4-6` (deeper analysis)
- API key: read from `~/.dailymind/config.json` or `ANTHROPIC_API_KEY` env var

### Libraries
- `markdown2` — render Markdown in preview pane
- `PyQtChart` — mood trend charts
- `reportlab` — PDF export
- `cryptography` — optional local encryption of journal entries
- `platformdirs` — cross-platform data directory resolution

### Data Storage
- All data stored in `~/.dailymind/journal.db` (SQLite)
- Attachments stored in `~/.dailymind/attachments/`
- Config in `~/.dailymind/config.json`
- Exports in `~/Documents/DailyMind/` (or user-configured path)

### Packaging
- `PyInstaller` for bundling into standalone executable
- Supports: Windows 10+, macOS 12+, Ubuntu 20.04+

---

## Core Features

### 1. Journal Editor
- Split-pane: Markdown editor (left) + live preview (right)
- Full Markdown support: headings, bold, italic, lists, code blocks, tables
- Image insertion via drag-and-drop (stored in local attachments folder)
- Auto-save every 60 seconds + on window close
- Word count and read-time estimate in status bar
- Focus mode: hide sidebar, expand editor to full width

### 2. AI Reflection & Prompts
- "Reflect with AI" button: Claude analyzes today's entry and asks 2-3 deep questions
- Daily writing prompt (generated on app open, cached locally)
- "Expand this thought" — highlight text, Claude elaborates in a side panel
- "Summarize week" — Claude summarizes the last 7 entries into a weekly digest
- All AI requests are non-blocking (background thread + progress indicator)

### 3. Mood Tracking
- Mood selector at top of each entry: 5 emoji levels (😞 😐 🙂 😊 🤩)
- Optional text note on mood ("bad sleep", "great meeting")
- AI mood inference: if mood not set, Claude infers from entry content (with user confirmation)
- Weekly mood chart (bar chart via PyQtChart)
- Monthly mood heatmap calendar view

### 4. Automatic Tagging & Search
- Claude auto-generates tags from entry content (on save or on demand)
- Manual tag editing (comma-separated in tag field)
- Tag cloud view in sidebar
- Full-text search across all entries (SQLite FTS5)
- Filter by: date range, tags, mood, has-images
- Search highlights matching terms in results

### 5. Habit Tracker
- Define custom habits (e.g., "exercise", "meditation", "reading")
- Check off habits at bottom of daily entry
- Streak counter per habit
- Weekly habit completion grid (calendar heatmap)
- Claude habit insight: "You've exercised 3x this week — what helped?"

### 6. Entry Organization
- Calendar view: click any date to jump to that entry
- Entries grouped by: Today / This Week / This Month / Archive
- Pinned entries (mark as favorites)
- Templates: Morning Pages, Gratitude, Goal Review (user-editable)
- Entry versioning: undo history preserved in DB (last 10 versions)

### 7. Privacy & Security
- Local-only by default (no cloud sync)
- Optional AES-256 encryption for entire DB (password set on first run)
- AI features can be disabled globally (works fully offline without API key)
- API key stored in OS keychain (keyring library) — never in plaintext

### 8. Export
- Export single entry: Markdown, PDF, HTML
- Export date range: ZIP of Markdown files
- Export all: full JSON backup
- Import: JSON backup restore, Day One JSON format

### 9. Settings & Customization
- Theme: Light / Dark / Solarized / Nord (QSS stylesheets)
- Font family and size for editor
- Editor line spacing
- Autosave interval
- AI model selection (Haiku / Sonnet)
- AI feature toggles (prompts / mood inference / auto-tagging)
- Backup schedule (daily/weekly auto-export to user folder)

---

## Database Schema

### `entries`
```sql
id          TEXT PRIMARY KEY  -- UUID
date        TEXT NOT NULL     -- YYYY-MM-DD (one entry per day)
title       TEXT              -- auto-generated or user-set
body        TEXT NOT NULL     -- raw Markdown content
mood        INTEGER           -- 1-5 (NULL if not set)
mood_note   TEXT
tags        TEXT              -- JSON array of strings
word_count  INTEGER
created_at  TEXT              -- ISO 8601
updated_at  TEXT
is_pinned   INTEGER DEFAULT 0
is_deleted  INTEGER DEFAULT 0
```

### `entry_versions`
```sql
id          TEXT PRIMARY KEY
entry_id    TEXT REFERENCES entries(id)
body        TEXT
saved_at    TEXT
version_num INTEGER
```

### `habits`
```sql
id          TEXT PRIMARY KEY
name        TEXT NOT NULL
icon        TEXT              -- emoji
color       TEXT              -- hex color
sort_order  INTEGER
is_active   INTEGER DEFAULT 1
created_at  TEXT
```

### `habit_logs`
```sql
id          TEXT PRIMARY KEY
habit_id    TEXT REFERENCES habits(id)
date        TEXT              -- YYYY-MM-DD
completed   INTEGER DEFAULT 0
note        TEXT
```

### `ai_insights`
```sql
id          TEXT PRIMARY KEY
entry_id    TEXT REFERENCES entries(id)
type        TEXT              -- 'reflection' | 'summary' | 'tags' | 'mood_inference'
prompt      TEXT
response    TEXT
model       TEXT
created_at  TEXT
tokens_used INTEGER
```

### `templates`
```sql
id          TEXT PRIMARY KEY
name        TEXT
body        TEXT              -- Markdown template
is_default  INTEGER DEFAULT 0
created_at  TEXT
```

---

## UI Layout

### Main Window (1200×800 default, resizable)
```
┌─────────────────────────────────────────────────────────┐
│  [☀ DailyMind]    [Today] [Calendar] [Habits] [Search]  │
├──────────────┬──────────────────────────────────────────┤
│  SIDEBAR     │  EDITOR AREA                             │
│              │                                          │
│  📅 Today    │  📝 Monday, May 26, 2025                │
│  📅 Yesterday│  Mood: 😊  Tags: [work] [coding] [+]    │
│  ─────────── │  ─────────────────────────────────────── │
│  This Week   │  [Markdown Editor]   [Preview]           │
│  • Mon 26    │                                          │
│  • Sun 25    │  Today was a productive...               │
│  • Sat 24    │                                          │
│  ─────────── │                                          │
│  Tag Cloud   │                                          │
│  #work #ai   │  ─────────────────────────────────────── │
│  #reading    │  Habits: ✅ Exercise  ☐ Meditation       │
│              │  ─────────────────────────────────────── │
│  [⚙ Settings]│  [💾 Save] [✨ Reflect with AI] [📤 Export]│
└──────────────┴──────────────────────────────────────────┘
```

### AI Panel (slide-in from right, 400px)
- Triggered by "Reflect with AI" or "Expand" buttons
- Shows AI response as streaming text
- Copy / Insert into entry buttons
- Dismiss button

### Calendar View (full window overlay)
- Monthly grid, color-coded by mood
- Click date to open that entry
- Habit completion dots below each date

---

## Key Interactions

### Daily Writing Flow
1. App opens → show today's entry (create if none)
2. Optional: AI generates writing prompt (shown at top, dismissable)
3. User writes in Markdown editor, preview updates live
4. Select mood from emoji bar
5. Check off completed habits
6. Auto-save triggers every 60 seconds
7. Optional: click "Reflect with AI" → AI asks follow-up questions
8. Close app → final auto-save + encrypt if enabled

### AI Reflection Flow
1. User clicks "Reflect with AI"
2. Entry content sent to Claude (Haiku model)
3. Spinner shows in AI panel while streaming
4. Claude responds with 2-3 reflection questions
5. User reads, optionally types answers back into entry
6. Interaction stored in `ai_insights` table

### Tag Auto-Generation Flow
1. On entry save: background task calls Claude with entry body
2. Claude returns 3-5 suggested tags (JSON)
3. Notification badge on Tags field
4. User reviews and accepts/edits tags
5. Tags saved to entry

---

## Implementation Steps

### Step 1: Project Foundation
- Set up Python virtual environment + `requirements.txt`
- Initialize SQLite DB with SQLAlchemy migrations
- Create main PyQt6 window shell with menu bar
- Implement config file (JSON) read/write
- Set up logging to `~/.dailymind/logs/`

### Step 2: Core Editor
- Build split-pane editor (QSplitter)
- Integrate markdown2 for live preview (QWebEngineView or QTextBrowser)
- Implement save/load entry to/from SQLite
- Add auto-save timer
- Word count status bar

### Step 3: Sidebar & Navigation
- Entry list panel (grouped by week)
- Calendar date picker integration
- Tag cloud widget
- Search bar with FTS5 SQLite search

### Step 4: AI Features
- Anthropic SDK integration (background QThread)
- "Reflect with AI" button + streaming response panel
- Daily writing prompt generation (on startup)
- Auto-tagging on save

### Step 5: Mood & Habit Tracking
- Mood emoji selector widget
- Habit checklist widget (bottom of editor)
- PyQtChart mood trend chart
- Habit streak calculation

### Step 6: Export & Privacy
- Markdown / PDF / JSON export (reportlab for PDF)
- Optional DB encryption (cryptography library)
- API key secure storage (keyring)

### Step 7: Polish
- 4 QSS themes (Light / Dark / Solarized / Nord)
- Keyboard shortcuts (Cmd+S save, Cmd+K search, etc.)
- Onboarding wizard (first run)
- Error handling & user-facing messages

---

## File & Directory Conventions

```
dailymind/
├── main.py                    -- entry point
├── requirements.txt
├── app/
│   ├── db/
│   │   ├── models.py          -- SQLAlchemy ORM models
│   │   ├── migrations.py      -- schema init + migrations
│   │   └── queries.py         -- reusable query functions
│   ├── ai/
│   │   ├── client.py          -- Anthropic SDK wrapper
│   │   ├── prompts.py         -- system prompts for each AI feature
│   │   └── worker.py          -- QThread background AI worker
│   ├── ui/
│   │   ├── main_window.py     -- QMainWindow
│   │   ├── editor_pane.py     -- Markdown editor widget
│   │   ├── sidebar.py         -- entry list + tag cloud
│   │   ├── ai_panel.py        -- slide-in AI response panel
│   │   ├── calendar_view.py   -- monthly calendar overlay
│   │   ├── habit_widget.py    -- habit checklist + streak
│   │   └── settings_dialog.py -- settings modal
│   ├── models/                -- dataclasses for Entry, Habit, etc.
│   ├── services/              -- business logic (EntryService, HabitService)
│   ├── utils/
│   │   ├── export.py          -- PDF/Markdown/JSON export
│   │   ├── encryption.py      -- AES-256 DB encryption
│   │   └── config.py          -- config read/write
│   └── themes/                -- QSS stylesheets
│       ├── light.qss
│       ├── dark.qss
│       ├── solarized.qss
│       └── nord.qss
└── tests/
    ├── test_db.py
    ├── test_ai_client.py
    └── test_export.py
```

---

## Success Criteria

### Functionality
- Daily entries save and load reliably
- AI reflection responds within 3 seconds (Haiku model)
- Search returns results within 500ms for 1000+ entries
- Export produces valid PDF and Markdown files
- Habit streaks calculated correctly

### User Experience
- App launches in under 2 seconds
- Markdown preview renders in real-time without lag
- AI panel streams response word-by-word (no waiting for full response)
- All keyboard shortcuts documented and working
- First-run onboarding completable in under 2 minutes

### Technical Quality
- All AI calls wrapped in try/except with user-facing error messages
- API key never logged or written to plaintext files
- No hardcoded paths (use `platformdirs.user_data_dir`)
- All DB operations use parameterized queries (no SQL injection)
- Unit tests cover: DB models, AI prompt templates, export functions
