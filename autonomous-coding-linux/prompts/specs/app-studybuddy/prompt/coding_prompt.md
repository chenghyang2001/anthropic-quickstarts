# StudyBuddy Coding Prompt

You are an autonomous coding agent implementing features for **StudyBuddy**, a PyQt6 desktop flashcard application with SM-2 spaced repetition and Claude AI integration.

**IMPORTANT: This is a PyQt6 desktop application. Do NOT use Puppeteer. Testing uses pytest + pytest-qt + Xvfb.**

---

## STEP 1: GET YOUR BEARINGS

```bash
# Read the spec and current status
cat prompts/app_spec.txt
cat studybuddy/status.md
cat studybuddy/feature_list.json

# Check test collection
cd studybuddy
source .venv/bin/activate
python3 -m pytest tests/ --collect-only 2>&1 | head -30

# Verify SM-2 algorithm is working
python3 -m pytest tests/test_sm2.py -v 2>&1

# Check DB tables
python3 -c "
from app.db import Base, get_engine
from sqlalchemy import inspect
engine = get_engine()
Base.metadata.create_all(engine)
print('Tables:', inspect(engine).get_table_names())
"

# See which files are still stubs (contain only 'pass')
grep -rl "^    pass$" app/ 2>/dev/null
```

Determine which feature to implement next by reading `feature_list.json` and finding the first feature with `"status": "pending"`. Features with lower `implementation_step` numbers come first.

---

## STEP 2: ACTIVATE ENVIRONMENT AND VERIFY DB

```bash
cd studybuddy
source .venv/bin/activate

# Run migrations (idempotent)
python3 -c "
from app.db import Base, get_engine
engine = get_engine()
Base.metadata.create_all(engine)
print('DB ready. Tables:', list(Base.metadata.tables.keys()))
"

# Check ANTHROPIC_API_KEY
python3 -c "
import os
key = os.environ.get('ANTHROPIC_API_KEY', '')
print(f'API key: {key[:8]}...' if key else 'WARNING: ANTHROPIC_API_KEY not set — AI features disabled')
"
```

---

## STEP 3: IMPLEMENT THE CURRENT FEATURE

### General Implementation Rules

**Rule 1: SM-2 updates happen only through sm2.calculate_next_review().**
Never compute next_review inline. Always call the pure function from sm2.py:

```python
from sm2 import calculate_next_review
new_interval, new_ease, new_reps, next_date = calculate_next_review(
    card.interval, card.ease_factor, card.repetitions, rating
)
card.interval = new_interval
card.ease_factor = new_ease
card.repetitions = new_reps
card.next_review = next_date
```

**Rule 2: All Claude API calls MUST run in QThread workers.**

```python
from PyQt6.QtCore import QThread, pyqtSignal
from anthropic import Anthropic
import os

class AIWorker(QThread):
    result_ready = pyqtSignal(str)
    error_occurred = pyqtSignal(str)
    chunk_ready = pyqtSignal(str)  # for streaming

    def __init__(self, prompt: str, system: str = ""):
        super().__init__()
        self.prompt = prompt
        self.system = system

    def run(self):
        try:
            api_key = os.environ.get("ANTHROPIC_API_KEY")
            if not api_key:
                self.error_occurred.emit("ANTHROPIC_API_KEY not set")
                return
            client = Anthropic(api_key=api_key)
            with client.messages.stream(
                model="claude-sonnet-4-6",
                max_tokens=1024,
                system=self.system,
                messages=[{"role": "user", "content": self.prompt}],
            ) as stream:
                full_text = ""
                for text in stream.text_stream:
                    full_text += text
                    self.chunk_ready.emit(text)
                self.result_ready.emit(full_text)
        except Exception as e:
            self.error_occurred.emit(str(e))
```

**Rule 3: SQLAlchemy sessions use context manager.**

```python
from sqlalchemy.orm import Session
with Session(engine) as session:
    card = session.get(Card, card_id)
    card.interval = new_interval
    session.commit()
# Session auto-closed
```

**Rule 4: API key ONLY from os.environ.**

```python
api_key = os.environ.get("ANTHROPIC_API_KEY")
if not api_key:
    # Show status bar message, disable AI buttons — do NOT raise to user
    self.status_bar.showMessage("AI features disabled: ANTHROPIC_API_KEY not set")
    return
```

**Rule 5: Validate Claude JSON before DB write.**

```python
import json

def parse_cards_response(response_text: str) -> list[dict]:
    """Parse Claude's card generation response. Returns [] on any error."""
    try:
        data = json.loads(response_text)
        if not isinstance(data, list):
            return []
        valid = []
        for item in data:
            if isinstance(item, dict) and "question" in item and "answer" in item:
                valid.append({
                    "question": str(item["question"])[:1000],
                    "answer": str(item["answer"])[:500],
                    "type": item.get("type", "basic") if item.get("type") in ("basic", "cloze") else "basic",
                })
        return valid
    except (json.JSONDecodeError, TypeError, AttributeError):
        return []
```

**Rule 6: Use platformdirs for ALL data paths.**

```python
import platformdirs
DATA_DIR = Path(platformdirs.user_data_dir("studybuddy"))
EXPORT_DIR = Path.home() / "Documents" / "StudyBuddy" / "exports"
EXPORT_DIR.mkdir(parents=True, exist_ok=True)
```

### Feature-Specific Implementation Guides

#### Feature 6: Deck Organization (implement first — no AI dependency)

- `app/ui/deck_sidebar.py`: QTreeWidget, each item stores deck.id in Qt.ItemDataRole.UserRole
- Build tree recursively: root decks (parent_id IS NULL) as top-level, children nested
- Context menu: QMenu with actions for Add Child Deck, Rename, Change Color, Delete
- Color swatch: subclass QStyledItemDelegate, paint colored rectangle left of text
- Signal: `deck_selected = pyqtSignal(int)` emitted on currentItemChanged
- Card list loads cards for selected deck; filtering by tag uses `card.tags.contains(tag)`
- Bulk operations: `table.selectionModel().selectedRows()` → list of card IDs → batch UPDATE

#### Feature 1: Note Import and AI Flashcard Generation

- `app/services/import_service.py`:

  ```python
  import pdfplumber, markdown2, re

  def extract_text_pdf(path: str) -> str:
      with pdfplumber.open(path) as pdf:
          return "\n\n".join(page.extract_text() or "" for page in pdf.pages)

  def extract_text_markdown(path: str) -> str:
      raw = Path(path).read_text(encoding="utf-8")
      html = markdown2.markdown(raw)
      # Strip HTML tags for plain text
      return re.sub(r"<[^>]+>", " ", html)

  def extract_text_plain(path: str) -> str:
      return Path(path).read_text(encoding="utf-8")

  def chunk_text(text: str, max_chars: int = 2000) -> list[str]:
      """Split on double-newline (paragraph) boundaries."""
      paragraphs = re.split(r"\n\n+", text.strip())
      chunks, current = [], ""
      for para in paragraphs:
          if len(current) + len(para) > max_chars and current:
              chunks.append(current.strip())
              current = para
          else:
              current += "\n\n" + para
      if current.strip():
          chunks.append(current.strip())
      return [c for c in chunks if len(c) > 50]  # skip tiny chunks
  ```

- `app/services/claude_client.py`:

  ```python
  CARD_GEN_SYSTEM = """You are an expert flashcard creator. Generate Q&A flashcard pairs
  from the provided text. Return ONLY a valid JSON array with no markdown wrapping:
  [{"question": "...", "answer": "...", "type": "basic"}]
  Rules:
  - Generate 2-5 cards per text chunk
  - Focus on key facts, definitions, concepts, relationships
  - Questions should be specific and unambiguous
  - Answers should be concise (1-3 sentences)
  - Use "cloze" type only if a fill-in-the-blank format fits naturally"""

  EXPLANATION_SYSTEM = """You are a patient tutor helping a student understand why they
  got a flashcard wrong. Be concise (max 150 words total). Structure your response:
  1) Root cause: Why this concept is commonly confused
  2) Mnemonic: A memorable trick to remember the answer
  3) Example: A concrete real-world example"""
  ```

- `app/ui/import_dialog.py`: QDialog with QStackedWidget (5 pages):
  - Page 0: QLabel + QPushButton "Browse" + drag-drop area
  - Page 1: QListWidget showing text chunks (preview)
  - Page 2: QProgressBar + QLabel "Generating cards..." (AIWorker runs here)
  - Page 3: QTableWidget (editable) showing generated cards
  - Page 4: QComboBox (select deck) + QPushButton "Save N Cards"

#### Feature 3: Card Types

- Cloze storage: front = "The {{c1::mitochondria}} is the powerhouse of the cell"
- Cloze display in study mode: replace `{{c1::...}}` with `____` using regex
- Cloze answer: extract the hidden text from `{{c1::(...)}}`

  ```python
  import re
  def render_cloze_front(front: str) -> str:
      return re.sub(r"\{\{c\d+::([^}]+)\}\}", "____", front)
  def extract_cloze_answer(front: str) -> str:
      match = re.search(r"\{\{c\d+::([^}]+)\}\}", front)
      return match.group(1) if match else ""
  ```

- Bulk conversion: select cards → right-click → "Convert to Basic/Cloze"
  Basic→Cloze: wrap the answer word(s) in {{c1::}} if found in front text

#### Feature 4: Study Session UI

- `app/ui/study_window.py`: QWidget with `setWindowFlags(Qt.WindowType.Window)`
  Call `showFullScreen()` when opening
- Study queue SQL:

  ```python
  from datetime import date
  from sqlalchemy import and_
  due_cards = session.query(Card).filter(
      and_(
          Card.deck_id == deck_id,
          Card.next_review <= date.today().isoformat(),
          Card.suspended == False,
      )
  ).order_by(Card.next_review).all()
  ```

- Card flip: QStackedWidget with front_widget and back_widget
  Or: QPropertyAnimation on a QFrame's maximumHeight (0 → natural height)
- Pre-rating state snapshot for undo:

  ```python
  self._last_card_state = {
      "card_id": card.id, "interval": card.interval,
      "ease_factor": card.ease_factor, "repetitions": card.repetitions,
      "next_review": card.next_review,
  }
  ```

- Session summary: calculate time as (ended_at - started_at).total_seconds()

#### Feature 5: AI Explanation

- Rate-limit counter: `self._explanation_count = 0` on session start
- Before AI call: `if self._explanation_count >= 10: show_limit_message(); return`
- Check cache first:

  ```python
  if card.ai_explanation:
      self.explanation_panel.setText(card.ai_explanation)
      return  # no API call needed
  ```

- After successful response: `card.ai_explanation = response; session.commit()`
- ExplanationPanel: QFrame with QTextBrowser, appears via QPropertyAnimation height 0→180

#### Feature 7: Statistics Dashboard

- Embed matplotlib in PyQt6:

  ```python
  from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
  from matplotlib.figure import Figure

  class RetentionChart(FigureCanvas):
      def __init__(self):
          self.figure = Figure(figsize=(8, 3), tight_layout=True)
          super().__init__(self.figure)
          self.ax = self.figure.add_subplot(111)

      def update_data(self, dates: list, retention_rates: list):
          self.ax.clear()
          self.ax.plot(dates, retention_rates, marker="o", color="#4A90E2")
          self.ax.set_ylim(0, 100)
          self.ax.set_ylabel("Retention %")
          self.ax.set_title("30-Day Retention Rate")
          self.figure.autofmt_xdate()
          self.draw()
  ```

- Retention rate query:

  ```python
  from sqlalchemy import func
  total = session.query(func.count(CardReview.id)).filter(CardReview.session_id == session_id).scalar()
  correct = session.query(func.count(CardReview.id)).filter(
      CardReview.session_id == session_id, CardReview.rating >= 3
  ).scalar()
  retention = (correct / total * 100) if total > 0 else 0.0
  ```

- Streak heatmap: custom `paintEvent(QPainter)` — 7 columns (Mon-Sun) × rows (weeks)
  Color scale: 0→lightgray, 1-3→"#c6e48b", 4-7→"#40c463", 8+→"#216e39"

#### Feature 8: Anki Export

- `app/services/export_service.py`:

  ```python
  import genanki, random

  def export_anki(deck_ids: list[int], engine, output_path: str):
      BASIC_MODEL = genanki.Model(
          random.randrange(1 << 30, 1 << 31),
          "StudyBuddy Basic",
          fields=[{"name": "Front"}, {"name": "Back"}],
          templates=[{"name": "Card 1",
                      "qfmt": "{{Front}}",
                      "afmt": "{{FrontSide}}<hr id=answer>{{Back}}"}],
      )
      CLOZE_MODEL = genanki.Model(
          random.randrange(1 << 30, 1 << 31),
          "StudyBuddy Cloze",
          fields=[{"name": "Text"}, {"name": "Extra"}],
          templates=[{"name": "Cloze 1",
                      "qfmt": "{{cloze:Text}}",
                      "afmt": "{{cloze:Text}}<br>{{Extra}}"}],
          model_type=genanki.Model.CLOZE,
      )
      package_decks = []
      with Session(engine) as s:
          for deck_id in deck_ids:
              deck = s.get(Deck, deck_id)
              anki_deck = genanki.Deck(deck_id + 1000000000, deck.name)
              cards = s.query(Card).filter_by(deck_id=deck_id, suspended=False).all()
              for card in cards:
                  if card.card_type == "cloze":
                      note = genanki.Note(model=CLOZE_MODEL, fields=[card.front, card.back])
                  else:
                      note = genanki.Note(model=BASIC_MODEL, fields=[card.front, card.back])
                  anki_deck.add_note(note)
              package_decks.append(anki_deck)
      genanki.Package(package_decks).write_to_file(output_path)
  ```

---

## STEP 4: WRITE TESTS FOR THE FEATURE

**Test locations** (from feature_list.json):

- Features 1, 5, 8 → `tests/test_import.py`
- Feature 2 → `tests/test_sm2.py` (already written)
- Features 3, 6, 7 → `tests/test_db.py`
- Feature 4 → `tests/test_sm2.py` (SM-2 integration)

**Service layer test template:**

```python
@pytest.fixture
def engine(tmp_path):
    from app.db import Base
    eng = create_engine(f"sqlite:///{tmp_path}/test.db")
    Base.metadata.create_all(eng)
    return eng


def test_import_pdf_extracts_text(tmp_path):
    """PDF extraction should return non-empty string."""
    from app.services.import_service import extract_text_plain
    test_file = tmp_path / "test.txt"
    test_file.write_text("Hello world\n\nSecond paragraph.")
    result = extract_text_plain(str(test_file))
    assert "Hello world" in result


def test_chunk_text_splits_on_paragraphs():
    """chunk_text must split on double newlines."""
    from app.services.import_service import chunk_text
    text = "Para one.\n\nPara two is longer and has more content here.\n\nPara three."
    chunks = chunk_text(text, max_chars=50)
    assert len(chunks) >= 2


def test_parse_cards_valid_json():
    """parse_cards_response returns list of dicts for valid JSON."""
    from app.services.claude_client import parse_cards_response
    raw = '[{"question": "What is Python?", "answer": "A programming language.", "type": "basic"}]'
    cards = parse_cards_response(raw)
    assert len(cards) == 1
    assert cards[0]["question"] == "What is Python?"


def test_parse_cards_invalid_json_returns_empty():
    """parse_cards_response returns [] for malformed JSON — no exception."""
    from app.services.claude_client import parse_cards_response
    assert parse_cards_response("not json at all") == []
    assert parse_cards_response('{"cards": []}') == []  # wrong structure
    assert parse_cards_response("") == []


def test_anki_export_creates_file(tmp_path, engine):
    """Anki export should produce a non-empty .apkg file."""
    from app.services.export_service import export_anki
    from app.db import Deck, Card
    from sqlalchemy.orm import Session

    with Session(engine) as s:
        deck = Deck(name="Test Deck")
        s.add(deck)
        s.flush()
        s.add(Card(deck_id=deck.id, front="Q?", back="A."))
        s.commit()
        deck_id = deck.id

    output = str(tmp_path / "export.apkg")
    export_anki([deck_id], engine, output)
    assert Path(output).exists()
    assert Path(output).stat().st_size > 0
```

**pytest-qt widget tests:**

```python
def test_deck_sidebar_shows_decks(qtbot, engine):
    """Deck sidebar populates tree from DB."""
    from app.db import Deck
    from app.ui.deck_sidebar import DeckSidebar
    from sqlalchemy.orm import Session

    with Session(engine) as s:
        s.add(Deck(name="Python"))
        s.add(Deck(name="Math"))
        s.commit()

    sidebar = DeckSidebar(engine=engine)
    qtbot.addWidget(sidebar)
    sidebar.refresh()
    assert sidebar.topLevelItemCount() == 2


def test_study_window_flip_shows_back(qtbot, engine):
    """Space key during study should reveal card back."""
    from app.db import Deck, Card
    from app.ui.study_window import StudyWindow
    from sqlalchemy.orm import Session
    from PyQt6.QtCore import Qt

    with Session(engine) as s:
        deck = Deck(name="Test")
        s.add(deck)
        s.flush()
        s.add(Card(deck_id=deck.id, front="Question?", back="Answer!"))
        s.commit()
        deck_id = deck.id

    window = StudyWindow(deck_id=deck_id, engine=engine)
    qtbot.addWidget(window)
    window.show()
    assert not window.is_flipped
    qtbot.keyPress(window, Qt.Key.Key_Space)
    qtbot.wait(100)
    assert window.is_flipped
```

---

## STEP 5: UPDATE feature_list.json

After implementing and testing a feature, update its status:

```json
{
  "id": 6,
  "name": "Deck Organization",
  "status": "complete",
  "test_result": "PASS — 5 tests passing"
}
```

---

## STEP 6: VERIFY WITH PYTEST AND VISUAL SCREENSHOTS

**CRITICAL: This is a PyQt6 desktop app. Do NOT use Puppeteer.**

### Layer 1: Unit and Integration Tests (always run first)

```bash
cd studybuddy
source .venv/bin/activate
python3 -m pytest tests/ -v --tb=short 2>&1
```

All tests must PASS. Fix failures before moving to Layer 2.

### Layer 2: UI Screenshot Verification

```bash
# Install Xvfb if needed
which Xvfb || sudo apt-get install -y xvfb

# Start virtual display
Xvfb :99 -screen 0 1280x800x24 &
XVFB_PID=$!
export DISPLAY=:99
sleep 2

# Screenshot: main window
python3 -c "
import sys, os
os.environ['DISPLAY'] = ':99'
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
app = QApplication(sys.argv)
from app.ui.main_window import MainWindow
window = MainWindow()
window.show()
window.resize(1280, 800)
def take_shot():
    os.makedirs('verification', exist_ok=True)
    window.grab().save('verification/screenshot_main.png')
    print('Screenshot: verification/screenshot_main.png')
    app.quit()
QTimer.singleShot(500, take_shot)
app.exec()
"

# Screenshot: study window (if implemented)
python3 -c "
import sys, os
os.environ['DISPLAY'] = ':99'
from PyQt6.QtWidgets import QApplication
from PyQt6.QtCore import QTimer
from app.db import Base, Deck, Card, get_engine
from sqlalchemy.orm import Session
import tempfile

app = QApplication(sys.argv)

# Set up test data
engine = get_engine('/tmp/studybuddy_screenshot_test.db')
Base.metadata.create_all(engine)
with Session(engine) as s:
    deck = s.query(Deck).first() or Deck(name='Demo Deck')
    if not deck.id:
        s.add(deck)
        s.flush()
        s.add(Card(deck_id=deck.id,
                   front='What is spaced repetition?',
                   back='A learning technique that increases review intervals over time.'))
        s.commit()
    deck_id = deck.id

from app.ui.study_window import StudyWindow
window = StudyWindow(deck_id=deck_id, engine=engine)
window.show()

def take_shot():
    os.makedirs('verification', exist_ok=True)
    window.grab().save('verification/screenshot_study.png')
    print('Screenshot: verification/screenshot_study.png')
    app.quit()
QTimer.singleShot(500, take_shot)
app.exec()
"

# Kill virtual display
kill $XVFB_PID 2>/dev/null || pkill Xvfb || true

ls -la verification/*.png 2>/dev/null && echo "Screenshots OK" || echo "No screenshots generated"
```

### Layer 3: pytest-qt Widget Tests

```python
# tests/test_ui.py
def test_main_window_opens(qtbot):
    from app.ui.main_window import MainWindow
    window = MainWindow()
    qtbot.addWidget(window)
    window.show()
    assert window.isVisible()


def test_card_list_populates(qtbot, engine):
    from app.db import Deck, Card
    from app.ui.card_list import CardListWidget
    from sqlalchemy.orm import Session

    with Session(engine) as s:
        deck = Deck(name="Test")
        s.add(deck)
        s.flush()
        for i in range(3):
            s.add(Card(deck_id=deck.id, front=f"Q{i}", back=f"A{i}"))
        s.commit()
        deck_id = deck.id

    widget = CardListWidget(engine=engine)
    qtbot.addWidget(widget)
    widget.load_deck(deck_id)
    assert widget.rowCount() == 3


def test_import_dialog_opens(qtbot):
    from app.ui.import_dialog import ImportDialog
    dialog = ImportDialog(engine=None)
    qtbot.addWidget(dialog)
    dialog.show()
    assert dialog.isVisible()
```

### Test priorities

1. Service layer (DB queries, SM-2, import, export) — must all pass
2. Widget initialization and basic interaction — verify with pytest-qt
3. Visual screenshots — confirm UI renders correctly end-to-end

### DO

- Run all pytest tests before claiming a feature is done
- Use pytest-qt for widget-level testing
- Take screenshots with Xvfb for visual confirmation
- Mock Claude API calls in tests (never hit real API in test suite)
- Verify DB state changes after operations

### DON'T

- Use Puppeteer (it controls web browsers, not PyQt6 desktop apps)
- Skip Layer 1 and go straight to screenshots
- Make real Claude API calls in the test suite
- Block the UI thread with synchronous anthropic.messages.create() calls

---

## STEP 7: QUALITY CHECKS BEFORE FINISHING

```bash
cd studybuddy
source .venv/bin/activate

# 1. All tests pass
python3 -m pytest tests/ -v --tb=short

# 2. SM-2 regression check (always)
python3 -m pytest tests/test_sm2.py -v

# 3. No hardcoded API keys
grep -r "sk-ant-" app/ tests/ && echo "ERROR: hardcoded API key!" || echo "OK: no hardcoded keys"

# 4. No hardcoded data paths
grep -rn "\.local/share/studybuddy\|studybuddy\.db" app/ tests/ \
  && echo "WARNING: hardcoded paths found" || echo "OK: no hardcoded paths"

# 5. No blocking Claude calls in UI thread
grep -rn "messages\.create\|Anthropic()" app/ui/ \
  && echo "WARNING: direct API call in UI file!" || echo "OK: AI calls not in UI files directly"

# 6. Verify imports for all implemented modules
python3 -c "
import importlib
modules = [
    'app.db', 'sm2',
    'app.services.import_service',
    'app.services.claude_client',
    'app.services.export_service',
]
for m in modules:
    try:
        importlib.import_module(m)
        print(f'OK: {m}')
    except Exception as e:
        print(f'FAIL: {m} — {e}')
"
```

### Quality bar — every session must achieve

- Zero `QApplication.exec()` crash on launch
- All pytest tests PASS (zero failures, zero errors)
- SM-2 `calculate_next_review()` called for every card rating (never inline math)
- All Claude JSON responses validated with `parse_cards_response()` before DB write
- All AI calls in QThread workers — zero blocking calls in UI thread or `__init__`
- `ANTHROPIC_API_KEY` read from `os.environ` only — never from hardcoded string
- All data paths use `platformdirs.user_data_dir("studybuddy")` — never hardcoded

---

## STEP 8: UPDATE STATUS AND PRINT SUMMARY

Update `studybuddy/status.md` with:

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
