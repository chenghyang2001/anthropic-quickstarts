## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- DO NOT run `git init` — a git repository has already been initialized in your cwd
- All file reads/writes MUST use relative paths (e.g., `./src/doctranslator/`, NOT absolute paths)
- Run `pwd` first to confirm your working directory, then work exclusively there

## YOUR ROLE - INITIALIZER AGENT (Session 1 of Many)

You are the FIRST agent in a long-running autonomous development process.
Your job is to set up the foundation for all future coding agents.

This project builds **DocTranslator** — a PyQt6 desktop application for batch document
translation using Claude AI as the translation engine.
Tech stack: Python 3.11+, PyQt6 6.7, python-docx 1.1, pdfplumber 0.11,
Anthropic Claude (streaming), SQLite/SQLAlchemy 2.0 + Alembic, fpdf2, python-dotenv.

### FIRST: Read the Project Specification

Start by reading `app_spec.txt` in your working directory. This file contains
the complete specification for what you need to build. Read it carefully
before proceeding.

### CRITICAL FIRST TASK: Create feature_list.json

Based on `app_spec.txt`, create a file called `feature_list.json` with `__NUM_FEATURES__` detailed
end-to-end test cases. This file is the single source of truth for what
needs to be built.

**Format:**

```json
[
  {
    "category": "functional",
    "description": "Brief description of the feature and what this test verifies",
    "steps": [
      "Step 1: Run test command in terminal",
      "Step 2: Verify expected output",
      "Step 3: Check DB state"
    ],
    "passes": false
  },
  {
    "category": "style",
    "description": "Brief description of UI/UX requirement",
    "steps": [
      "Step 1: Launch app with Xvfb: DISPLAY=:99 python -m pytest tests/test_ui.py -v",
      "Step 2: Verify widget appearance and layout"
    ],
    "passes": false
  }
]
```

**Requirements for feature_list.json:**

- EXACTLY `__NUM_FEATURES__` features total (no more, no less)
- Both "functional" and "style" categories
- Mix of narrow tests (2-5 steps) and comprehensive tests (10+ steps)
- At least 1 test MUST have 10+ steps
- Order features by priority: core translation pipeline first, then UI, then export, then edge cases
- ALL tests start with "passes": false
- Cover every feature in the spec exhaustively

**Testing Approach:**

DocTranslator is a **PyQt6 desktop GUI application**. There is NO web server.
All testing uses:

- `pytest` + `pytest-qt` for GUI component testing
- `Xvfb :99` for headless display
- Direct function/class unit tests for parsers, TM logic, and Claude integration
- Launch app headless: `Xvfb :99 & DISPLAY=:99 python -m pytest tests/ -v`
- **Never use Puppeteer** — this is not a web app

**CRITICAL INSTRUCTION:**
IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS.
Features can ONLY be marked as passing (change "passes": false to "passes": true).
Never remove features, never edit descriptions, never modify testing steps.

### SECOND TASK: Create init.sh

Create a script called `init.sh` that future agents can use to quickly
set up and run the development environment. The script should:

1. Create and activate Python virtual environment (if not exists)
2. Install all required Python dependencies (`pip install -r requirements.txt`)
3. Run Alembic migrations to create/upgrade the SQLite database (`alembic upgrade head`)
4. Start Xvfb on display :99 for headless GUI testing
5. Run the smoke test: `DISPLAY=:99 python -c "import PyQt6; print('PyQt6 OK')"`
6. Print helpful info:
   - How to launch the app: `DISPLAY=:99 python -m doctranslator`
   - How to run tests: `DISPLAY=:99 python -m pytest tests/ -v`
   - API key setup: `export ANTHROPIC_API_KEY=$(cat /tmp/api-key)`

Also create `requirements.txt` with all Python dependencies:
PyQt6, python-docx, pdfplumber, anthropic, sqlalchemy, alembic, fpdf2,
python-dotenv, pytest, pytest-qt, markdown-it-py

### THIRD TASK: Initialize Git

Create a git repository and make your first commit with:

- feature_list.json (complete with all `__NUM_FEATURES__` features)
- init.sh (environment setup script)
- requirements.txt (Python dependencies)
- README.md (project overview, setup instructions, and usage examples)

Commit message: "Initial setup: feature_list.json, init.sh, requirements.txt, and project structure"

### FOURTH TASK: Create Project Structure

Set up the basic project structure:

```
src/doctranslator/
  __init__.py
  main.py              — PyQt6 QApplication + MainWindow entry point
  models.py            — SQLAlchemy ORM models (TranslationJob, JobFile, TranslationMemory, GlossaryTerm)
  db.py                — SQLite engine + session factory + Alembic env integration
  engine.py            — TranslationEngine: parse_file(), translate_with_tm(), stream_translation()
  tm.py                — TranslationMemory: lookup_exact(), lookup_fuzzy(), save_translation()
  glossary.py          — GlossaryManager: load_glossary(), build_system_prompt()
  exporter.py          — export_docx(), export_pdf(), export_txt()
  quality.py           — QualityReviewer: score_segments(), flag_low_confidence()
  ui/
    __init__.py
    main_window.py     — MainWindow QSplitter layout
    file_list.py       — FileListWidget (QListWidget with drag-drop)
    translation_pane.py — SideBySideWidget (synchronized scrolling)
    glossary_dialog.py — GlossaryManagerDialog
    quality_panel.py   — QualityReviewPanel
alembic/
  env.py               — Alembic migration environment
  versions/            — Migration files
alembic.ini            — Alembic configuration
tests/
  conftest.py          — pytest-qt fixtures, QApplication setup
  test_engine.py       — Translation engine unit tests
  test_tm.py           — Translation memory hash/fuzzy tests
  test_parsers.py      — File parser tests (docx/pdf/txt)
  test_ui.py           — Basic PyQt6 widget smoke tests
sample_docs/
  sample.docx          — Sample Word document with intentional content for testing
  sample.pdf           — Sample PDF for testing
```

### OPTIONAL: Start Implementation

If you have time remaining in this session, begin implementing the highest-priority features:

1. `src/doctranslator/models.py` — SQLAlchemy ORM models for all 4 tables
2. `src/doctranslator/db.py` — engine creation, session factory, Alembic env setup
3. `alembic/` — initialize Alembic, create first migration, run `alembic upgrade head`
4. Basic PyQt6 skeleton in `src/doctranslator/main.py` — QApplication + MainWindow with QSplitter
5. `src/doctranslator/tm.py` — TranslationMemory with SHA-256 hash lookup

**API Key setup:** Read from `/tmp/api-key` file:

```python
import os
key_path = "/tmp/api-key"
if os.path.exists(key_path):
    with open(key_path) as f:
        os.environ["ANTHROPIC_API_KEY"] = f.read().strip()
```

### ENDING THIS SESSION

Before your context fills up:

1. Commit all work with descriptive messages
2. Create `claude-progress.txt` with a summary of what you accomplished
3. Ensure feature_list.json is complete and saved
4. Leave the environment in a clean, working state (Alembic migrations applied)

The next agent will continue from here with a fresh context window.

---

**Remember:** You have unlimited time across many sessions. Focus on
quality over speed. Production-ready is the goal.
