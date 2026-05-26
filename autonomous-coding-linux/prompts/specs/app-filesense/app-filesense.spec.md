# App Specification: FileSense

## Project Overview

FileSense is a privacy-first local file search and organizer. A background indexer daemon
watches configured folders, extracts text from files, and stores semantic embeddings in
ChromaDB. The Tkinter overlay (Ctrl+Space) lets users search in natural language; Claude
re-ranks results and can suggest folder reorganization. Everything runs locally — no file
content ever leaves the machine.

**Primary audience:** Developers, researchers, and knowledge workers with large local file
collections who want Google-quality semantic search without cloud storage.

---

## Technology Stack

| Layer              | Technology                                          |
|--------------------|-----------------------------------------------------|
| UI                 | Tkinter (overlay) + ttkbootstrap (theming)         |
| Background daemon  | Python watchdog 4.0 + threading                    |
| Embedding model    | sentence-transformers (all-MiniLM-L6-v2, local)    |
| Vector store       | ChromaDB 0.5 (persistent, local)                   |
| AI re-ranking      | Anthropic Claude (claude-sonnet-4-6)               |
| File parsing       | pdfplumber, python-docx, markdown-it-py, chardet   |
| Metadata DB        | SQLite (via SQLAlchemy 2.0)                         |
| File watching      | watchdog 4.0                                        |

---

## Core Features

### 1. Background Indexer Daemon
- Runs as a system service (`filesense-daemon`) or background process on startup
- Watches configured folders recursively for file create/modify/delete events
- Extracts text content from: .txt, .md, .py, .js, .ts, .go, .pdf, .docx, .csv
- Skips binary files, node_modules, .git directories, files > 50MB
- Generates embeddings via sentence-transformers (384-dim, CPU-friendly)
- Stores embeddings in ChromaDB, metadata in SQLite
- Throttles to max 5 files/second to avoid CPU spike during large initial scans

### 2. Semantic Search
- Ctrl+Space opens spotlight-style overlay from anywhere in the OS
- User types natural language query: "notes about machine learning from last month"
- Query embedded in real-time (< 100ms); ChromaDB returns top-50 candidates
- Results displayed as file cards: icon, name, parent folder, date, excerpt
- Keyboard navigation: arrow keys, Enter to open, Esc to close

### 3. Claude Re-Ranking & Query Understanding
- For ambiguous queries, Claude interprets intent and refines ChromaDB filter
- Claude re-ranks top-50 candidates to top-10 based on semantic relevance to query
- Explains top result: "This file matches because it discusses gradient descent from March"
- "Ask about files" mode: "What did I write about the API design last week?" → Claude answers using file excerpts as context

### 4. Duplicate Detection
- Content-hash (SHA-256) detects exact duplicates across watched folders
- Semantic similarity (cosine > 0.95) detects near-duplicates (same content, different format)
- Duplicate report in UI: side-by-side preview, one-click move-to-trash
- Configurable threshold: strict (0.98) / relaxed (0.90)

### 5. Smart Folder Suggestions
- Claude analyzes clusters of unorganized files in a target folder
- Suggests folder names and which files belong in each
- Example output: "23 files seem related to 'Project Alpha' — create /ProjectAlpha/?"
- User approves moves file by file or in bulk; changes are reversible (undo stack)

### 6. File Tagging
- AI auto-tag on index: extracts 3-5 topic tags per file (Claude or keyword extraction)
- Manual tag management in the UI: add, remove, rename tags
- Tag-based search: filter results by tag in overlay
- Tags stored in SQLite `file_tags` table, searchable via FTS5

### 7. Folder Watching Configuration
- GUI settings panel: add/remove watched folders
- Per-folder rules: include/exclude patterns (glob), max file size, file type filter
- Pause indexing for specific folders (e.g., downloads folder during active use)
- Index statistics: total files, total embeddings, last scan time per folder

### 8. Privacy Guarantees
- Embedding model runs entirely on CPU (no GPU required, no cloud API for embeddings)
- Claude API called only for re-ranking and suggestions (snippets only, not full files)
- Option to disable Claude entirely (pure local mode — ChromaDB search only)
- Logs stored locally; no telemetry, no analytics

---

## Database Schema

```sql
-- SQLite: file metadata, tags, history
CREATE TABLE indexed_files (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path       TEXT UNIQUE NOT NULL,
    file_name       TEXT NOT NULL,
    extension       TEXT,
    size_bytes      INTEGER,
    content_hash    SHA256 TEXT,        -- for exact duplicate detection
    chroma_doc_id   TEXT UNIQUE,        -- ChromaDB document ID
    last_modified   DATETIME NOT NULL,
    last_indexed    DATETIME NOT NULL,
    word_count      INTEGER,
    language        TEXT                -- detected language
);

CREATE TABLE file_tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id     INTEGER NOT NULL REFERENCES indexed_files(id) ON DELETE CASCADE,
    tag         TEXT NOT NULL,
    source      TEXT DEFAULT 'manual',  -- 'auto' | 'manual'
    created_at  DATETIME NOT NULL,
    UNIQUE(file_id, tag)
);

CREATE TABLE watch_folders (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    folder_path     TEXT UNIQUE NOT NULL,
    include_globs   TEXT DEFAULT '*',
    exclude_globs   TEXT DEFAULT 'node_modules/**,.git/**',
    max_file_mb     INTEGER DEFAULT 50,
    is_active       BOOLEAN DEFAULT 1,
    added_at        DATETIME NOT NULL
);

CREATE TABLE search_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    query       TEXT NOT NULL,
    result_count INTEGER,
    top_file_id INTEGER REFERENCES indexed_files(id),
    searched_at DATETIME NOT NULL
);

-- FTS5 for tag search
CREATE VIRTUAL TABLE file_tags_fts USING fts5(
    tag, file_id UNINDEXED,
    content='file_tags', content_rowid='id'
);
```

ChromaDB collection: `filesense_embeddings`
- Document: extracted text excerpt (first 512 tokens)
- Metadata: `{ file_path, file_name, extension, last_modified, tags }`
- Embedding: 384-dim float32 (sentence-transformers all-MiniLM-L6-v2)

---

## Architecture / UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│  SYSTEM TRAY ICON (daemon status indicator)                  │
│  Right-click: Pause / Settings / Quit                        │
└─────────────────────────────────────────────────────────────┘
          │ Ctrl+Space triggers
          ▼
┌─────────────────────────────────────────────────────────────┐
│  ┌──────────────────────────────────────────────────────┐   │
│  │  🔍 Search your files...                    [×]      │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  📄 design-notes.md          ~/Projects  2 days ago │    │
│  │     "...gradient descent is preferable here..."     │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │  📄 ml-references.txt        ~/Documents  1 wk ago  │    │
│  │     "...backpropagation overview, LR scheduling..." │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │  📂 [Open folder] [Show duplicates] [Organize...]   │    │
│  └─────────────────────────────────────────────────────┘    │
│  Claude: "Top result matches because it covers gradient..."  │
└─────────────────────────────────────────────────────────────┘

Background Daemon (separate process):
  watchdog → FileEventHandler → TextExtractor → Embedder → ChromaDB + SQLite
```

---

## Key Interactions

### Flow 1: Natural Language File Search
1. User presses Ctrl+Space; overlay animates open (< 80ms)
2. User types "meeting notes about API design last quarter"
3. Query embedded in real-time; ChromaDB ANN search returns top-50 results
4. Claude receives query + top-50 excerpts, returns ranked top-10 with explanation
5. Results rendered as cards; user presses Enter to open file in default app

### Flow 2: Duplicate Detection and Cleanup
1. User opens Settings > Duplicates panel
2. Daemon scans indexed_files for matching content_hash values (exact duplicates)
3. Near-duplicates found via ChromaDB pairwise similarity for files in same folder
4. UI lists duplicate pairs with side-by-side excerpt preview
5. User selects "Move to Trash" for each duplicate; undo available for 60 seconds

### Flow 3: Smart Folder Organization
1. User right-clicks a messy folder in the UI and selects "Suggest Organization"
2. Claude receives list of filenames + top keywords from each file (no full content)
3. Claude returns JSON: proposed subfolders and file assignments
4. UI presents a preview tree; user checks/unchecks files before applying
5. Files moved atomically; rollback available via undo stack (SQLite journal)

---

## Implementation Steps

1. **Daemon scaffold** — `filesense_daemon.py`, watchdog setup, PID file management
2. **Text extraction layer** — pdfplumber, python-docx, plaintext, chardet encoding detection
3. **Embedding pipeline** — sentence-transformers loader, ChromaDB collection init, batch upsert
4. **SQLite models** — `indexed_files`, `file_tags`, `watch_folders`, `search_history`
5. **Tkinter overlay** — ttkbootstrap themed window, keyboard bindings, result card widgets
6. **Claude integration** — re-ranking prompt, folder suggestion prompt, snippet-only payloads
7. **Duplicate detector** — SHA-256 hash comparison + ChromaDB cosine similarity scanner
8. **Settings UI** — watched folders management, exclusion patterns, duplicate threshold slider

---

## Success Criteria

### Functional
- Initial index of 10,000 files completes within 20 minutes on a modern laptop CPU
- Semantic search returns relevant results (top-3 contain target file) for test query set
- Duplicate detection finds 100% of exact duplicates and > 90% of near-duplicates in test set

### UX
- Overlay opens in < 80ms from Ctrl+Space keypress
- Search results update within 300ms of each keystroke
- Daemon CPU usage < 5% during idle (watchdog + no active indexing)

### Technical Quality
- ChromaDB and SQLite stay consistent after ungraceful daemon shutdown (WAL mode)
- Full-text tag search returns results in < 50ms for 100k tag entries
- Claude called with excerpts only (max 2000 tokens), never full file content
- Unit tests cover text extraction for all supported file types with edge-case inputs
