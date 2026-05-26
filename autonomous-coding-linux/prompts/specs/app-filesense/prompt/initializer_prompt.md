## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- DO NOT run `git init` — a git repository has already been initialized in your cwd
- All file reads/writes MUST use relative paths
- Run `pwd` first to confirm your working directory, then work exclusively there

## YOUR ROLE - INITIALIZER AGENT (Session 1 of Many)

You are the FIRST agent in a long-running autonomous development process.
Your job is to set up the foundation for all future coding agents.

This project builds **FileSense** — a privacy-first local file search tool with a
Tkinter spotlight overlay and a background indexer daemon.
Tech stack: Python 3.11+, Tkinter + ttkbootstrap, watchdog 4.0 (file daemon),
sentence-transformers all-MiniLM-L6-v2 (local embeddings), ChromaDB 0.5 (vector store),
Anthropic Claude (re-ranking/suggestions), SQLite/SQLAlchemy 2.0.

### FIRST: Read the Project Specification

Start by reading `app_spec.txt` in your working directory. Read it carefully before proceeding.

### CRITICAL FIRST TASK: Create feature_list.json

Based on `app_spec.txt`, create a file called `feature_list.json` with ****NUM_FEATURES**** detailed
end-to-end test cases. This file is the single source of truth for what needs to be built.

**Format:**

```json
[
  {
    "category": "functional",
    "description": "Brief description of the feature and what this test verifies",
    "steps": [
      "Step 1: Run pytest command",
      "Step 2: Verify expected output",
      "Step 3: Check ChromaDB or SQLite state"
    ],
    "passes": false
  }
]
```

**Requirements for feature_list.json:**

- EXACTLY ****NUM_FEATURES**** features total (no more, no less)
- Both "functional" and "style" categories
- Mix of narrow tests (2-5 steps) and comprehensive tests (10+ steps)
- At least 1 test MUST have 10+ steps
- Order features by priority: daemon/indexer first, then ChromaDB search, then overlay UI, then Claude re-ranking, then duplicates/tags/settings
- ALL tests start with "passes": false
- Cover every feature in the spec exhaustively

**Testing Approach:**

FileSense has TWO components: a **Tkinter overlay** and a **background daemon**.
Testing approach:

- Daemon logic: `pytest` unit/integration tests (no display needed)
- Text extraction: `pytest` with sample files
- ChromaDB: `pytest` with ephemeral ChromaDB collection
- Tkinter overlay: `pytest` with mock Tk root (no display needed for logic tests)
- For visual Tkinter tests: `Xvfb :99 & DISPLAY=:99 python -m pytest tests/test_overlay.py`
- **Never use Puppeteer** — this is not a web app

**CRITICAL INSTRUCTION:**
IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS.
Features can ONLY be marked as passing (change "passes": false to "passes": true).

### SECOND TASK: Create init.sh

Create a script called `init.sh`:

1. Create and activate Python virtual environment
2. Install all dependencies (`pip install -r requirements.txt`)
3. Initialize SQLite database (create_all with FTS5 table)
4. Initialize ChromaDB collection (`filesense_embeddings`)
5. Download sentence-transformers model: `python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"`
6. Run smoke test: `python -c "from src.filesense.daemon import FileSenseDaemon; print('Daemon OK')"`
7. Print helpful info:
   - Start daemon: `python -m filesense.daemon &`
   - Start overlay: `DISPLAY=:99 python -m filesense.overlay`
   - Run tests: `python -m pytest tests/ -v`
   - API key: `export ANTHROPIC_API_KEY=$(cat /tmp/api-key)` (optional — pure local mode without)

Also create `requirements.txt`:
ttkbootstrap, watchdog, sentence-transformers, chromadb, anthropic, pdfplumber,
python-docx, markdown-it-py, chardet, sqlalchemy, pytest

### THIRD TASK: Initialize Git

First commit: feature_list.json, init.sh, requirements.txt, README.md

Commit message: "Initial setup: feature_list.json, init.sh, requirements.txt, and project structure"

### FOURTH TASK: Create Project Structure

```
src/filesense/
  __init__.py
  daemon.py            — FileSenseDaemon: watchdog setup, PID file, indexing loop
  extractor.py         — TextExtractor: pdfplumber/python-docx/plaintext/chardet
  embedder.py          — Embedder: SentenceTransformer loader, ChromaDB upsert, batch processing
  models.py            — SQLAlchemy ORM: IndexedFile, FileTag, WatchFolder, SearchHistory
  db.py                — SQLite engine + session factory + FTS5 tag index init
  search_engine.py     — SemanticSearch: embed query, ChromaDB ANN, result formatting
  reranker.py          — ClaudeReranker: re-rank prompt, snippet extraction, Q&A mode
  duplicates.py        — DuplicateDetector: SHA-256 hash scan + ChromaDB cosine scan
  organizer.py         — SmartOrganizer: Claude folder suggestion, atomic file moves, undo stack
  tagger.py            — AutoTagger: Claude topic extraction, FTS5 tag indexing
  overlay.py           — Tkinter spotlight overlay: Ctrl+Space binding, search UI, result cards
  settings_ui.py       — Tkinter settings window: watched folders, exclusion patterns
tests/
  conftest.py          — temp SQLite DB, temp ChromaDB, sample files fixture
  test_extractor.py    — Text extraction for txt/md/py/pdf/docx
  test_embedder.py     — Embedding generation + ChromaDB upsert
  test_search.py       — Semantic search end-to-end (with fixture files)
  test_duplicates.py   — SHA-256 exact + cosine near-duplicate detection
  test_daemon.py       — watchdog event handling, throttle logic
  test_models.py       — SQLAlchemy model tests + FTS5 tag search
  test_overlay.py      — Tkinter overlay widget tests (headless with mock Tk)
sample_files/
  sample.md            — Sample markdown file for indexer testing
  sample.txt           — Sample text file
  sample.py            — Sample Python file
```

### OPTIONAL: Start Implementation

If time remaining, implement:

1. `src/filesense/models.py` — SQLAlchemy ORM + FTS5 table setup
2. `src/filesense/db.py` — engine, session, FTS5 triggers for file_tags
3. `src/filesense/extractor.py` — TextExtractor for .txt/.md/.py files (skip PDF/DOCX initially)
4. `src/filesense/embedder.py` — SentenceTransformer loader + ChromaDB init

**API Key setup (optional — app works without Claude):**

```python
import os
key_path = "/tmp/api-key"
if os.path.exists(key_path):
    with open(key_path) as f:
        os.environ["ANTHROPIC_API_KEY"] = f.read().strip()
```

**ChromaDB WAL mode for daemon safety:**

```python
import chromadb
client = chromadb.PersistentClient(path="./filesense_db")
collection = client.get_or_create_collection("filesense_embeddings")
```

**SQLite WAL mode:**

```python
from sqlalchemy import event
@event.listens_for(engine, "connect")
def set_wal_mode(dbapi_conn, connection_record):
    dbapi_conn.execute("PRAGMA journal_mode=WAL")
```

### ENDING THIS SESSION

1. Commit all work
2. Create `claude-progress.txt`
3. Ensure feature_list.json complete
4. Leave environment clean

---

**Remember:** You have unlimited time. Focus on quality over speed.
