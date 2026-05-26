## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- DO NOT run `git init` — a git repository has already been initialized in your cwd
- All file reads/writes MUST use relative paths
- Run `pwd` first to confirm your working directory, then work exclusively there

## YOUR ROLE - INITIALIZER AGENT (Session 1 of Many)

You are the FIRST agent in a long-running autonomous development process.
Your job is to set up the foundation for all future coding agents.

This project builds **MeetingMind** — a PyQt6 desktop application that records,
transcribes (via local Whisper), and summarizes meetings using Claude AI.
Tech stack: Python 3.11+, PyQt6 6.7, PyAudio 0.2.14, ffmpeg-python,
openai-whisper (local), Anthropic Claude (claude-sonnet-4-6), SQLite/SQLAlchemy 2.0,
python-docx, fpdf2.

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
      "Step 3: Check DB state"
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
- Order features by priority: audio recording/import first, then transcription, then summarization, then search/export
- ALL tests start with "passes": false
- Cover every feature in the spec exhaustively

**Testing Approach:**

MeetingMind is a **PyQt6 desktop GUI application**. There is NO web server.
All testing uses:

- `pytest` + `pytest-qt` for GUI component testing
- `Xvfb :99` for headless display
- Direct unit tests for Whisper integration, Claude parsing, FTS5 indexing
- Mock PyAudio for audio recording tests (no real microphone needed in CI)
- Launch headless: `Xvfb :99 & DISPLAY=:99 python -m pytest tests/ -v`
- **Never use Puppeteer** — this is not a web app

**CRITICAL INSTRUCTION:**
IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS.
Features can ONLY be marked as passing (change "passes": false to "passes": true).

### SECOND TASK: Create init.sh

Create a script called `init.sh` that future agents can use:

1. Check ffmpeg is installed (`which ffmpeg || sudo apt-get install -y ffmpeg`)
2. Create and activate Python virtual environment
3. Install all required Python dependencies (`pip install -r requirements.txt`)
4. Initialize SQLite database with SQLAlchemy `create_all` (including FTS5 triggers)
5. Start Xvfb on display :99
6. Run smoke test: `DISPLAY=:99 python -c "import PyQt6, whisper, anthropic; print('All imports OK')"`
7. Print helpful info:
   - Launch app: `DISPLAY=:99 python -m meetingmind`
   - Run tests: `DISPLAY=:99 python -m pytest tests/ -v`
   - API key: `export ANTHROPIC_API_KEY=$(cat /tmp/api-key)`
   - Whisper model download: `python -c "import whisper; whisper.load_model('base')"`

Also create `requirements.txt`:
PyQt6, pyaudio, ffmpeg-python, openai-whisper, anthropic, sqlalchemy, python-docx, fpdf2,
icalendar, pytest, pytest-qt

### THIRD TASK: Initialize Git

First commit: feature_list.json, init.sh, requirements.txt, README.md

Commit message: "Initial setup: feature_list.json, init.sh, requirements.txt, and project structure"

### FOURTH TASK: Create Project Structure

```
src/meetingmind/
  __init__.py
  main.py              — PyQt6 QApplication + MainWindow entry point
  models.py            — SQLAlchemy ORM: Meeting, Transcript, ActionItem, Participant + FTS5 setup
  db.py                — SQLite engine + session factory + FTS5 trigger creation
  recorder.py          — AudioRecorder: PyAudio stream, WAV writer, VU meter widget
  importer.py          — FileImporter: ffmpeg-python wrapper, drag-and-drop handler
  transcriber.py       — WhisperWorker: QThread, model loading, segment callback
  summarizer.py        — Claude summarization: prompt template, structured output parser
  diarizer.py          — BasicDiarizer: energy+pause speaker detection
  exporter.py          — export_docx(), export_pdf(), export_markdown(), export_csv_actions()
  search.py            — FTS5SearchEngine: index_transcript(), search(), filter_results()
  calendar_parser.py   — ICS file parser, upcoming meetings list
  ui/
    __init__.py
    main_window.py     — MainWindow QSplitter layout
    recording_controls.py — RecordingControlsWidget with VU meter
    meeting_list.py    — MeetingListWidget (QListWidget)
    transcript_pane.py — TranscriptPane with speaker-colored segments
    summary_pane.py    — SummaryPane QTextBrowser with collapsible sections
    search_bar.py      — SearchBarWidget with FTS5 results
alembic/
  env.py
  versions/
alembic.ini
tests/
  conftest.py          — pytest-qt fixtures, temp DB, mock PyAudio
  test_models.py       — SQLAlchemy model tests + FTS5 indexing
  test_transcriber.py  — Whisper segment parser tests (mock whisper)
  test_summarizer.py   — Claude response parser tests (mock anthropic)
  test_search.py       — FTS5 search tests
  test_exporter.py     — DOCX/PDF/Markdown export tests
  test_ui.py           — PyQt6 widget smoke tests
sample_audio/
  sample.wav           — Short sample WAV for testing (generate with Python)
```

### OPTIONAL: Start Implementation

If time remaining, implement:

1. `src/meetingmind/models.py` — ORM models + FTS5 virtual table setup
2. `src/meetingmind/db.py` — engine, session, FTS5 trigger (INSERT/UPDATE/DELETE on transcripts)
3. Basic PyQt6 MainWindow in `src/meetingmind/main.py`
4. `src/meetingmind/search.py` — FTS5 index and search

**API Key setup:**

```python
import os
key_path = "/tmp/api-key"
if os.path.exists(key_path):
    with open(key_path) as f:
        os.environ["ANTHROPIC_API_KEY"] = f.read().strip()
```

**FTS5 trigger setup in db.py:**

```python
# After create_all(), create FTS5 triggers for automatic indexing
conn.execute("""
    CREATE TRIGGER IF NOT EXISTS transcripts_ai AFTER INSERT ON transcripts BEGIN
        INSERT INTO transcripts_fts(rowid, text, meeting_id) VALUES (new.id, new.text, new.meeting_id);
    END
""")
```

### ENDING THIS SESSION

1. Commit all work
2. Create `claude-progress.txt`
3. Ensure feature_list.json complete
4. Leave environment clean

---

**Remember:** You have unlimited time. Focus on quality over speed.
