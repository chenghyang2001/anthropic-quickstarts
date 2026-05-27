# Autonomous Coding Portfolio — 12 AI-Powered Apps Overview

This document describes all 12 applications built using the `autonomous-coding-linux` pipeline.
Each app is a standalone, locally-runnable Python project that integrates **Claude AI** via the
Anthropic API. All apps store data in **SQLite** and run with zero cloud dependencies beyond
the Claude API key.

---

## App Classification

| Category | Apps |
|----------|------|
| 🖥️ Developer Tools | CodeReviewBot, GitInsight |
| 📡 Monitoring & Observability | APIWatcher, PipelineGuard |
| 🧠 Desktop AI Productivity | DailyMind, DocTranslator, ExpenseAI, FileSense, MeetingMind, StudyBuddy |
| 📊 Health & Knowledge | HealthLog, PodcastBrain |

---

## 1. APIWatcher — REST API Endpoint Monitor

### Purpose

Continuously checks REST API endpoints for availability, correctness, and performance. Records results in SQLite, visualises uptime and response-time trends in a Streamlit dashboard, and uses Claude to generate plain-English incident reports with root-cause suggestions when anomalies are detected.

### Target Users

Development teams monitoring dev / staging / production API endpoints from a single dashboard.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.11+ |
| Backend API | FastAPI (port 8000) |
| Scheduler | APScheduler 3.x (AsyncIOScheduler) |
| HTTP client | httpx (async) |
| Database | SQLite via SQLAlchemy 2.x |
| Dashboard | Streamlit (port 8501) |
| Charts | Plotly |
| AI | Anthropic Claude — incident report generation |
| Alert channels | Email (smtplib), Slack webhook, plyer desktop notification |

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  APScheduler (cron jobs)                                     │
│    → httpx async checks each endpoint                        │
│    → writes Check record to SQLite                           │
│    → incident.py: 3 fails → open Incident, 2 pass → close   │
│    → claude_reporter.py: Claude generates incident report    │
│    → alerter.py: email / Slack / desktop notification        │
└──────────────────┬──────────────────────────────────────────┘
                   │ REST API (FastAPI :8000)
┌──────────────────▼──────────────────────────────────────────┐
│  Streamlit Dashboard (:8501)                                 │
│    Status grid (green/yellow/red cards per endpoint)         │
│    Response-time Plotly chart with SLA threshold line        │
│    Incident log with Claude report expander                  │
│    Multi-environment tabs (dev / staging / prod)             │
│    Endpoint detail sidebar (SLA %, check history)            │
└─────────────────────────────────────────────────────────────┘
```

### Key Data Models

- **Endpoint**: name, URL, method, headers, interval, environment, SLA threshold
- **Check**: endpoint_id, timestamp, status_code, response_ms, error_message
- **Incident**: endpoint_id, opened_at, closed_at, check_count, claude_report
- **AlertConfig**: endpoint_id, channel, address, enabled

---

## 2. CodeReviewBot — AI-Powered Code Review Tool

### Purpose

AI-powered code review combining a **Click CLI** with a **FastAPI + Streamlit** dashboard. Developers run `codereview scan ./src` locally or point it at a GitHub PR; Claude returns structured findings (critical / warning / suggestion) with file-and-line context. All findings persist in SQLite so teams can track quality trends over time.

### Target Users

Individual developers and small engineering teams wanting automated pre-merge code review without sending code to a third-party SaaS.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.11+ |
| CLI | Click 8 + Rich (color terminal output, progress bars) |
| Backend API | FastAPI 0.111 (port 8000) |
| Dashboard | Streamlit 1.35 (port 8501) |
| Database | SQLite via SQLAlchemy 2.0 + Alembic migrations |
| AI | Anthropic Claude — code analysis, severity classification |
| GitHub Integration | PyGithub 2.3 (PR diff fetch + comment posting) |
| Report templates | Jinja2 |

### Architecture

```
CLI: codereview scan ./src
  → ReviewEngine: chunk_code() splits file into 200-line chunks (20-line overlap)
  → Claude API: each chunk → structured JSON findings
  → Pydantic validation (never blindly trust AI output)
  → SQLite: Review + Finding records persisted
  → Rich: color-coded table (🔴 critical / 🟡 warning / 💡 suggestion)
  → sys.exit(1) if any critical finding (CI gate usage)

CLI: codereview pr --repo owner/repo --pr 123
  → PyGithub fetches PR diff
  → same ReviewEngine pipeline
  → posts findings as PR comment via GitHub API

FastAPI (:8000) ←→ SQLite
  ↕ REST endpoints for reviews, findings, stats

Streamlit (:8501)
  Dashboard tab: review history table, findings trend Plotly chart
  Files tab: per-file findings breakdown
  Team tab: team_stats aggregation
```

### Key Data Models

- **Review**: id, repo_path, commit_sha, created_at, total_findings, critical_count
- **Finding**: review_id, file_path, line_number, severity, message, suggestion
- **RepoConfig**: repo_path, config JSON (excluded paths, custom rules)
- **TeamStats**: reviewer, date, findings_resolved, avg_severity

---

## 3. DailyMind — AI-Powered Private Journal

### Purpose

Fully-featured desktop journal with Claude AI integration: mood analysis, automatic tagging, reflection prompts, and habit tracking — all stored locally in SQLite with no cloud dependency.

### Target Users

Developers, writers, and knowledge workers who want a private, AI-enhanced journaling experience without data leaving their machine.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.12+ |
| GUI | PyQt6 |
| Database | SQLite via SQLAlchemy 2.0 |
| AI | Anthropic Claude — mood inference, auto-tagging, reflective prompts |
| Editor | QTextEdit with Markdown live-preview split pane |
| Charts | pyqtgraph (habit heatmap, mood trend) |
| Encryption | Optional AES-256 encrypted SQLite (sqlcipher) |

### Architecture

```
PyQt6 Main Window
  ├── Left: Calendar + Entry List
  ├── Center: Split-pane Markdown editor (QTextEdit / QTextBrowser)
  ├── Right: AI panel (mood badge, tags, prompt suggestions)
  └── Bottom: Habit tracker strip (7-day streak view)

On Save:
  → Claude: infers mood (1-10), extracts 3-5 tags, suggests tomorrow's prompt
  → SQLite: journal_entries + auto_tags + habit_logs
  → Local encryption (optional): AES-256 key from user password

Habit Tracker:
  → Weekly heatmap grid (pyqtgraph)
  → Streak counter per habit
  → Claude weekly insight: correlations between mood and habit completion
```

### Key Data Models

- **JournalEntry**: date, title, body_md, mood_score, word_count, created_at
- **Tag**: name, source (auto/manual), entry_id
- **Habit**: name, color, target_days_per_week
- **HabitLog**: habit_id, date, completed

---

## 4. DocTranslator — AI Batch Document Translator

### Purpose

Desktop batch document translation app using Claude AI. Users drag in Word docs, PDFs, and text files, select languages, and receive translated output with original formatting preserved. A terminology glossary ensures consistent translation of technical terms; a translation memory caches previous sentence-level translations to reduce cost and improve consistency.

### Target Users

Technical writers, researchers, and enterprises needing high-volume document translation with domain-specific terminology control.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.12+ |
| GUI | PyQt6 6.7 |
| Database | SQLite via SQLAlchemy 2.0 |
| AI | Anthropic Claude — streaming translation, quality scoring |
| Document parsing | python-docx, pypdf2, chardet |
| Export | python-docx (DOCX), fpdf2 (PDF) |
| Translation memory | SHA-256 exact match + fuzzy 85% match |

### Architecture

```
PyQt6 Main Window
  ├── File list panel (drag-and-drop DOCX/PDF/TXT/MD)
  ├── Side-by-side view (original left, streaming translation right)
  ├── Terminology glossary manager
  └── TM (translation memory) statistics panel

Translation pipeline per file:
  1. Parse → sentence segmentation
  2. TM lookup: SHA-256 exact match → skip Claude (free)
              fuzzy 85% match → pre-fill (user confirms)
  3. Claude streaming API: sentence-by-sentence with glossary injected
  4. Quality review: Claude second-pass scores 0.0-1.0; <0.75 → orange highlight
  5. Export: DOCX (style-preserved), PDF, TXT

SQLite tables: translation_jobs, documents, segments, glossary_terms, translation_memory
```

---

## 5. ExpenseAI — AI-Powered Personal Finance Tracker

### Purpose

Desktop personal finance application combining manual expense tracking with AI-powered receipt processing and spending analysis. Users enter expenses manually, import bank CSV statements, or photograph receipts for Claude to extract and categorize automatically. Enforces per-category monthly budgets with alerts.

### Target Users

Individuals wanting a privacy-first personal finance tool with AI categorization and insights — no bank API keys required.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.12+ |
| GUI | PyQt6 |
| Database | SQLite via SQLAlchemy 2.0 |
| AI | Anthropic Claude — receipt OCR (Vision API), categorization, monthly insight |
| Charts | matplotlib (embedded FigureCanvas) |
| Export | reportlab (PDF), openpyxl (Excel pivot), CSV |
| Notifications | plyer (OS-native desktop alerts at 80%/100% budget) |

### Architecture

```
PyQt6 Main Window
  ├── Quick-entry dialog (Ctrl+N): amount, merchant, date, category
  ├── Expense list table (sortable, filterable by date/category)
  ├── Budget panel: progress bars (green/yellow/red) per category
  ├── Reports tab: pie chart, 6-month trend, merchant analysis
  └── Claude insight panel: 400-600 word AI spending summary

Receipt → Claude Vision API → JSON extraction → editable dialog → save
CSV import wizard → column mapping → duplicate detection → batch save
AI categorization: cached after 3 same-merchant occurrences; batch re-categorize

SQLite tables: expenses, categories, budgets, monthly_summaries, csv_import_profiles
```

---

## 6. FileSense — Privacy-First Local File Search & Organizer

### Purpose

Privacy-first local file search and organizer. A background indexer daemon watches configured folders, extracts text, and stores semantic embeddings in ChromaDB. A Tkinter overlay (Ctrl+Space) lets users search in natural language; Claude re-ranks results and can suggest folder reorganization. Everything runs locally — no file content ever leaves the machine.

### Target Users

Knowledge workers and developers who manage large local file collections and want instant semantic search without cloud upload.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.11+ |
| GUI | Tkinter (Ctrl+Space spotlight overlay) |
| Embedding model | all-MiniLM-L6-v2 (384-dim, runs on CPU) |
| Vector store | ChromaDB (ANN semantic search) |
| Database | SQLite (file metadata, tags, duplicate hashes) |
| File watching | watchdog |
| AI | Anthropic Claude — result re-ranking, folder reorganization suggestions |
| PDF parsing | pypdf2; DOCX: python-docx |

### Architecture

```
Background Daemon (watchdog):
  file create/modify/delete → extract text → embed (MiniLM on CPU)
  → ChromaDB: store 384-dim vector + metadata
  → SQLite: indexed_files, tags, SHA-256 hash (exact duplicate detection)
  throttle: 5 files/sec; skip binary/node_modules/.git/files>50MB

Ctrl+Space → Tkinter overlay (<80ms open):
  user types query → embed real-time → ChromaDB ANN top-50
  → Claude re-ranks top-50 → top-10 + explanation
  → file cards: icon / name / folder / date / excerpt
  → keyboard navigation (↑↓ Enter Esc)

Smart Folders:
  Claude receives filenames + top keywords (NOT full content)
  → suggests subfolder names + file assignments as JSON
  → user approves → atomic moves with undo stack

Privacy guarantee:
  Embedding: 100% local CPU, no cloud
  Claude: receives only snippets (max 2000 tokens), never full files
  Pure local mode: disable Claude entirely
```

---

## 7. GitInsight — Git Repository Health & Activity Dashboard

### Purpose

Streamlit web app that analyzes any local Git repository and produces a comprehensive health and activity dashboard. Reads commit history using GitPython, aggregates metrics with pandas, visualises with Plotly, and uses Claude to synthesize findings into an actionable health report. All results are cached in SQLite for instant repeat views.

### Target Users

Developers and engineering managers wanting deep repository insight: high-churn risk files, single-point-of-failure contributors, forgotten branches, and commit quality trends.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.11+ |
| Dashboard | Streamlit (port 8501) |
| Git parsing | GitPython |
| Data processing | pandas 2.2 |
| Charts | Plotly Express |
| Database | SQLite (analysis cache) |
| AI | Anthropic Claude — health report synthesis |

### Architecture

```
Streamlit UI
  ├── Repo picker: local path or recent repos list
  ├── Analysis tabs:
  │     Overview: commit frequency, contributor Lorenz curve
  │     Churn: files changed most often (risk heatmap)
  │     Contributors: bus factor score, review coverage
  │     Branches: age, divergence from main, stale detection
  │     Commit quality: message length trends, FTS search
  └── Claude Health Report: synthesized 500-word summary

GitPython → commit iteration → pandas aggregation → Plotly charts
SQLite cache: repo_path + commit_sha → cache_timestamp
  invalidate on new commits, serve instantly on repeat visits
```

---

## 8. HealthLog — Personal Health Tracker

### Purpose

Personal health tracker running entirely locally. Users log meals, exercise, sleep, weight, mood, and water intake through a **Streamlit multi-page web UI** (port 8501) or a quick-entry **Click CLI** (`healthlog` command). Claude generates weekly AI health reports detecting patterns such as "sleep under 7 hours correlates with lower mood scores."

### Target Users

Individuals wanting a private, local health journal with AI-generated correlational insights — no wearable or third-party account required.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.11+ |
| Web UI | Streamlit 1.35 (multi-page, port 8501) |
| CLI | Click 8 (`healthlog` command) |
| Database | SQLite via SQLAlchemy 2.0 + Alembic |
| AI | Anthropic Claude — weekly pattern analysis |
| Charts | pandas 2.2 + Plotly 5.22 |
| Notifications | plyer 2.1 (daily reminder) |
| Export | fpdf2 (PDF report) |

### Architecture

```
Two entry points:
  healthlog (Click CLI): quick log from terminal
    → healthlog log meal "chicken salad" --calories 450
    → healthlog log sleep 7.5 --quality good
    → healthlog report --week

  Streamlit (:8501):
    Page 1 – Log (form per category)
    Page 2 – Dashboard (charts: weight trend, sleep histogram, mood line)
    Page 3 – Reports (Claude weekly insight, PDF export)
    Page 4 – Settings (goals, notification time)

SQLite tables: meals, exercise_sessions, sleep_logs, weight_logs, mood_logs, water_logs
Weekly Claude report: aggregated stats (not raw records) → pattern detection → Markdown summary
```

---

## 9. MeetingMind — On-Device Meeting Recorder & Summarizer

### Purpose

Desktop application that records, transcribes, and summarizes meetings entirely on-device. Audio is transcribed using **OpenAI Whisper running locally**, then Claude generates structured summaries with agenda items, decisions, and action items. No audio or transcript ever leaves the user's machine.

### Target Users

Remote workers, product managers, and consultants who need automatic meeting documentation without trusting audio to cloud services.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.12+ |
| GUI | PyQt6 6.7 |
| Audio | PyAudio (recording), ffmpeg (format conversion) |
| Transcription | OpenAI Whisper (local, tiny/base/small/medium models) |
| Database | SQLite via SQLAlchemy 2.0 |
| AI | Anthropic Claude — structured summary, action item extraction |
| Export | python-docx, fpdf2, Markdown, CSV |
| Search | SQLite FTS5 (full-text search across all transcripts) |

### Architecture

```
PyQt6 Main Window
  ├── Record panel: Start/Stop/Pause, VU meter, device selector
  ├── File import: drag-and-drop WAV/MP3/M4A/MP4/MKV/WebM → ffmpeg
  ├── Transcript panel: word-level timestamps, clickable navigation
  ├── Summary panel: purpose, agenda, decisions, action items (checkboxes)
  ├── Speaker diarization: energy+pause analysis → Speaker 1/2/3 labels
  └── Sidebar search: FTS5 across all meetings, date/participant filters

Whisper pipeline (QThread background):
  audio → Whisper → word-level transcript → display

Claude summarization:
  full transcript + metadata → structured JSON
  → action_items table (owner, due_date, completed)

Export: DOCX (checkboxes), PDF (fpdf2), Markdown, CSV (action items only)
```

---

## 10. PipelineGuard — Data Pipeline Monitoring Platform

### Purpose

Data pipeline monitoring and observability platform running locally. The **FastAPI backend** (port 8000) handles pipeline CRUD and execution. **APScheduler** runs pipelines on cron schedules. After each run, Claude analyzes row count trends, null rate changes, and execution time baselines, then generates plain-English alerts and fix suggestions stored in the database.

### Target Users

Data engineers and analysts managing local ETL pipelines who want automated anomaly detection without cloud observability tooling.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.12+ |
| Backend API | FastAPI 0.111 (port 8000) |
| Scheduler | APScheduler 3.10 (cron-based) |
| Dashboard | Streamlit (port 8501) |
| Database | SQLite via SQLAlchemy 2.0 |
| Data processing | pandas 2.2 |
| HTTP client | httpx (async source fetching) |
| AI | Anthropic Claude — anomaly analysis, fix suggestions |

### Architecture

```
FastAPI (:8000)
  /pipelines CRUD → SQLite
  /pipelines/{id}/run → ExecutionEngine → pandas transform → DB
  /pipelines/{id}/executions → run history + Claude analysis

APScheduler:
  cron job per pipeline → ExecutionEngine
  post-run: Claude receives row_count, null_rates, exec_time_ms + 30-run baseline
  → generates alert_message + fix_suggestion → stores in pipeline_runs

Execution Engine:
  Sources: csv_file, json_file, rest_api, sqlite_table
  Transforms: filter (pandas query), rename, cast, drop_columns
  Data quality checks: null_rate, min/max, uniqueness, custom rules

Streamlit (:8501):
  Pipeline list with run status badges
  Execution timeline chart (Plotly)
  Claude alert panel (last N anomalies with fix suggestions)
  Data quality sparklines per column
```

---

## 11. PodcastBrain — Podcast & YouTube Knowledge Extraction

### Purpose

Streamlit web app converting podcast episodes and YouTube videos into structured knowledge assets. Downloads audio with **yt-dlp**, transcribes locally using **OpenAI Whisper**, then uses Claude to generate chapters, summaries, key quotes with timestamps, action items, and speaker identification. Interactive Q&A is grounded exclusively in the episode transcript.

### Target Users

Knowledge workers, researchers, and learners who want to extract maximum value from audio content without manual note-taking.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.11+ |
| Dashboard | Streamlit (port 8501) |
| Audio download | yt-dlp (YouTube + direct links) |
| Transcription | OpenAI Whisper (local, no audio leaves machine) |
| Database | SQLite + FTS5 (full-text search across all transcripts) |
| AI | Anthropic Claude — chapters, summary, quotes, Q&A |
| Export | Markdown, PDF (reportlab), SRT subtitles, plain text |

### Architecture

```
Streamlit (:8501)
  ├── Add episode: URL (YouTube/MP3/M4A) or file upload
  ├── Processing queue: yt-dlp download → Whisper transcription → Claude analysis
  ├── Episode library: search (FTS5), filter by date/duration/topics
  ├── Episode view:
  │     Chapters timeline, Full transcript with timestamps
  │     Summary, Key quotes, Action items
  │     Q&A chat (context = episode transcript, grounded answers only)
  └── Batch export panel

Privacy boundary:
  Audio: 100% local (Whisper on CPU)
  Claude: receives text transcript only, no audio
  FTS5: instant millisecond search across all episode text
```

---

## 12. StudyBuddy — AI-Powered Spaced Repetition Flashcards

### Purpose

PyQt6 desktop flashcard application combining **SM-2 spaced repetition** with Claude AI. Users import Markdown, PDF, or plain text files; Claude auto-generates Q&A flashcard pairs from the content. When a card is answered incorrectly, Claude provides contextual explanations with root cause analysis and mnemonics. Exports to **Anki-compatible .apkg** format.

### Target Users

Students, language learners, exam preppers, and developers learning new domains who want AI-assisted card creation and intelligent explanations when they struggle.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Python 3.12+ |
| GUI | PyQt6 |
| Database | SQLite via SQLAlchemy 2.0 |
| AI | Anthropic Claude — card generation, contextual explanations |
| Spaced repetition | SM-2 algorithm (custom Python implementation) |
| Anki export | genanki library (.apkg format) |
| Document parsing | pypdf2, python-docx |

### Architecture

```
PyQt6 Main Window
  ├── Deck browser: hierarchical tree, tag panel, search bar
  ├── Import wizard: Markdown/PDF/TXT → Claude generates card pairs
  │     Claude receives: full document text
  │     Returns: [{front: "Q", back: "A", tags: [...]}] JSON array
  ├── Study mode:
  │     Card display (front → flip → back)
  │     SM-2 rating buttons (1 Blackout / 2 Hard / 3 Good / 4 Easy)
  │     Rating 1 or 2 → Claude contextual explanation:
  │       - WHY the answer is correct
  │       - Root cause of common confusion
  │       - Mnemonic suggestion
  ├── Statistics: retention % per deck, due-card forecast calendar
  └── Anki export: genanki .apkg with SM-2 scheduling data preserved

SQLite tables: decks, cards, review_logs, study_sessions
SM-2 scheduler: ease_factor, interval_days, next_review_date per card
```

---

## Cross-App Patterns

All 12 apps share these engineering decisions:

| Pattern | Implementation |
|---------|---------------|
| **Data persistence** | SQLite via SQLAlchemy 2.0 (local, no cloud DB required) |
| **AI integration** | Anthropic Claude via API key from environment variable |
| **Privacy** | No raw user data sent to cloud (only text excerpts/summaries to Claude) |
| **Dependencies** | `requirements.txt` + `init.sh` setup script |
| **Schema changes** | Alembic migrations (FastAPI/Streamlit apps) or SQLAlchemy create_all (desktop apps) |
| **API key** | `ANTHROPIC_API_KEY` from `os.environ`; fallback `/tmp/api-key` for autonomous agent testing |
| **Port convention** | FastAPI = 8000, Streamlit = 8501 (where applicable) |

### UI Framework Distribution

- **PyQt6** (desktop): DailyMind, DocTranslator, ExpenseAI, MeetingMind, StudyBuddy
- **Streamlit** (web): APIWatcher, GitInsight, HealthLog, PipelineGuard, PodcastBrain
- **CLI + Web hybrid**: CodeReviewBot (Click CLI + Streamlit), HealthLog (Click CLI + Streamlit)
- **Tkinter overlay**: FileSense (Ctrl+Space spotlight)

### AI Usage Patterns

- **Structured analysis**: CodeReviewBot (code findings), GitInsight (repo health), PipelineGuard (anomaly detection)
- **Content generation**: DailyMind (prompts/tags), MeetingMind (summaries/action items), PodcastBrain (chapters/summaries)
- **Document processing**: DocTranslator (streaming translation), StudyBuddy (card generation), ExpenseAI (receipt OCR)
- **Pattern detection**: HealthLog (health correlations), APIWatcher (incident root cause), FileSense (result re-ranking)
