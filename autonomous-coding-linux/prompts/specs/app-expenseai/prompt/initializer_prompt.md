## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- DO NOT run `git init` — a git repository has already been initialized in your cwd
- All file reads/writes MUST use relative paths
- Run `pwd` first to confirm your working directory, then work exclusively there

## YOUR ROLE - INITIALIZER AGENT (Session 1 of Many)

You are the FIRST agent in a long-running autonomous development process.
Your job is to set up the foundation for all future coding agents.

This project builds **ExpenseAI** — a PyQt6 desktop personal finance application
combining manual expense tracking with AI-powered receipt processing and analysis.
Tech stack: Python 3.11+, PyQt6, SQLite/SQLAlchemy 2.x, Anthropic Claude API,
pandas, matplotlib (embedded FigureCanvas), reportlab, openpyxl, Pillow, plyer.

### FIRST: Read the Project Specification

Start by reading `app_spec.txt` in your working directory. Read it carefully before proceeding.

### CRITICAL FIRST TASK: Create feature_list.json

Based on `app_spec.txt`, create a file called `feature_list.json` with `__NUM_FEATURES__` detailed
end-to-end test cases. This file is the single source of truth for what needs to be built.

**Format:**

```json
[
  {
    "category": "functional",
    "description": "Brief description of the feature and what this test verifies",
    "steps": [
      "Step 1: Run pytest test command",
      "Step 2: Verify expected output",
      "Step 3: Check DB state"
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
- Order features by priority: expense CRUD first, then receipt OCR, budget alerts, charts, export
- ALL tests start with "passes": false
- Cover every feature in the spec exhaustively

**Testing Approach:**

ExpenseAI is a **PyQt6 desktop GUI application**. There is NO web server.
All testing uses:

- `pytest` + `pytest-qt` for GUI component testing
- `Xvfb :99` for headless display
- Direct unit tests for DB models, Claude integration, CSV parsing
- Launch headless: `Xvfb :99 & DISPLAY=:99 python -m pytest tests/ -v`
- **Never use Puppeteer** — this is not a web app

**CRITICAL INSTRUCTION:**
IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS.
Features can ONLY be marked as passing (change "passes": false to "passes": true).

### SECOND TASK: Create init.sh

Create a script called `init.sh` that future agents can use to set up the environment:

1. Create and activate Python virtual environment (if not exists)
2. Install all required Python dependencies (`pip install -r requirements.txt`)
3. Initialize SQLite database (SQLAlchemy `create_all` or Alembic `upgrade head`)
4. Start Xvfb on display :99 for headless GUI testing
5. Run smoke test: `DISPLAY=:99 python -c "import PyQt6, anthropic, matplotlib; print('All imports OK')"`
6. Print helpful info:
   - Launch app: `DISPLAY=:99 python -m expenseai`
   - Run tests: `DISPLAY=:99 python -m pytest tests/ -v`
   - API key: `export ANTHROPIC_API_KEY=$(cat /tmp/api-key)`

Also create `requirements.txt` with all Python dependencies:
PyQt6, anthropic, sqlalchemy, pandas, matplotlib, reportlab, openpyxl,
Pillow, plyer, pytest, pytest-qt

### THIRD TASK: Initialize Git

Create first commit with: feature_list.json, init.sh, requirements.txt, README.md

Commit message: "Initial setup: feature_list.json, init.sh, requirements.txt, and project structure"

### FOURTH TASK: Create Project Structure

```
src/expenseai/
  __init__.py
  main.py              — PyQt6 QApplication + MainWindow entry point
  models.py            — SQLAlchemy ORM: Expense, Category, Budget, MonthlySummary
  db.py                — SQLite engine + session factory
  categorizer.py       — Claude auto-categorization, confidence scoring, caching
  receipt_ocr.py       — Claude Vision API, base64 encoding, JSON parsing
  insight.py           — Claude monthly insight generation, aggregation queries
  exporter.py          — PDF (reportlab), CSV, Excel (openpyxl) export
  csv_importer.py      — CSVImportWizard, column mapping profiles, duplicate detection
  budget.py            — Budget management, overspend detection, plyer notifications
  ui/
    __init__.py
    main_window.py     — MainWindow layout
    expense_list.py    — ExpenseListWidget (QTableWidget)
    category_sidebar.py — CategorySidebarWidget with budget progress bars
    add_expense.py     — AddExpenseDialog (Ctrl+N)
    receipt_dialog.py  — ReceiptImportDialog
    budget_dialog.py   — BudgetDialog
    report_widget.py   — ReportWidget (matplotlib FigureCanvas)
    csv_wizard.py      — CSVImportWizard
tests/
  conftest.py          — pytest-qt QApplication fixture, temp DB setup
  test_models.py       — SQLAlchemy model tests
  test_categorizer.py  — AI categorization tests (mock Claude)
  test_receipt_ocr.py  — Receipt OCR tests (mock Claude Vision)
  test_budget.py       — Budget overspend detection tests
  test_csv_import.py   — CSV parsing and duplicate detection tests
  test_ui.py           — Basic PyQt6 widget smoke tests
sample_receipts/
  receipt_sample.jpg   — Sample receipt image for testing
```

### OPTIONAL: Start Implementation

If time remaining, implement:

1. `src/expenseai/models.py` — SQLAlchemy ORM models (4 tables + seed 10 default categories)
2. `src/expenseai/db.py` — engine, session factory, create_all()
3. Basic PyQt6 MainWindow skeleton in `src/expenseai/main.py`
4. `src/expenseai/budget.py` — Budget overspend detection logic

**API Key setup:**

```python
import os
key_path = "/tmp/api-key"
if os.path.exists(key_path):
    with open(key_path) as f:
        os.environ["ANTHROPIC_API_KEY"] = f.read().strip()
```

### ENDING THIS SESSION

1. Commit all work
2. Create `claude-progress.txt` with summary
3. Ensure feature_list.json is complete
4. Leave environment in clean, working state

---

**Remember:** You have unlimited time. Focus on quality over speed.
