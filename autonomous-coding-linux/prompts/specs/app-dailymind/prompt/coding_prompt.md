# DailyMind Coding Prompt

You are an autonomous coding agent implementing features for **DailyMind**, a PyQt6 desktop journal application with Claude AI integration.

**IMPORTANT: This is a PyQt6 desktop application. Do NOT use Puppeteer. Testing uses pytest + pytest-qt + Xvfb.**

---

## STEP 1: GET YOUR BEARINGS

```bash
# Read the spec and current status
cat prompts/app_spec.txt
cat dailymind/status.md
cat dailymind/feature_list.json

# Check what tests exist and their status
cd dailymind
source .venv/bin/activate
python3 -m pytest tests/ --collect-only 2>&1 | head -30

# See which files have real implementations vs stubs
grep -rl "pass$" app/ 2>/dev/null | head -20

# Check DB state
python3 -c "
from app.db.models import Base, get_engine
from sqlalchemy import inspect
engine = get_engine()
Base.metadata.create_all(engine)
tables = inspect(engine).get_table_names()
print('Tables:', tables)
"
```

Determine which feature to implement next by reading `feature_list.json` and finding the first feature with `"status": "pending"`.

---

## STEP 2: ACTIVATE ENVIRONMENT AND VERIFY DB

```bash
cd dailymind
source .venv/bin/activate

# Run migrations (idempotent — safe to run every session)
python3 -c "
from app.db.models import Base, get_engine
engine = get_engine()
Base.metadata.create_all(engine)
print('DB ready. Tables:', list(Base.metadata.tables.keys()))
"

# Check ANTHROPIC_API_KEY for AI features
python3 -c "
import os
key = os.environ.get('ANTHROPIC_API_KEY', '')
if key:
    print(f'API key found: {key[:8]}...')
else:
    print('WARNING: ANTHROPIC_API_KEY not set. AI features will be disabled.')
"
```

If the DB fails to initialize, fix models.py before proceeding to any other step.

---

## STEP 3: IMPLEMENT THE CURRENT FEATURE

Read `feature_list.json` to get the next pending feature. Then implement it fully.

### Feature Implementation Rules

**Rule 1: Complete the entire feature, not just stubs.**
Every function must have a real implementation. No `pass`, `TODO`, or `raise NotImplementedError` in final code.

**Rule 2: All Claude API calls MUST run in QThread workers.**
Never call `anthropic.Anthropic().messages.create()` from the UI thread.
The pattern is always:

```python
class AIWorker(QThread):
    result_ready = pyqtSignal(str)
    error_occurred = pyqtSignal(str)

    def run(self):
        try:
            client = Anthropic()  # reads ANTHROPIC_API_KEY from env
            response = client.messages.create(...)
            self.result_ready.emit(response.content[0].text)
        except Exception as e:
            self.error_occurred.emit(str(e))
```

**Rule 3: SQLAlchemy sessions use try/finally.**

```python
from sqlalchemy.orm import Session
engine = get_engine()
with Session(engine) as session:
    # operations
    session.commit()
# Session auto-closed by context manager
```

**Rule 4: API key ONLY from environment.**

```python
import os
api_key = os.environ.get("ANTHROPIC_API_KEY")
if not api_key:
    raise RuntimeError("ANTHROPIC_API_KEY not set")
```

**Rule 5: Use platformdirs for ALL data paths.**

```python
import platformdirs
DATA_DIR = platformdirs.user_data_dir("dailymind")
# Never: Path("~/.dailymind").expanduser()
```

**Rule 6: Validate Claude JSON responses before writing to DB.**

```python
import json
try:
    data = json.loads(response_text)
    tags = [str(t) for t in data.get("tags", [])][:5]  # max 5
except (json.JSONDecodeError, AttributeError):
    tags = []  # graceful fallback
```

### Feature-Specific Implementation Guides

#### Feature 1: Journal Editor

- `app/ui/editor_pane.py`: QSplitter(Qt.Horizontal) with sizes [50%, 50%]
- Left pane: QPlainTextEdit subclass with Markdown syntax highlighter
- Right pane: QTextBrowser with `setOpenExternalLinks(True)`
- Connect: `editor.textChanged.connect(self._update_preview)`
- `_update_preview()`: `markdown2.markdown(text, extras=["fenced-code-blocks", "tables"])` → `browser.setHtml(html)`
- Auto-save: `QTimer.singleShot(60000, self._auto_save)` reset on each textChanged
- `app/services/entry_service.py`: `save_entry(date, body, mood=None, tags=None)`, `get_entry(date)`, `list_entries()`, `search(query)`

#### Feature 2: AI Reflection and Prompts

- `app/ai/prompts.py`: Define system prompts as module-level constants

  ```python
  REFLECTION_SYSTEM = """You are a thoughtful journaling coach. Read the journal entry
  and respond with 2-3 open-ended Socratic questions to help the writer reflect deeper.
  Be warm, concise, and non-judgmental. Questions only — no preamble."""

  TAGGING_SYSTEM = """Extract 3-5 concise topic tags from this journal entry.
  Return ONLY valid JSON: {"tags": ["tag1", "tag2", "tag3"]}
  Tags should be lowercase, single words or short phrases."""

  MOOD_SYSTEM = """Infer the writer's mood from this journal entry.
  Return ONLY valid JSON: {"mood": 3, "mood_note": "brief explanation"}
  mood is an integer 1-5 (1=terrible, 3=neutral, 5=excellent)."""

  DAILY_PROMPT_SYSTEM = """Generate a single thoughtful journaling prompt for today.
  One sentence only. Be creative and introspective."""
  ```

- `app/ai/worker.py`: AIWorker(QThread) — accepts prompt_type and entry_body
- `app/ui/ai_panel.py`: QWidget with QPropertyAnimation for slide-in/out, QTextBrowser for content
- Button in editor status bar: `QPushButton("✨ Reflect")` → starts AIWorker → streams to panel

#### Feature 3: Mood Tracking

- `app/ui/mood_widget.py`: QWidget with 5 emoji QPushButton in horizontal QHBoxLayout
- Each button: `setCheckable(True)`, grouped in QButtonGroup(exclusive=True)
- Emit `mood_changed = pyqtSignal(int)` when selection changes
- PyQtChart bar chart: `QBarSeries` → `QChart` → `QChartView` in a `QDialog`
- Monthly heatmap: custom `QWidget.paintEvent()` drawing day cells colored by mood

#### Feature 4: FTS5 Search

- In migrations, execute raw SQL:

  ```python
  with engine.connect() as conn:
      conn.execute(text("""
          CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts
          USING fts5(date, title, body, tags, content='entries', content_rowid='rowid')
      """))
      conn.commit()
  ```

- `EntryService.search(query)`: `SELECT entries.* FROM entries JOIN entries_fts ON entries.rowid = entries_fts.rowid WHERE entries_fts MATCH ?`
- Sidebar QLineEdit: `textChanged.connect(self._search_debounced)` with 300ms QTimer

#### Feature 5: Habit Tracker

- `HabitService.get_streak(habit_id)`: query habit_logs ordered by date DESC, count consecutive completed days

  ```python
  from datetime import date, timedelta
  def get_streak(self, habit_id: str) -> int:
      logs = session.query(HabitLog).filter_by(habit_id=habit_id, completed=1)\
                    .order_by(HabitLog.date.desc()).all()
      streak = 0
      check_date = date.today()
      for log in logs:
          log_date = date.fromisoformat(log.date)
          if log_date == check_date or log_date == check_date - timedelta(days=1):
              streak += 1
              check_date = log_date
          else:
              break
      return streak
  ```

#### Feature 6: Export

- PDF: `from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer`
  Use `ParagraphStyle` for title (larger font) and body (normal font)
- JSON backup: serialize all tables to list of dicts using `inspect(model).__dict__`
- Import: deserialize JSON, use `merge()` to upsert (preserve existing data)

#### Feature 7: Privacy/Encryption

- Encryption: `Fernet(key).encrypt(db_bytes)` applied to entire DB file
- Key derivation: `PBKDF2HMAC(SHA256, length=32, salt=salt, iterations=480000)`
- Keyring: `keyring.set_password("dailymind", "api_key", key)` / `keyring.get_password(...)`

#### Feature 8: Themes

- Load at startup: `QApplication.instance().setStyleSheet(Path(theme_path).read_text())`
- Theme switcher: signal `theme_changed(str)` → reconnect stylesheet
- `app/themes/dark.qss` must define colors for: QMainWindow, QPlainTextEdit, QSplitter, QPushButton, QListWidget, QStatusBar

---

## STEP 4: WRITE TESTS FOR THE FEATURE

After implementing a feature, write tests in its designated test file.

**Test file locations** (from feature_list.json):

- Feature 1 → `tests/test_editor.py`
- Features 2,4 → `tests/test_ai_client.py`, `tests/test_search.py`
- Feature 3,5 → `tests/test_mood.py`, `tests/test_habit.py`
- Features 6,7 → `tests/test_export.py`
- Feature 9 → `tests/test_settings.py`

**Test template for service layer tests:**

```python
import pytest
from sqlalchemy import create_engine
from app.db.models import Base


@pytest.fixture
def engine(tmp_path):
    eng = create_engine(f"sqlite:///{tmp_path}/test.db")
    Base.metadata.create_all(eng)
    return eng


def test_save_and_load_entry(engine):
    from app.services.entry_service import EntryService
    svc = EntryService(engine=engine)
    svc.save_entry(date="2025-05-26", body="Hello world")
    entry = svc.get_entry(date="2025-05-26")
    assert entry is not None
    assert entry.body == "Hello world"
    assert entry.word_count == 2


def test_search_returns_matching_entry(engine):
    from app.services.entry_service import EntryService
    svc = EntryService(engine=engine)
    svc.save_entry(date="2025-05-26", body="The quick brown fox")
    results = svc.search("quick")
    assert len(results) == 1
    assert "quick" in results[0].body
```

**Test template for Qt widget tests (pytest-qt):**

```python
def test_editor_preview_updates(qtbot):
    from PyQt6.QtWidgets import QApplication
    import sys
    app = QApplication.instance() or QApplication(sys.argv)
    from app.ui.editor_pane import EditorPane
    pane = EditorPane()
    qtbot.addWidget(pane)
    pane.show()
    pane.editor.setPlainText("# Hello")
    qtbot.wait(100)  # let event loop process
    html = pane.preview.toHtml()
    assert "Hello" in html


def test_habit_streak_calculation(engine):
    from datetime import date, timedelta
    from app.services.habit_service import HabitService
    from app.db.models import Habit, HabitLog
    from sqlalchemy.orm import Session

    svc = HabitService(engine=engine)
    with Session(engine) as s:
        habit = Habit(name="Exercise")
        s.add(habit)
        s.commit()
        habit_id = habit.id
        # Add 3 consecutive completed days
        for i in range(3):
            d = (date.today() - timedelta(days=i)).isoformat()
            s.add(HabitLog(habit_id=habit_id, date=d, completed=1))
        s.commit()

    streak = svc.get_streak(habit_id)
    assert streak == 3
```

**AI client tests use mocking (no real API calls in tests):**

```python
from unittest.mock import MagicMock, patch


def test_tagging_prompt_format():
    """Verify tagging prompt is correctly formed — no real API call."""
    from app.ai.prompts import TAGGING_SYSTEM
    from app.ai.client import build_tagging_prompt
    body = "Today I went for a run and felt great."
    messages = build_tagging_prompt(body)
    assert messages[0]["role"] == "user"
    assert body in messages[0]["content"]


def test_tag_json_validation():
    """Verify graceful fallback for malformed Claude response."""
    from app.ai.client import parse_tags_response
    # valid response
    assert parse_tags_response('{"tags": ["health", "running"]}') == ["health", "running"]
    # malformed response — must not raise
    assert parse_tags_response("not json") == []
    assert parse_tags_response('{"tags": []}') == []
```

---

## STEP 5: UPDATE feature_list.json

After implementing and testing a feature, update its status:

```json
{
  "id": 1,
  "name": "Journal Editor",
  "status": "complete",
  "test_result": "PASS — 4 tests passing"
}
```

---

## STEP 6: VERIFY WITH PYTEST AND VISUAL SCREENSHOTS

**CRITICAL: This is a PyQt6 desktop app. Do NOT use Puppeteer.**

### Layer 1: Unit and Integration Tests (always run first)

```bash
cd dailymind
source .venv/bin/activate
python3 -m pytest tests/ -v --tb=short 2>&1
```

All tests must PASS before claiming a feature is complete. Fix failures before moving on.

### Layer 2: UI Screenshot Verification (for UI features)

For headless Linux environments, use Xvfb virtual display:

```bash
# Install Xvfb if needed
which Xvfb || sudo apt-get install -y xvfb

# Start virtual display
Xvfb :99 -screen 0 1280x800x24 &
XVFB_PID=$!
export DISPLAY=:99
sleep 2

# Take screenshot of main window
python3 -c "
import sys, os
os.environ.setdefault('DISPLAY', ':99')
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
app = QApplication(sys.argv)

# Import and show the window
from app.ui.main_window import MainWindow
window = MainWindow()
window.show()
window.resize(1280, 800)

# Wait for render then screenshot
def take_shot():
    os.makedirs('verification', exist_ok=True)
    screenshot = window.grab()
    screenshot.save('verification/screenshot_main.png')
    print('Screenshot saved: verification/screenshot_main.png')
    app.quit()

QTimer.singleShot(500, take_shot)
app.exec()
"

# Kill virtual display
kill $XVFB_PID 2>/dev/null || pkill Xvfb || true

# Check screenshot was created
ls -la verification/screenshot_main.png && echo "Screenshot OK"
```

**Take targeted screenshots for each UI feature:**

```bash
# Mood chart dialog
python3 -c "
import sys, os
os.environ['DISPLAY'] = ':99'
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
app = QApplication(sys.argv)
from app.ui.mood_widget import MoodChartDialog
dialog = MoodChartDialog(mood_data=[(1,3),(2,4),(3,5),(4,2),(5,3),(6,4),(7,5)])
dialog.show()
def shot():
    dialog.grab().save('verification/screenshot_mood_chart.png')
    app.quit()
QTimer.singleShot(300, shot)
app.exec()
"
```

### Layer 3: pytest-qt Widget Tests (for specific widget behavior)

```python
# tests/test_ui_widgets.py
def test_main_window_opens(qtbot):
    from app.ui.main_window import MainWindow
    window = MainWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible()


def test_mood_selector_emits_signal(qtbot):
    from app.ui.mood_widget import MoodSelector
    widget = MoodSelector()
    qtbot.addWidget(widget)
    with qtbot.waitSignal(widget.mood_changed, timeout=1000) as blocker:
        widget.buttons[2].click()  # click 3rd emoji (mood=3)
    assert blocker.args[0] == 3


def test_editor_word_count(qtbot):
    from app.ui.editor_pane import EditorPane
    pane = EditorPane()
    qtbot.addWidget(pane)
    qtbot.keyClicks(pane.editor, "hello world foo")
    qtbot.wait(100)
    assert pane.word_count == 3
```

### Test priorities for each feature

1. Service layer tests: all business logic (DB operations, calculations, AI client building)
2. Widget behavior tests: widgets initialize, respond to input, emit correct signals
3. Visual screenshots: confirm UI appearance for presentation features

### DO

- Run pytest for all business logic
- Use pytest-qt for widget-level testing
- Take screenshots with Xvfb for visual confirmation
- Verify DB state after operations (query the DB and check)
- Mock Claude API calls in tests (never make real API calls in test suite)

### DON'T

- Use Puppeteer (it controls web browsers, not desktop Qt apps)
- Skip Layer 1 tests and go straight to screenshots
- Assume the app works just because it launches — verify the actual feature worked
- Block the UI thread with synchronous Claude API calls

---

## STEP 7: QUALITY CHECKS BEFORE FINISHING

Run these before ending the coding session:

```bash
cd dailymind
source .venv/bin/activate

# 1. All tests pass
python3 -m pytest tests/ -v --tb=short

# 2. No obvious import errors in any module
python3 -c "
import importlib, sys
modules = [
    'app.db.models', 'app.services.entry_service',
    'app.services.habit_service', 'app.ai.client',
    'app.ai.prompts', 'app.utils.export', 'app.utils.config',
]
for m in modules:
    try:
        importlib.import_module(m)
        print(f'OK: {m}')
    except Exception as e:
        print(f'FAIL: {m} — {e}')
"

# 3. Verify ANTHROPIC_API_KEY is read only from env (grep for hardcoded keys)
grep -r "sk-ant-" app/ tests/ && echo "ERROR: hardcoded API key found!" || echo "OK: no hardcoded keys"

# 4. Verify no hardcoded ~/.dailymind paths
grep -r '\.dailymind' app/ tests/ && echo "WARNING: hardcoded paths found" || echo "OK: no hardcoded paths"

# 5. Check for blocking Claude calls in UI thread (must be 0)
grep -rn "messages.create\|client.messages" app/ui/ && echo "WARNING: direct API call in UI thread!" || echo "OK: AI calls not in UI files directly"
```

### Quality bar — every session must achieve

- Zero `QApplication.exec()` crash on launch (test with Layer 2 screenshot)
- All pytest tests PASS with no skips except intentional skip decorators
- Claude API responses validated with `json.loads()` before any DB write
- All AI calls in QThread workers (never in UI slots or **init**)
- `ANTHROPIC_API_KEY` read from `os.environ` only
- No hardcoded data paths (use `platformdirs.user_data_dir("dailymind")`)

---

## STEP 8: UPDATE STATUS AND COMMIT NOTES

Update `dailymind/status.md` with:

- Which feature was implemented this session
- Test results (N tests passing)
- Screenshot file names created
- Next feature to implement

Print a summary:

```
=== Session Complete ===
Feature implemented: [name]
Tests: N passing, 0 failing
Screenshots: verification/screenshot_*.png
Next: [next pending feature from feature_list.json]
```
