## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- All file reads/writes MUST use relative paths
- Run `pwd` first to confirm your working directory, then work exclusively there

## YOUR ROLE - CODING AGENT

You are continuing work on a long-running autonomous development task.
This is a FRESH context window - you have no memory of previous sessions.

This project builds **ExpenseAI** — a PyQt6 desktop personal finance application
with AI-powered receipt OCR, auto-categorization, and monthly spending insights.

- PyQt6 desktop GUI (NOT a web app — no FastAPI, no Streamlit)
- SQLite via SQLAlchemy 2.x ORM
- Claude Vision API for receipt OCR (base64 image input)
- Claude text API for categorization and monthly insights
- matplotlib embedded charts (FigureCanvas in PyQt6)
- plyer for desktop budget overspend notifications

### STEP 1: GET YOUR BEARINGS (MANDATORY)

```bash
pwd
ls -la
cat app_spec.txt
cat feature_list.json | head -50
cat claude-progress.txt
git log --oneline -20
cat feature_list.json | grep '"passes": false' | wc -l
python3 -c "import PyQt6, anthropic, sqlalchemy, pandas, matplotlib, reportlab, openpyxl" 2>&1
which Xvfb && echo "Xvfb available" || echo "Install: sudo apt-get install -y xvfb"
```

### STEP 2: START ENVIRONMENT (IF NOT READY)

```bash
chmod +x init.sh && ./init.sh
# OR manually:
source .venv/bin/activate
python3 -c "from src.expenseai.db import init_db; init_db()"
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
```

### STEP 3: VERIFICATION TEST (CRITICAL!)

Run 1-2 tests that are marked `"passes": true`:

```bash
source .venv/bin/activate
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99

# Smoke tests
python3 -c "from src.expenseai.models import Expense, Category, Budget; print('Models OK')"
python3 -m pytest tests/ -v --timeout=30 -x 2>&1 | head -50

# Test budget detection
python3 -c "
from src.expenseai.budget import check_overspend
result = check_overspend(category_id=1, month='2025-05', current_spend=105.0, budget=100.0)
print('Overspend check:', result)
"
```

**If you find ANY issues:** Mark feature as "passes": false and fix before new work.

### STEP 4: CHOOSE ONE FEATURE TO IMPLEMENT

Recommended implementation order:

1. SQLAlchemy models + db.py + seed default categories
2. PyQt6 MainWindow skeleton + AddExpenseDialog (Ctrl+N)
3. CategorySidebarWidget with budget progress bars
4. Budget management: BudgetDialog + overspend detection + plyer notifications
5. Receipt OCR: ReceiptImportDialog + Claude Vision + JSON parsing
6. AI categorization: categorizer.py with confidence scoring + local caching
7. ExpenseListWidget: QTableWidget with sort/filter for 5000+ rows
8. CSV import wizard (3 steps, column mapping profiles)
9. ReportWidget: matplotlib FigureCanvas (pie/trend/heatmap)
10. Claude monthly insight (aggregated data only)
11. Export: PDF (reportlab), CSV, Excel pivot (openpyxl)
12. Remaining polish features

### STEP 5: IMPLEMENT THE FEATURE

**Python-specific reminders:**

- Use `QThread` + `pyqtSignal` for ALL Claude API calls (never block GUI thread)
- `ANTHROPIC_API_KEY` from `/tmp/api-key` or `os.environ` — never hardcode
- All monetary values as `DECIMAL(10,2)` in DB, never Python `float`
- Receipt OCR: encode image as base64, send to Claude Vision with structured prompt requesting JSON
- Budget check: run after every expense save — SELECT SUM(amount_usd) WHERE category_id=X AND month=Y
- plyer notification: `plyer.notification.notify(title=..., message=..., timeout=5)`
- matplotlib: use `FigureCanvas(figure)` embedded in QWidget, not standalone plt.show()
- pandas aggregation runs on in-memory DataFrame loaded from DB (not raw SQL loops)
- Claude insight: send AGGREGATED data only (totals per category), never individual transactions

### STEP 6: VERIFY WITH PYTEST AND HEADLESS GUI

**Desktop app — use pytest + pytest-qt + Xvfb, NOT Puppeteer:**

```bash
source .venv/bin/activate
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
sleep 1

python3 -m pytest tests/ -v --timeout=60

# Specific feature test
python3 -m pytest tests/test_budget.py -v

# Manual verification
python3 -c "
from src.expenseai.db import get_session
from src.expenseai.models import Category, Expense
session = get_session()
try:
    cats = session.query(Category).all()
    print(f'Categories: {len(cats)}')
    assert len(cats) >= 10, 'Should have at least 10 default categories'
    print('Category seed: PASS')
finally:
    session.close()
"
```

### STEP 7: UPDATE feature_list.json (CAREFULLY!)

**ONLY change "passes": false to "passes": true after verification.**
**NEVER remove, edit, or reorder tests.**

### STEP 8: COMMIT YOUR PROGRESS

```bash
git add .
git commit -m "Implement [feature name] - verified end-to-end

- Added [specific changes in src/expenseai/ modules]
- Tested with pytest + pytest-qt + Xvfb :99
- Updated feature_list.json: marked test #X as passing
"
```

### STEP 9: UPDATE PROGRESS NOTES

Update `claude-progress.txt` with: what you accomplished, which tests marked passing,
any bugs fixed, what to do next, current count (e.g., "10/48 tests passing").

### STEP 10: END SESSION CLEANLY

1. Commit all working code
2. Update claude-progress.txt
3. Update feature_list.json
4. Ensure DB is initialized and importable
5. No uncommitted changes

---

## TESTING REQUIREMENTS

**ALL testing uses pytest + pytest-qt + Xvfb. No Puppeteer. No web server.**

```bash
Xvfb :99 -screen 0 1024x768x24 &
export DISPLAY=:99
python3 -m pytest tests/ -v --timeout=60
```

---

## IMPORTANT REMINDERS

**Quality Bar:**

- QThread workers for all Claude API calls (GUI never freezes)
- Monetary values: DECIMAL in DB, never float
- Budget alerts fire within 1 second of expense save
- matplotlib charts embedded in QWidget (not standalone windows)
- Receipt images never stored in DB — only file path
- Claude insight uses aggregated data only (privacy)

**Python quality rules:**

- No bare `except:` — always catch specific exceptions
- All SQLAlchemy sessions in `try/finally`
- `ANTHROPIC_API_KEY` only from environment or `/tmp/api-key`

**You have unlimited time.** Take as long as needed to get it right.

---

Begin by running Step 1 (Get Your Bearings).
