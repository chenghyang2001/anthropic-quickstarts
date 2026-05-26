# App Specification: ExpenseAI — Smart Expense Tracker with AI Categorization

## Project Overview

ExpenseAI is a desktop personal finance application that combines manual expense tracking with
AI-powered receipt processing and spending analysis. Users can enter expenses manually, import
bank statement CSVs, or photograph receipts for Claude to extract and categorize automatically.
The application enforces per-category monthly budgets and alerts users when limits are approached.
Each month, Claude generates a personalized spending insight report comparing patterns across
months and flagging unusual transactions. The focus is on a clean, fast workflow for daily
expense logging without requiring cloud connectivity.

---

## Technology Stack

| Layer         | Technology                                    |
|---------------|-----------------------------------------------|
| Language      | Python 3.11+                                  |
| GUI Framework | PyQt6                                         |
| Database      | SQLite (via SQLAlchemy 2.x ORM)               |
| AI            | Anthropic Claude API (`claude-sonnet-4-6`)    |
| Data Analysis | pandas                                        |
| Charts        | matplotlib (embedded PyQt6 FigureCanvas)      |
| PDF Export    | reportlab                                     |
| Excel Export  | openpyxl                                      |
| Currency      | offline JSON cache (exchangerate-api snapshot)|
| Dependencies  | anthropic, sqlalchemy, pandas, matplotlib,    |
|               | reportlab, openpyxl, PyQt6, Pillow            |

---

## Core Features

### 1. Manual Expense Entry
- Quick-entry dialog: amount, merchant name, date (datepicker), notes
- Category dropdown (pre-populated, user-extensible)
- Keyboard shortcut: Ctrl+N opens entry dialog from anywhere in app
- Duplicate detection: warn if same merchant + amount within 24 hours
- Recurring expense templates: define monthly bills, auto-suggest on due date
- Entry validated: amount > 0, date not in future, category required

### 2. Receipt Photo Import with Claude OCR
- Import via: file dialog (jpg/png/webp) or drag-and-drop onto main window
- Image encoded to base64, sent to Claude vision API
- Claude extracts: merchant name, total amount, date, currency, line items (if visible)
- Returns structured JSON: `{merchant, amount, date, currency, items: [{name, price}]}`
- User reviews pre-filled form before saving; editable all fields
- Failed OCR shows raw Claude response for manual correction
- Receipt image stored as file path reference (not embedded in DB)

### 3. AI Auto-Categorization
- Every expense (manual or imported) auto-classified by Claude
- Categorization prompt includes merchant name + notes context
- Categories: Food, Transport, Utilities, Entertainment, Health, Shopping,
  Education, Travel, Subscriptions, Other (user can add custom)
- Confidence shown: HIGH / MEDIUM / LOW — user can override on LOW
- Categorization rules cached locally: if same merchant seen 3+ times, use cached category
- Batch re-categorize: select expenses and run Claude on all at once

### 4. Budget Setup and Overspend Alerts
- Set monthly budget per category (e.g., Food: $400, Entertainment: $100)
- Progress bars per category: green (< 75%), yellow (75-99%), red (>= 100%)
- Desktop notification when any category reaches 80% and 100% of budget
- Budget carry-over option: unused budget adds to next month (per category setting)
- Budget vs. actual comparison chart: horizontal bar chart per category
- "Projected spend" calculation: current spend / days elapsed * days in month

### 5. Monthly Spending Report
- Pie chart: spending distribution by category for selected month
- Category breakdown table: planned vs. actual, variance, % of total
- Trend lines: monthly totals over last 6 months per category (line chart)
- Top 5 merchants by total spend for the month
- Day-of-week spending heatmap: which days you spend most
- Comparison toggle: overlay previous month on all charts

### 6. Claude Monthly Insight Report
- Triggered manually ("Generate Insight") or auto on month end
- Claude receives aggregated spending data (not raw transactions for privacy)
- Insight includes:
  - Month-over-month changes by category (% and absolute)
  - Merchant frequency analysis ("8 visits to Starbucks = $62")
  - Budget adherence score (0-100)
  - 3 specific actionable recommendations
  - Anomaly flag: any expense > 2x category average
- Insight saved to monthly_summaries table, viewable in history

### 7. CSV Import from Bank Statements
- Parser supports common formats: Visa CSV, Mastercard CSV, generic 4-column
- Column mapping wizard: user maps CSV columns to fields on first import
- Saved mapping profiles per bank (reused on future imports)
- Duplicate detection: skip rows matching existing (date + amount + merchant)
- Import preview: show parsed rows before committing, highlight potential duplicates
- Error rows report: show unparseable rows with reason

### 8. Export Options
- PDF report: monthly summary with charts (reportlab, A4 layout)
- CSV: all expenses with all fields, date range filter
- Excel: pivot table by category x month (openpyxl)
- Export dialog with: date range, categories filter, include/exclude charts
- Auto-export on month end if enabled in settings

---

## Database Schema

```sql
CREATE TABLE expenses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    amount          DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    currency        TEXT NOT NULL DEFAULT 'USD',
    amount_usd      DECIMAL(10, 2),              -- converted amount for aggregation
    merchant        TEXT NOT NULL,
    category_id     INTEGER REFERENCES categories(id),
    date            DATE NOT NULL,
    notes           TEXT DEFAULT '',
    receipt_path    TEXT,                        -- path to receipt image file
    source          TEXT DEFAULT 'manual',       -- manual | receipt | csv_import
    ai_category     TEXT,                        -- Claude's suggestion
    ai_confidence   TEXT DEFAULT 'HIGH',         -- HIGH | MEDIUM | LOW
    user_overridden BOOLEAN DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,
    color       TEXT DEFAULT '#4A90E2',
    icon        TEXT DEFAULT '📂',
    is_custom   BOOLEAN DEFAULT 0,
    sort_order  INTEGER DEFAULT 99
);

CREATE TABLE budgets (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id     INTEGER NOT NULL REFERENCES categories(id),
    amount          DECIMAL(10, 2) NOT NULL,
    month           TEXT NOT NULL,              -- format: YYYY-MM
    carry_over      BOOLEAN DEFAULT 0,
    carry_over_amt  DECIMAL(10, 2) DEFAULT 0,
    UNIQUE (category_id, month)
);

CREATE TABLE monthly_summaries (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    month           TEXT NOT NULL UNIQUE,       -- format: YYYY-MM
    total_spend     DECIMAL(10, 2),
    budget_score    INTEGER,                    -- 0-100
    claude_insight  TEXT,
    generated_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## Architecture / UI Layout

```
┌─────────────────────────────────────────────────────────────┐
│  ExpenseAI                         [Ctrl+N Add]  [_ □ ×]   │
├────────────────────────────┬────────────────────────────────┤
│  CATEGORY SIDEBAR          │  MAIN TRANSACTION LIST         │
│                            │                                │
│  This Month: $1,247 / $2k  │  [May 2025 ▾] [Search...] [⚙]│
│  ────────────────────      │  ─────────────────────────     │
│  🍔 Food                   │  DATE    MERCHANT    AMT  CAT  │
│  ████████░░ $320/$400      │  May 26  Starbucks  $6.50 ☕  │
│                            │  May 25  Uber       $12.3 🚗  │
│  🚗 Transport              │  May 25  Amazon     $89.0 🛍  │
│  ██░░░░░░░░ $45/$150       │  May 24  Whole Fds  $67.2 🍔  │
│                            │  May 23  Netflix    $15.9 📺  │
│  📺 Entertainment          │  ...                           │
│  ██████████ $102/$100 ⚠️   │                                │
│                            │  ─────────────────────────     │
│  💊 Health                 │  Total this view: $191.20      │
│  ██░░░░░░░░ $30/$200       │                                │
│                            │                                │
│  [+ Add Budget]            │  [Import Receipt] [Import CSV] │
├────────────────────────────┴────────────────────────────────┤
│  AI INSIGHTS PANEL (collapsible)                            │
│  "You spent 40% more on dining this month vs 3-month avg.  │
│   8 Starbucks visits = $62. Consider brewing at home."     │
│  [Generate New Insight]         Last updated: May 26 10:31  │
└─────────────────────────────────────────────────────────────┘

MONTHLY REPORT VIEW:
┌────────────────────────────────┬────────────────────────────┐
│  PIE CHART (matplotlib)        │  CATEGORY TABLE            │
│                                │  Cat      Plan  Actual  %  │
│      🍕 Food 32%               │  Food    $400   $320  80%  │
│      🚗 Transport 12%          │  Transport $150  $45  30%  │
│      🛍 Shopping 28%           │  Entertain $100 $102 102%⚠│
│                                │  Health   $200   $30  15%  │
│                                │                            │
└────────────────────────────────┴────────────────────────────┘
```

---

## Key Interactions

### Interaction 1: Receipt Import via Claude Vision
```
User drags receipt image onto main window
  → ReceiptImportDialog opens with image preview
  → Image file read, encoded to base64
  → Claude API call (vision model):
      Prompt: "Extract from this receipt: merchant name, total amount,
               date, currency. Return JSON: {merchant, amount, date, currency}"
  → JSON parsed into form fields
  → User reviews pre-filled dialog:
      Merchant: "Whole Foods Market" (editable)
      Amount: $67.20 (editable)
      Date: 2025-05-24 (editable)
      Category: [AI suggests "Food" → shown as pre-selected]
  → User clicks Save
  → Expense row inserted, receipt_path stored
  → Category sidebar updates budget bar
```

### Interaction 2: Budget Overspend Alert
```
User saves Entertainment expense $5 (current total: $98/$100)
  → Budget check triggered after save:
      SELECT SUM(amount_usd) FROM expenses
      WHERE category_id=X AND strftime('%Y-%m', date)='2025-05'
  → Result: $103 > $100 budget
  → Desktop notification fired:
      "Entertainment budget exceeded! $103 of $100 spent this month."
  → Category sidebar bar turns red
  → Overspent categories highlighted in transaction list header
  → "Projected spend" recalculated and shown in sidebar
```

### Interaction 3: Claude Monthly Insight Generation
```
User clicks "Generate Insight" for May 2025
  → Aggregate query run (no raw transactions sent to Claude):
      {
        month: "May 2025",
        total_spend: 1247,
        categories: [{name: "Food", actual: 320, budget: 400, tx_count: 24}, ...],
        top_merchants: [{"Starbucks": 62, visits: 8}, ...],
        vs_last_month: {total_change: +12%, food_change: +40%, ...}
      }
  → Claude called with aggregated JSON + insight prompt
  → Claude returns structured insight text (400-600 words)
  → Insight stored in monthly_summaries.claude_insight
  → AI Insights Panel updated with new content
  → Budget score (0-100) extracted from Claude response, stored
```

---

## Implementation Steps

1. **Project scaffold**: PyQt6 main window, SQLAlchemy models for 4 tables, seed default
   categories (10 built-in), database migration on startup with `create_all`.

2. **Expense CRUD**: AddExpenseDialog with form validation, ExpenseListWidget (QTableWidget)
   with sort/filter, inline delete with undo, duplicate detection query.

3. **Category sidebar**: CategorySidebarWidget with QListWidget, budget progress bars
   (QProgressBar custom style), real-time update on expense add/delete.

4. **Receipt import**: ReceiptImportDialog, base64 image encoding, Claude vision API call
   with JSON response parsing, pre-fill form fields, error fallback to manual entry.

5. **CSV import**: CSVImportWizard (3 steps: file select → column mapping → preview/confirm),
   save mapping profiles to settings JSON, duplicate detection on import.

6. **Budget management**: BudgetDialog per category/month, overspend notification using
   `plyer.notification`, projected spend calculation, carry-over logic.

7. **Reports & charts**: ReportWidget with matplotlib FigureCanvas, pie chart + category
   table + trend lines, month selector, previous-month overlay toggle.

8. **Claude insight + export**: `claude_insight.py` builds aggregated payload, calls API,
   parses response; ExportDialog for PDF (reportlab) / CSV / Excel (openpyxl) generation.

---

## Success Criteria

### Functional
- Receipt OCR extracts correct merchant and amount from clean receipts in > 85% of cases
- CSV import parses 500 rows in < 2 seconds with correct duplicate detection
- Budget alerts fire within 1 second of expense save that causes overspend
- Claude monthly insight generated in < 15 seconds
- PDF export produces readable A4 report with embedded charts

### UX
- Ctrl+N opens add dialog within 100ms from any screen
- Transaction list filters/searches 5,000+ rows without lag
- Category sidebar budget bars update instantly on every save
- Receipt import dialog shows image preview at correct aspect ratio

### Technical Quality
- All monetary values stored as DECIMAL, never float (avoid rounding errors)
- pandas aggregation queries run on in-memory DataFrame from DB load (not raw SQL loops)
- Claude API calls non-blocking: QThread worker with signal/slot for UI update
- Receipt images never embedded in DB; only file path stored
- `ANTHROPIC_API_KEY` read from environment variable, never hardcoded
- Unit tests: budget overspend detection, CSV column mapping, SM-2 (shared module)
