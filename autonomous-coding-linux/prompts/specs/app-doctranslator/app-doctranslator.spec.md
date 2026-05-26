# App Specification: DocTranslator

## Project Overview

DocTranslator is a desktop application for batch document translation using Claude as the
AI translation engine. Users drag in Word documents, PDFs, and text files, select source
and target languages, and receive translated output with original formatting preserved.
A terminology glossary ensures consistent translation of technical terms. A translation
memory caches previous sentence-level translations to reduce cost and improve consistency
on repeated content.

**Primary audience:** Technical writers, legal teams, academic researchers, and companies
that need accurate batch translation of internal documents without uploading sensitive
content to a public translation SaaS.

---

## Technology Stack

| Layer            | Technology                                          |
|------------------|-----------------------------------------------------|
| UI framework     | PyQt6 6.7                                           |
| Word documents   | python-docx 1.1                                     |
| PDF extraction   | pdfplumber 0.11                                     |
| AI translation   | Anthropic Claude (claude-sonnet-4-6, streaming)    |
| Database         | SQLite (via SQLAlchemy 2.0)                         |
| Export           | python-docx (DOCX), fpdf2 (PDF), built-in (TXT)    |
| Async execution  | QThread + asyncio bridge                            |
| Configuration    | python-dotenv + JSON config file                    |

---

## Core Features

### 1. Batch File Import
- Drag-and-drop files or folders onto the file list panel
- Supported input formats: .docx, .pdf, .txt, .md
- File list shows: filename, format icon, page count, estimated word count, status badge
- Remove files from queue with Delete key or right-click context menu
- Import folder: recursively discovers all supported files (with depth limit)
- File size limit: warn if single file > 100 pages (slow translation expected)

### 2. Language Selection
- Source language: dropdown with auto-detect option (Claude detects on first paragraph)
- Target language: 20+ supported languages including EN, ZH-TW, ZH-CN, JA, KO, FR, DE, ES, PT, AR, RU, IT, NL, PL, SV, TR, VI, TH, ID, UK
- Language pair remembered per session and saved to config
- Per-file language override: right-click file > "Set language for this file"

### 3. Translation with Streaming
- Claude translates sentence by sentence with streaming API (token-by-token display)
- Live preview in the right panel: translated text appears as Claude streams
- Progress bar per file: "Page 3 of 12 — Sentence 47 of 130"
- Pause/Resume button halts streaming mid-translation (Claude API call cancelled)
- Estimated time remaining shown in status bar based on current throughput

### 4. Side-by-Side View
- Left pane: original document text (structured by paragraphs)
- Right pane: translated text, updated in real-time as streaming progresses
- Synchronized scrolling: scrolling either pane moves the other in sync
- Click on any translated segment to edit inline (corrections stored in translation memory)
- Toggle: show/hide source text (full-width translation view)

### 5. Terminology Glossary
- Glossary manager: add term pairs (source term → required translation)
- Example: "API" → "API" (preserve), "machine learning" → "機器學習" (enforce)
- Claude system prompt includes active glossary terms before each translation call
- Terms highlighted in both source and translation panes with tooltip
- Import/export glossary as CSV; shared glossaries for team use
- Per-project glossary support: different glossaries for different document sets

### 6. Translation Memory
- Every translated sentence cached: (source_lang, target_lang, source_text) → translated_text
- Before calling Claude, check TM for exact match (100%) or fuzzy match (≥ 85%)
- TM hit rates displayed per file: "42% of sentences from memory (saved ~$0.03)"
- Manual TM editing: correct a cached translation, propagate correction to all matching segments
- TM import: import from TMX format (standard translation memory exchange)
- TM size limit: configurable max entries, LRU eviction when limit exceeded

### 7. Export
- **DOCX**: python-docx preserves original heading styles, bold/italic, lists, tables
- **PDF**: fpdf2 generates clean layout with source language and target language metadata
- **TXT**: plain translated text, paragraph breaks preserved
- Batch export: translate all queued files and save to output folder with `_translated` suffix
- Output folder configurable in Settings; defaults to source file directory
- File naming: `original_name_[target_lang].docx`

### 8. Quality Review Mode
- After translation, Claude scores each sentence (confidence: 0.0–1.0) in a second pass
- Sentences below configurable threshold (default 0.75) highlighted in orange
- Quality panel shows all flagged segments; click to jump to location in translation
- Reviewer can accept as-is, edit manually, or request Claude re-translate with context hint
- Quality score summary per document: "92% high confidence, 6% medium, 2% low"

---

## Database Schema

```sql
CREATE TABLE translation_jobs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    job_name        TEXT,
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    status          TEXT DEFAULT 'pending',  -- 'pending'|'running'|'done'|'error'|'paused'
    created_at      DATETIME NOT NULL,
    started_at      DATETIME,
    finished_at     DATETIME,
    total_files     INTEGER DEFAULT 0,
    completed_files INTEGER DEFAULT 0
);

CREATE TABLE job_files (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id          INTEGER NOT NULL REFERENCES translation_jobs(id),
    original_path   TEXT NOT NULL,
    output_path     TEXT,
    file_format     TEXT NOT NULL,          -- 'docx'|'pdf'|'txt'|'md'
    word_count      INTEGER,
    page_count      INTEGER,
    status          TEXT DEFAULT 'pending', -- 'pending'|'translating'|'done'|'error'
    error_message   TEXT,
    tm_hit_rate     REAL DEFAULT 0.0        -- fraction of sentences from TM
);

CREATE TABLE translation_memory (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    source_text     TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_hash     TEXT NOT NULL,          -- SHA-256 of normalized source_text
    quality_score   REAL DEFAULT 1.0,
    usage_count     INTEGER DEFAULT 1,
    created_at      DATETIME NOT NULL,
    updated_at      DATETIME NOT NULL,
    UNIQUE(source_hash, source_lang, target_lang)
);

CREATE TABLE glossary_terms (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    glossary_name   TEXT NOT NULL DEFAULT 'default',
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    source_term     TEXT NOT NULL,
    target_term     TEXT NOT NULL,
    case_sensitive  BOOLEAN DEFAULT 0,
    notes           TEXT,
    created_at      DATETIME NOT NULL,
    UNIQUE(glossary_name, source_lang, target_lang, source_term)
);
```

---

## Architecture / UI Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│  Menu Bar: File | Edit | Glossary | Translation Memory | Help        │
├──────────────────────────┬──────────────────────────────────────────┤
│  LEFT PANEL              │  RIGHT PANEL (Translation Workspace)     │
│                          │  ┌─────────────────┬───────────────────┐ │
│  [+Add Files] [Clear]    │  │  ORIGINAL TEXT  │  TRANSLATED TEXT  │ │
│  ┌──────────────────┐   │  │                 │                   │ │
│  │ 📄 report.docx   │   │  │  Paragraph 1    │  翻譯後的段落 1   │ │
│  │    ● Done        │   │  │                 │                   │ │
│  │ 📄 manual.pdf    │   │  │  Paragraph 2    │  翻譯中...▌       │ │
│  │    ⏳ In progress│   │  │                 │                   │ │
│  │ 📄 notes.txt     │   │  └─────────────────┴───────────────────┘ │
│  │    ○ Queued      │   │                                           │
│  └──────────────────┘   │  Progress: ▓▓▓▓▓▓░░░░ File 2/3 | P4/12  │
│                          │  [▶ Translate All] [⏸ Pause] [Export ▾]  │
│  Source: [Auto-detect ▾] │                                           │
│  Target: [ZH-TW       ▾] │  Quality flags: 3 segments need review   │
│                          │  Glossary: 12 terms active               │
│  Glossary: [default   ▾] │  TM hits: 38% (saved ~$0.02)            │
└──────────────────────────┴──────────────────────────────────────────┘
│  Status bar: Translating report.docx — sentence 47/130 — ~2m left   │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Key Interactions

### Flow 1: Translate a Single DOCX File
1. User drags `report.docx` onto the file list; file entry appears with word count
2. Selects source: English, target: Traditional Chinese (ZH-TW)
3. Clicks "Translate All"; translation of report.docx starts
4. Each paragraph sent to Claude with glossary terms prepended in system prompt
5. Translated text streams into right pane paragraph by paragraph
6. On completion, status badge turns green; user clicks Export > DOCX
7. `report_ZH-TW.docx` saved with same heading styles as original

### Flow 2: Batch Translation with Translation Memory
1. User adds 15 files from a product documentation folder
2. Translation job starts; for each sentence, TM checked first
3. Sentences with exact TM match (hash match) inserted without Claude API call
4. TM hit rate shown per file; final report: "38% from memory"
5. All 15 files exported to output folder; job logged in `translation_jobs` table

### Flow 3: Glossary Setup and Quality Review
1. User opens Glossary Manager; imports `terms.csv` with 50 term pairs
2. Starts translation; glossary terms highlighted orange in source pane
3. After translation, clicks "Quality Review"; Claude scores all sentences
4. 4 sentences flagged yellow (confidence 0.71–0.74)
5. User edits 2 manually inline; requests Claude re-translate remaining 2 with hint
6. Corrected translations saved back to TM with quality_score updated

---

## Implementation Steps

1. **Project scaffold** — `pyproject.toml`, `src/doctranslator/`, PyQt6 MainWindow skeleton
2. **File parsers** — python-docx paragraph extractor, pdfplumber text+page extractor, TXT/MD reader
3. **SQLAlchemy models** — 4 tables, Alembic migrations, TM hash index
4. **Translation engine** — Claude streaming integration, QThread worker, TM lookup/write
5. **UI layout** — QSplitter side-by-side, file list QListWidget, language dropdowns
6. **Glossary manager** — CRUD dialog, CSV import/export, system prompt injection
7. **Quality review mode** — second-pass Claude scoring, segment highlighting, review panel
8. **Export modules** — DOCX style preservation (python-docx), PDF (fpdf2), batch export loop

---

## Success Criteria

### Functional
- 10-page DOCX translated in under 90 seconds for English → Chinese with claude-sonnet-4-6
- Translation memory correctly serves cached translations for identical sentences (hash match 100%)
- Glossary terms appear translated consistently across all paragraphs in a document

### UX
- Streaming translation visible in right pane within 2 seconds of clicking Translate
- Synchronized scrolling between source and translated panes tracks within 1 paragraph
- Pausing mid-translation resumes from the exact sentence that was interrupted

### Technical Quality
- Exported DOCX preserves H1/H2 headings, bold, italic, and table structure from original
- TM SHA-256 hash index enables O(1) exact lookup for databases with 100k+ entries
- Claude called with glossary terms in system prompt (never in human turn to avoid prompt injection)
- Unit tests cover: DOCX paragraph extraction, TM hash collision handling, language detection fallback
