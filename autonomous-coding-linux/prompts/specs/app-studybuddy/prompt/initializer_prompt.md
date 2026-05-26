# StudyBuddy Initializer Prompt

You are an autonomous coding agent. Your job is to **scaffold the StudyBuddy project** from scratch.

Read the full app specification at `prompts/app_spec.txt` before taking any action.

---

## YOUR TASK: Initialize the Project

Create the complete project scaffold so that subsequent coding sessions can immediately start implementing features.

### What "Initialized" means

1. All directories and empty module files exist (matching the package structure)
2. `requirements.txt` is written with all dependencies
3. A working `init.sh` has been executed successfully
4. SQLite database tables are created (create_all runs without error)
5. SM-2 algorithm core function is implemented and tested
6. `feature_list.json` is written summarizing all features to build
7. A brief `status.md` confirms readiness

---

## STEP 1: Read the Spec

```bash
cat prompts/app_spec.txt
```

Extract and internalize:

- Tech stack and all dependencies
- Database schema (4 tables with constraints)
- All 8 core features with their sub-tasks
- Package structure (every directory and file listed)
- Implementation steps (8 steps, each becoming one coding session)

---

## STEP 2: Create Directory Structure

Create **every directory** in the package structure:

```
studybuddy/
  app/
    db/        (or app/db.py — single file for this smaller app)
    ui/
    services/
  tests/
```

Use a single `mkdir -p` command:

```bash
mkdir -p studybuddy/app/ui studybuddy/app/services studybuddy/tests
touch studybuddy/app/__init__.py studybuddy/app/ui/__init__.py studybuddy/app/services/__init__.py studybuddy/tests/__init__.py
```

Also create the `generations/studybuddy/` output directory.

---

## STEP 3: Write requirements.txt

Write `studybuddy/requirements.txt`:

```
PyQt6>=6.6.0
SQLAlchemy>=2.0.0
anthropic>=0.50.0
pdfplumber>=0.10.0
markdown2>=2.4.0
genanki>=0.13.0
matplotlib>=3.8.0
platformdirs>=4.0.0
pytest>=7.0.0
pytest-qt>=4.0.0
```

---

## STEP 4: Write and Execute init.sh

Write `studybuddy/init.sh`:

```bash
#!/bin/bash
set -euo pipefail

echo "=== StudyBuddy Project Initializer ==="

cd "$(dirname "$0")"

# 1. Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate
echo "Virtual environment created."

# 2. Install dependencies
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo "Dependencies installed."

# 3. Initialize the database
python3 -c "
import sys
sys.path.insert(0, '.')
from app.db import Base, get_engine
engine = get_engine()
Base.metadata.create_all(engine)
print('Database tables created successfully.')
"

# 4. Verify imports work
python3 -c "
from PyQt6.QtWidgets import QApplication
from anthropic import Anthropic
from sqlalchemy import create_engine
import pdfplumber, markdown2, genanki, matplotlib, platformdirs
print('All imports verified.')
"

# 5. Run SM-2 tests
python3 -m pytest tests/test_sm2.py -v --tb=short
echo "SM-2 tests complete."

echo ""
echo "=== StudyBuddy is ready ==="
echo "To run the application:"
echo "  source .venv/bin/activate"
echo "  python3 main.py"
echo ""
echo "NOTE: Requires DISPLAY for GUI. On headless servers use:"
echo "  Xvfb :99 -screen 0 1280x800x24 &"
echo "  DISPLAY=:99 python3 main.py"
echo ""
echo "To run all tests:"
echo "  python3 -m pytest tests/ -v"
echo ""
echo "DO NOT auto-launch the app here — it requires a display."
```

Make executable and run:

```bash
chmod +x studybuddy/init.sh
cd studybuddy && bash init.sh 2>&1
```

---

## STEP 5: Write Core Stub Source Files

### `studybuddy/sm2.py` — IMPLEMENT FULLY (not a stub)

This must be a complete, working implementation:

```python
"""SM-2 Spaced Repetition Algorithm — pure function, no DB dependency."""
from datetime import date, timedelta
from typing import Tuple


def calculate_next_review(
    interval: int,
    ease_factor: float,
    repetitions: int,
    rating: int,
) -> Tuple[int, float, int, str]:
    """
    SM-2 algorithm: compute next review parameters after a rating.

    Args:
        interval: current interval in days (>= 1)
        ease_factor: current ease factor (>= 1.3)
        repetitions: consecutive correct reviews so far
        rating: quality rating 1-5 (1=Again/blackout, 5=Perfect)

    Returns:
        (new_interval, new_ease_factor, new_repetitions, next_review_date_str)
        next_review_date_str format: YYYY-MM-DD
    """
    if rating < 1 or rating > 5:
        raise ValueError(f"Rating must be 1-5, got {rating}")

    # Update ease factor (can go below 1.3 — clamp after)
    new_ease = ease_factor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02))
    new_ease = max(1.3, new_ease)  # minimum ease factor per SM-2 spec

    if rating >= 3:
        # Correct response — advance repetition count and increase interval
        new_reps = repetitions + 1
        if new_reps == 1:
            new_interval = 1
        elif new_reps == 2:
            new_interval = 6
        else:
            new_interval = round(interval * new_ease)
    else:
        # Incorrect response — reset to beginning
        new_reps = 0
        new_interval = 1

    next_date = (date.today() + timedelta(days=new_interval)).isoformat()
    return new_interval, new_ease, new_reps, next_date
```

### `studybuddy/app/db.py` — IMPLEMENT FULLY

```python
"""SQLAlchemy ORM models for StudyBuddy — 4 tables."""
from datetime import datetime, date
from pathlib import Path

import platformdirs
from sqlalchemy import (Boolean, Column, Integer, String, Text, Float,
                        ForeignKey, DateTime, Date, create_engine, CheckConstraint)
from sqlalchemy.orm import DeclarativeBase, relationship


DATA_DIR = Path(platformdirs.user_data_dir("studybuddy"))
DATA_DIR.mkdir(parents=True, exist_ok=True)
DB_PATH = DATA_DIR / "studybuddy.db"


def get_engine(db_path: str | None = None):
    """Return SQLAlchemy engine for the StudyBuddy database."""
    path = db_path or str(DB_PATH)
    return create_engine(f"sqlite:///{path}", echo=False)


class Base(DeclarativeBase):
    pass


class Deck(Base):
    __tablename__ = "decks"
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    parent_id = Column(Integer, ForeignKey("decks.id", ondelete="CASCADE"), nullable=True)
    color = Column(String, default="#4A90E2")
    created_at = Column(DateTime, default=datetime.utcnow)
    description = Column(Text)

    cards = relationship("Card", back_populates="deck", cascade="all, delete-orphan")
    children = relationship("Deck", backref="parent",
                            foreign_keys=[parent_id],
                            cascade="all, delete-orphan")
    sessions = relationship("StudySession", back_populates="deck")


class Card(Base):
    __tablename__ = "cards"
    id = Column(Integer, primary_key=True, autoincrement=True)
    deck_id = Column(Integer, ForeignKey("decks.id", ondelete="CASCADE"), nullable=False)
    front = Column(Text, nullable=False)
    back = Column(Text, nullable=False)
    card_type = Column(String, default="basic")
    tags = Column(String, default="")
    interval = Column(Integer, default=1)
    ease_factor = Column(Float, default=2.5)
    repetitions = Column(Integer, default=0)
    next_review = Column(String, default=lambda: date.today().isoformat())
    ai_explanation = Column(Text)
    suspended = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    deck = relationship("Deck", back_populates="cards")
    reviews = relationship("CardReview", back_populates="card", cascade="all, delete-orphan")


class StudySession(Base):
    __tablename__ = "study_sessions"
    id = Column(Integer, primary_key=True, autoincrement=True)
    started_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    ended_at = Column(DateTime)
    cards_reviewed = Column(Integer, default=0)
    avg_rating = Column(Float)
    deck_id = Column(Integer, ForeignKey("decks.id", ondelete="SET NULL"), nullable=True)

    deck = relationship("Deck", back_populates="sessions")
    reviews = relationship("CardReview", back_populates="session")


class CardReview(Base):
    __tablename__ = "card_reviews"
    id = Column(Integer, primary_key=True, autoincrement=True)
    card_id = Column(Integer, ForeignKey("cards.id", ondelete="CASCADE"), nullable=False)
    session_id = Column(Integer, ForeignKey("study_sessions.id", ondelete="SET NULL"))
    rating = Column(Integer, nullable=False)
    reviewed_at = Column(DateTime, default=datetime.utcnow)
    time_spent = Column(Integer)

    card = relationship("Card", back_populates="reviews")
    session = relationship("StudySession", back_populates="reviews")
```

### `studybuddy/main.py`

```python
"""StudyBuddy entry point."""
import sys
from PyQt6.QtWidgets import QApplication


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("StudyBuddy")
    app.setApplicationVersion("1.0.0")
    # MainWindow imported once implemented
    # from app.ui.main_window import MainWindow
    # window = MainWindow()
    # window.show()
    print("StudyBuddy started — UI implementation pending.")
    sys.exit(0)


if __name__ == "__main__":
    main()
```

Write stub `pass` bodies for all remaining module files:

- `studybuddy/app/ui/main_window.py`
- `studybuddy/app/ui/deck_sidebar.py`
- `studybuddy/app/ui/card_list.py`
- `studybuddy/app/ui/study_window.py`
- `studybuddy/app/ui/card_editor.py`
- `studybuddy/app/ui/stats_widget.py`
- `studybuddy/app/ui/import_dialog.py`
- `studybuddy/app/services/import_service.py`
- `studybuddy/app/services/claude_client.py`
- `studybuddy/app/services/export_service.py`

---

## STEP 6: Write tests/test_sm2.py — IMPLEMENT FULLY

```python
"""Tests for SM-2 spaced repetition algorithm."""
import pytest
from datetime import date, timedelta
from sm2 import calculate_next_review


def test_perfect_rating_advances_repetitions():
    """Rating 5 (Perfect) should advance repetitions by 1."""
    interval, ease, reps, next_date = calculate_next_review(1, 2.5, 0, 5)
    assert reps == 1
    assert interval == 1  # first repetition always 1 day


def test_second_repetition_gives_6_days():
    """Second successful repetition yields 6-day interval per SM-2."""
    interval, ease, reps, next_date = calculate_next_review(1, 2.5, 1, 4)
    assert interval == 6
    assert reps == 2


def test_third_repetition_uses_ease_factor():
    """Third+ repetition: new_interval = round(prev_interval * ease_factor)."""
    interval, ease, reps, next_date = calculate_next_review(6, 2.5, 2, 4)
    assert interval == round(6 * 2.5)
    assert reps == 3


def test_again_rating_resets_to_one():
    """Rating 1 (Again) resets repetitions to 0 and interval to 1."""
    interval, ease, reps, next_date = calculate_next_review(10, 2.5, 3, 1)
    assert reps == 0
    assert interval == 1


def test_hard_rating_resets():
    """Rating 2 (Hard) also resets repetitions to 0."""
    interval, ease, reps, next_date = calculate_next_review(6, 2.5, 2, 2)
    assert reps == 0
    assert interval == 1


def test_ease_factor_increases_on_perfect():
    """Rating 5 increases ease factor."""
    _, new_ease, _, _ = calculate_next_review(1, 2.5, 0, 5)
    assert new_ease > 2.5


def test_ease_factor_decreases_on_hard():
    """Rating 2 decreases ease factor."""
    _, new_ease, _, _ = calculate_next_review(1, 2.5, 1, 2)
    assert new_ease < 2.5


def test_ease_factor_never_below_1_3():
    """Ease factor is clamped at minimum 1.3."""
    # Apply multiple low ratings to try to push ease below 1.3
    ease = 1.3
    for _ in range(5):
        _, ease, _, _ = calculate_next_review(1, ease, 0, 1)
    assert ease >= 1.3


def test_next_review_date_is_future():
    """next_review date should be today or in the future."""
    _, _, _, next_date = calculate_next_review(1, 2.5, 0, 3)
    assert next_date >= date.today().isoformat()


def test_next_review_date_format():
    """next_review date should be in YYYY-MM-DD format."""
    _, _, _, next_date = calculate_next_review(6, 2.5, 2, 4)
    parts = next_date.split("-")
    assert len(parts) == 3
    assert len(parts[0]) == 4  # year


def test_invalid_rating_raises():
    """Ratings outside 1-5 must raise ValueError."""
    with pytest.raises(ValueError):
        calculate_next_review(1, 2.5, 0, 0)
    with pytest.raises(ValueError):
        calculate_next_review(1, 2.5, 0, 6)


def test_good_rating_does_not_reset():
    """Rating 3 (Good) is a pass — should not reset repetitions."""
    _, _, reps, _ = calculate_next_review(6, 2.5, 2, 3)
    assert reps == 3
```

---

## STEP 7: Write tests/test_db.py skeleton

```python
"""Tests for StudyBuddy database layer."""
import pytest
from sqlalchemy import create_engine, inspect
from app.db import Base, Deck, Card, StudySession, CardReview


@pytest.fixture
def engine(tmp_path):
    """Create a fresh SQLite DB for each test."""
    eng = create_engine(f"sqlite:///{tmp_path}/test.db")
    Base.metadata.create_all(eng)
    return eng


def test_all_tables_created(engine):
    """All 4 tables must exist after create_all."""
    tables = inspect(engine).get_table_names()
    for expected in ["decks", "cards", "study_sessions", "card_reviews"]:
        assert expected in tables, f"Missing table: {expected}"


def test_deck_insert(engine):
    """Insert a deck and verify retrieval."""
    from sqlalchemy.orm import Session
    with Session(engine) as s:
        deck = Deck(name="Python", color="#FF6B35")
        s.add(deck)
        s.commit()
        loaded = s.query(Deck).filter_by(name="Python").first()
        assert loaded is not None
        assert loaded.color == "#FF6B35"


def test_card_cascade_delete(engine):
    """Deleting a deck must cascade-delete its cards."""
    from sqlalchemy.orm import Session
    with Session(engine) as s:
        deck = Deck(name="Temp")
        s.add(deck)
        s.flush()
        card = Card(deck_id=deck.id, front="Q?", back="A.")
        s.add(card)
        s.commit()
        deck_id = deck.id
        card_id = card.id
    with Session(engine) as s:
        s.delete(s.get(Deck, deck_id))
        s.commit()
        assert s.get(Card, card_id) is None
```

---

## STEP 8: Write feature_list.json

Write `studybuddy/feature_list.json`:

```json
{
  "app": "StudyBuddy",
  "version": "1.0.0",
  "total_features": "__NUM_FEATURES__",
  "testing_approach": "Unit tests via pytest + pytest-qt, visual screenshot via xvfb-run. No web browser or Puppeteer — this is a PyQt6 desktop application.",
  "features": [
    {
      "id": 1,
      "name": "Note Import and AI Flashcard Generation",
      "description": "Accept .md/.pdf/.txt files, extract text, chunk to 500-token segments, Claude generates Q&A pairs as JSON, CardPreviewDialog for review before saving",
      "implementation_step": 4,
      "status": "pending",
      "test_file": "tests/test_import.py",
      "files": ["app/services/import_service.py", "app/services/claude_client.py", "app/ui/import_dialog.py"]
    },
    {
      "id": 2,
      "name": "SM-2 Spaced Repetition Scheduler",
      "description": "Pure SM-2 function in sm2.py: calculate_next_review(interval, ease, reps, rating) -> (interval, ease, reps, date). Overdue-first queue. Configurable new cards per day.",
      "implementation_step": 1,
      "status": "pending",
      "test_file": "tests/test_sm2.py",
      "files": ["sm2.py"]
    },
    {
      "id": 3,
      "name": "Multiple Card Types",
      "description": "Basic (flip), Cloze ({{c1::}} syntax shown as blank in study mode), Image (placeholder). Bulk type conversion in card list.",
      "implementation_step": 3,
      "status": "pending",
      "test_file": "tests/test_db.py",
      "files": ["app/ui/card_list.py", "app/ui/card_editor.py"]
    },
    {
      "id": 4,
      "name": "Daily Study Session",
      "description": "Full-screen QWidget study mode, card flip animation (QPropertyAnimation), 1-5 rating keyboard shortcuts, undo last, session summary dialog, streak tracking",
      "implementation_step": 5,
      "status": "pending",
      "test_file": "tests/test_sm2.py",
      "files": ["app/ui/study_window.py"]
    },
    {
      "id": 5,
      "name": "AI Why Was I Wrong Explanation",
      "description": "On rating 1-2, Claude explains root cause + mnemonic + example (max 150 words). Streams into ExplanationPanel. Rate-limited 10/session. Cached in cards.ai_explanation.",
      "implementation_step": 6,
      "status": "pending",
      "test_file": "tests/test_import.py",
      "files": ["app/services/claude_client.py", "app/ui/study_window.py"]
    },
    {
      "id": 6,
      "name": "Deck Organization",
      "description": "Hierarchical QTreeWidget (3 levels), context menu CRUD, color picker, card tagging, full-text search filter, bulk move/suspend/delete",
      "implementation_step": 2,
      "status": "pending",
      "test_file": "tests/test_db.py",
      "files": ["app/ui/deck_sidebar.py", "app/ui/card_list.py"]
    },
    {
      "id": 7,
      "name": "Study Statistics",
      "description": "Retention rate line chart (matplotlib), streak calendar heatmap (custom paint), cards-per-day bar chart, ease factor trend, CSV export",
      "implementation_step": 7,
      "status": "pending",
      "test_file": "tests/test_db.py",
      "files": ["app/ui/stats_widget.py", "app/services/export_service.py"]
    },
    {
      "id": 8,
      "name": "Anki Export",
      "description": "genanki .apkg export: Basic + Cloze models, Parent::Child deck names, scheduling data preserved, save to ~/Documents/StudyBuddy/exports/",
      "implementation_step": 8,
      "status": "pending",
      "test_file": "tests/test_import.py",
      "files": ["app/services/export_service.py"]
    }
  ]
}
```

Replace `__NUM_FEATURES__` with the actual integer count (8).

---

## STEP 9: Write status.md

Write `studybuddy/status.md`:

```markdown
# StudyBuddy — Project Status

## Initialization: COMPLETE

- [x] Directory structure created
- [x] requirements.txt written
- [x] Virtual environment created (.venv)
- [x] Dependencies installed
- [x] Database tables created (4 tables)
- [x] sm2.py implemented (pure SM-2 algorithm)
- [x] tests/test_sm2.py written (12 tests)
- [x] All imports verified
- [x] Stub source files written
- [x] feature_list.json written (8 features)
- [x] tests/test_db.py written

## SM-2 Test Results
All 12 test_sm2 tests passing.

## Ready for Coding Sessions

Next step: Run the coding_prompt.md to implement features one by one.
Start with Feature 6: Deck Organization (implementation_step 2), then
Feature 2 is already implemented (sm2.py done).

## Quick Commands
```bash
cd studybuddy
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
cd studybuddy
source .venv/bin/activate

# SM-2 tests must all pass
python3 -m pytest tests/test_sm2.py tests/test_db.py -v --tb=short

# Verify core imports
python3 -c "
from sm2 import calculate_next_review
result = calculate_next_review(1, 2.5, 0, 4)
print(f'SM-2 test: {result}')
assert result[0] == 1  # first rep = 1 day
print('SM-2 algorithm: OK')
"

python3 -c "
from app.db import Base, Deck, Card, get_engine
from sqlalchemy import inspect
engine = get_engine('/tmp/verify_studybuddy.db')
Base.metadata.create_all(engine)
tables = inspect(engine).get_table_names()
assert set(tables) >= {'decks', 'cards', 'study_sessions', 'card_reviews'}
print('DB tables: OK', tables)
"

python3 -c "from PyQt6.QtWidgets import QApplication; print('PyQt6: OK')"
python3 -c "import pdfplumber, genanki, matplotlib; print('Extra libs: OK')"
```

Report all results. Every check must show OK. If any test fails, fix it before declaring initialization complete.
