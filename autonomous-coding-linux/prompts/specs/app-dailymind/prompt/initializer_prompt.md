# DailyMind Initializer Prompt

You are an autonomous coding agent. Your job is to **scaffold the DailyMind project** from scratch.

Read the full app specification at `prompts/app_spec.txt` before taking any action.

---

## YOUR TASK: Initialize the Project

Create the complete project scaffold so that subsequent coding sessions can immediately start implementing features.

### What "Initialized" means

1. All directories and empty module files exist (matching the package structure)
2. `requirements.txt` is written with all dependencies
3. A working `init.sh` has been executed successfully
4. SQLite database tables are created (create_all runs without error)
5. `feature_list.json` is written summarizing all features to build
6. A brief `status.md` confirms readiness

---

## STEP 1: Read the Spec

```bash
cat prompts/app_spec.txt
```

Extract and internalize:

- Tech stack and dependencies
- Database schema (6 tables + FTS5)
- All 9 core features with their sub-tasks
- Package structure (every directory and file listed)
- Implementation steps (7 steps, each becoming one coding session)

---

## STEP 2: Create Directory Structure

Create **every directory** in the package structure:

```
dailymind/
  app/
    db/
    ai/
    ui/
    models/
    services/
    utils/
    themes/
  tests/
```

Use a single `mkdir -p` command. Then create all `__init__.py` files.

Also create the `generations/dailymind/` output directory.

---

## STEP 3: Write requirements.txt

Write `dailymind/requirements.txt` with pinned or minimum versions:

```
PyQt6>=6.6.0
PyQt6-Charts>=6.6.0
SQLAlchemy>=2.0.0
anthropic>=0.50.0
markdown2>=2.4.0
reportlab>=4.0.0
cryptography>=41.0.0
platformdirs>=4.0.0
keyring>=24.0.0
pytest>=7.0.0
pytest-qt>=4.0.0
```

---

## STEP 4: Write and Execute init.sh

Write `dailymind/init.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "=== DailyMind Project Initializer ==="

# 1. Create and activate virtual environment
cd "$(dirname "$0")"
python3 -m venv .venv
source .venv/bin/activate
echo "Virtual environment created."

# 2. Install dependencies
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo "Dependencies installed."

# 3. Initialize the database (create all tables)
python3 -c "
import sys
sys.path.insert(0, '.')
from app.db.models import Base, get_engine
engine = get_engine()
Base.metadata.create_all(engine)
print('Database tables created successfully.')
"

# 4. Verify imports work
python3 -c "
from PyQt6.QtWidgets import QApplication
from anthropic import Anthropic
from sqlalchemy import create_engine
import markdown2, reportlab, platformdirs, keyring
print('All imports verified.')
"

echo ""
echo "=== DailyMind is ready ==="
echo "To run the application:"
echo "  source .venv/bin/activate"
echo "  python3 main.py"
echo ""
echo "NOTE: Requires DISPLAY for GUI. On headless servers use:"
echo "  Xvfb :99 -screen 0 1280x800x24 &"
echo "  DISPLAY=:99 python3 main.py"
echo ""
echo "To run tests:"
echo "  python3 -m pytest tests/ -v"
echo ""
echo "DO NOT auto-launch the app here — it requires a display."
```

Make executable and run:

```bash
chmod +x dailymind/init.sh
cd dailymind && bash init.sh 2>&1
```

Capture and verify the output. Every step must say success.

---

## STEP 5: Write Stub Source Files

For each file in the package structure, write a minimal stub (valid Python that can be imported).

**Priority stubs to write (not just touch):**

### `dailymind/app/db/models.py`

```python
"""SQLAlchemy ORM models for DailyMind — 6 tables."""
import uuid
from datetime import datetime
from pathlib import Path

import platformdirs
from sqlalchemy import (Boolean, Column, Integer, String, Text,
                        ForeignKey, create_engine, event)
from sqlalchemy.orm import DeclarativeBase, relationship, Session

DATA_DIR = Path(platformdirs.user_data_dir("dailymind"))
DATA_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = DATA_DIR / "journal.db"


def get_engine(db_path: str | None = None):
    path = db_path or str(DB_PATH)
    return create_engine(f"sqlite:///{path}", echo=False)


class Base(DeclarativeBase):
    pass


class Entry(Base):
    __tablename__ = "entries"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    date = Column(String, nullable=False, unique=True)
    title = Column(String)
    body = Column(Text, nullable=False, default="")
    mood = Column(Integer)
    mood_note = Column(String)
    tags = Column(String, default="[]")
    word_count = Column(Integer, default=0)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    updated_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    is_pinned = Column(Integer, default=0)
    is_deleted = Column(Integer, default=0)
    versions = relationship("EntryVersion", back_populates="entry",
                            cascade="all, delete-orphan")
    ai_insights = relationship("AIInsight", back_populates="entry",
                               cascade="all, delete-orphan")


class EntryVersion(Base):
    __tablename__ = "entry_versions"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    entry_id = Column(String, ForeignKey("entries.id", ondelete="CASCADE"))
    body = Column(Text, nullable=False)
    saved_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    version_num = Column(Integer, nullable=False)
    entry = relationship("Entry", back_populates="versions")


class Habit(Base):
    __tablename__ = "habits"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    icon = Column(String, default="✓")
    color = Column(String, default="#4A90E2")
    sort_order = Column(Integer, default=0)
    is_active = Column(Integer, default=1)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    logs = relationship("HabitLog", back_populates="habit",
                        cascade="all, delete-orphan")


class HabitLog(Base):
    __tablename__ = "habit_logs"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    habit_id = Column(String, ForeignKey("habits.id", ondelete="CASCADE"))
    date = Column(String, nullable=False)
    completed = Column(Integer, default=0)
    note = Column(String)
    habit = relationship("Habit", back_populates="logs")


class AIInsight(Base):
    __tablename__ = "ai_insights"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    entry_id = Column(String, ForeignKey("entries.id", ondelete="CASCADE"))
    type = Column(String, nullable=False)
    prompt = Column(Text, nullable=False)
    response = Column(Text, nullable=False)
    model = Column(String, nullable=False)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
    tokens_used = Column(Integer, default=0)
    entry = relationship("Entry", back_populates="ai_insights")


class Template(Base):
    __tablename__ = "templates"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name = Column(String, nullable=False)
    body = Column(Text, nullable=False)
    is_default = Column(Integer, default=0)
    created_at = Column(String, default=lambda: datetime.utcnow().isoformat())
```

### `dailymind/main.py`

```python
"""DailyMind entry point."""
import sys
from PyQt6.QtWidgets import QApplication


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("DailyMind")
    app.setApplicationVersion("1.0.0")
    # MainWindow will be imported here once implemented
    # from app.ui.main_window import MainWindow
    # window = MainWindow()
    # window.show()
    print("DailyMind started — UI implementation pending.")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

Write stub `pass` bodies for all other modules in app/db/, app/ai/, app/ui/, app/services/, app/utils/.

---

## STEP 6: Write feature_list.json

Write `dailymind/feature_list.json` with ****NUM_FEATURES**** features:

```json
{
  "app": "DailyMind",
  "version": "1.0.0",
  "total_features": "__NUM_FEATURES__",
  "testing_approach": "Unit tests via pytest + pytest-qt, visual screenshot via xvfb-run. No web browser or Puppeteer — this is a PyQt6 desktop application.",
  "features": [
    {
      "id": 1,
      "name": "Journal Editor",
      "description": "Split-pane Markdown editor (QSplitter) with live preview (markdown2 + QTextBrowser), auto-save (QTimer 60s), word count, focus mode",
      "implementation_step": 2,
      "status": "pending",
      "test_file": "tests/test_editor.py",
      "files": ["app/ui/editor_pane.py", "app/services/entry_service.py", "app/db/queries.py"]
    },
    {
      "id": 2,
      "name": "AI Reflection and Prompts",
      "description": "QThread-based Claude API calls: Reflect button, daily writing prompt, Expand selection, Summarize week. All stream to slide-in AI panel.",
      "implementation_step": 4,
      "status": "pending",
      "test_file": "tests/test_ai_client.py",
      "files": ["app/ai/client.py", "app/ai/worker.py", "app/ai/prompts.py", "app/ui/ai_panel.py"]
    },
    {
      "id": 3,
      "name": "Mood Tracking",
      "description": "5-emoji QButtonGroup selector per entry, AI mood inference, PyQtChart weekly bar chart, monthly heatmap calendar",
      "implementation_step": 5,
      "status": "pending",
      "test_file": "tests/test_mood.py",
      "files": ["app/ui/mood_widget.py", "app/ui/calendar_view.py"]
    },
    {
      "id": 4,
      "name": "Automatic Tagging and FTS Search",
      "description": "Claude generates 3-5 tags on save, chip tag editor, tag cloud sidebar, SQLite FTS5 full-text search with debounce",
      "implementation_step": 4,
      "status": "pending",
      "test_file": "tests/test_search.py",
      "files": ["app/ui/sidebar.py", "app/db/queries.py"]
    },
    {
      "id": 5,
      "name": "Habit Tracker",
      "description": "Custom habit definition, per-day checkboxes, streak counter, weekly completion heatmap widget, Claude habit insight",
      "implementation_step": 5,
      "status": "pending",
      "test_file": "tests/test_habit.py",
      "files": ["app/ui/habit_widget.py", "app/services/habit_service.py"]
    },
    {
      "id": 6,
      "name": "Entry Organization",
      "description": "Sidebar grouped by Today/Week/Archive, calendar date picker, pinned entries, templates, entry versioning (last 10), soft delete",
      "implementation_step": 3,
      "status": "pending",
      "test_file": "tests/test_sidebar.py",
      "files": ["app/ui/sidebar.py", "app/ui/calendar_view.py"]
    },
    {
      "id": 7,
      "name": "Privacy and Security",
      "description": "Local-only data, optional AES-256 DB encryption (cryptography.fernet), AI offline mode toggle, API key in OS keychain (keyring)",
      "implementation_step": 6,
      "status": "pending",
      "test_file": "tests/test_export.py",
      "files": ["app/utils/encryption.py", "app/utils/config.py"]
    },
    {
      "id": 8,
      "name": "Export",
      "description": "Single entry: .md/.html/.pdf (reportlab). Date range ZIP of .md files. Full JSON backup + import. Day One JSON import.",
      "implementation_step": 6,
      "status": "pending",
      "test_file": "tests/test_export.py",
      "files": ["app/utils/export.py"]
    },
    {
      "id": 9,
      "name": "Settings and Themes",
      "description": "4 QSS themes (Light/Dark/Solarized/Nord), font selection, AI model/feature toggles, backup schedule, first-run onboarding wizard",
      "implementation_step": 7,
      "status": "pending",
      "test_file": "tests/test_settings.py",
      "files": ["app/ui/settings_dialog.py", "app/themes/"]
    }
  ]
}
```

Replace `__NUM_FEATURES__` with the actual integer count (9).

---

## STEP 7: Write Tests Skeleton

Write `dailymind/tests/test_db.py`:

```python
"""Tests for DailyMind database layer."""
import pytest
from sqlalchemy import create_engine, inspect

from app.db.models import Base, Entry, Habit, HabitLog, AIInsight, Template


@pytest.fixture
def engine(tmp_path):
    """Create a fresh in-memory SQLite engine for each test."""
    db_path = str(tmp_path / "test_journal.db")
    eng = create_engine(f"sqlite:///{db_path}")
    Base.metadata.create_all(eng)
    return eng


def test_all_tables_created(engine):
    """All 6 tables must exist after create_all."""
    inspector = inspect(engine)
    tables = inspector.get_table_names()
    for expected in ["entries", "entry_versions", "habits", "habit_logs",
                     "ai_insights", "templates"]:
        assert expected in tables, f"Missing table: {expected}"


def test_entry_insert_and_retrieve(engine):
    """Insert an entry and read it back."""
    from sqlalchemy.orm import Session
    with Session(engine) as session:
        entry = Entry(date="2025-05-26", body="Hello world", word_count=2)
        session.add(entry)
        session.commit()
        loaded = session.query(Entry).filter_by(date="2025-05-26").first()
        assert loaded is not None
        assert loaded.body == "Hello world"
        assert loaded.word_count == 2


def test_entry_unique_date_constraint(engine):
    """Two entries with the same date must fail."""
    from sqlalchemy.orm import Session
    from sqlalchemy.exc import IntegrityError
    with Session(engine) as session:
        session.add(Entry(date="2025-05-26", body="First"))
        session.commit()
    with Session(engine) as session:
        session.add(Entry(date="2025-05-26", body="Second"))
        with pytest.raises(IntegrityError):
            session.commit()
```

Write `dailymind/tests/__init__.py` (empty).

---

## STEP 8: Write status.md

Write `dailymind/status.md`:

```markdown
# DailyMind — Project Status

## Initialization: COMPLETE

- [x] Directory structure created
- [x] requirements.txt written
- [x] Virtual environment created (.venv)
- [x] Dependencies installed
- [x] Database tables created (6 tables)
- [x] All imports verified
- [x] Stub source files written
- [x] feature_list.json written (9 features)
- [x] tests/test_db.py written

## Ready for Coding Sessions

Next step: Run the coding_prompt.md to implement features one by one.
Start with Feature 1: Journal Editor (implementation_step 2).

## Quick Commands
```bash
cd dailymind
source .venv/bin/activate
python3 -m pytest tests/ -v          # run all tests
# On headless Linux for UI:
# Xvfb :99 -screen 0 1280x800x24 &
# DISPLAY=:99 python3 main.py
```

```

---

## FINAL CHECKS

Before finishing, run:

```bash
cd dailymind
source .venv/bin/activate
python3 -m pytest tests/test_db.py -v
```

All 3 tests in test_db.py must PASS.

Also verify imports:

```bash
python3 -c "from app.db.models import Base, Entry, Habit; print('Models OK')"
python3 -c "from PyQt6.QtWidgets import QApplication; print('PyQt6 OK')"
```

Report results. If any step failed, fix it before declaring success.
