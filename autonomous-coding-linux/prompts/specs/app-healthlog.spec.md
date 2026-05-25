# App Specification: HealthLog

## Project Overview

HealthLog is a personal health tracker that runs entirely on the local machine. Users log
meals, exercise, sleep, weight, mood, and water intake through either a Streamlit web UI or
a quick-entry CLI. Claude generates weekly AI health reports, identifying patterns like
"sleep under 7 hours correlates with lower mood scores." All data is stored in SQLite —
no cloud sync, no account required.

**Primary audience:** Health-conscious individuals who want a personal data journal with
AI insight without subscribing to a fitness app or sharing their health data with third parties.

---

## Technology Stack

| Layer         | Technology                                          |
|---------------|-----------------------------------------------------|
| Web UI        | Streamlit 1.35 (multi-page app)                    |
| CLI           | Python + Click 8                                    |
| AI reports    | Anthropic Claude (claude-sonnet-4-6)               |
| Database      | SQLite (via SQLAlchemy 2.0)                         |
| Data analysis | pandas 2.2                                          |
| Charts        | Plotly 5.22                                         |
| Notifications | plyer 2.1 (cross-platform desktop notifications)   |
| Export        | pandas CSV export + fpdf2 for PDF                  |

---

## Core Features

### 1. Multi-Category Logging (Web UI)
- Meals: name, calories, protein (g), carbs (g), fat (g), meal type (breakfast/lunch/dinner/snack)
- Exercise: type (cardio/strength/yoga/other), duration (minutes), intensity (1-10), calories burned
- Sleep: bedtime, wake time, quality rating (1-5), notes (dreams, interruptions)
- Weight: value (kg/lbs, configurable), body fat % (optional)
- Mood: score (1-10), energy level (1-10), free-text notes
- Water intake: glasses/day (quick increment button in UI)

### 2. Quick CLI Logging
- `healthlog meal "oatmeal 400cal" --time breakfast` — fast entry with natural language parsing
- `healthlog sleep 7.5 --quality 4` — log last night's sleep in seconds
- `healthlog weight 72.5` — weight entry with automatic timestamp
- `healthlog mood 7 --energy 8 --note "productive day"` — mood log
- `healthlog water +1` — increment water count for today
- Claude parses ambiguous meal descriptions to extract macros when not provided

### 3. Weekly AI Health Report
- Every Sunday at 8am (configurable), Claude generates a structured report
- Report covers: sleep average, exercise frequency, calorie trends, mood patterns
- Pattern detection: "Your mood scores averaged 6.1 on days with < 7h sleep vs. 7.8 on ≥ 7h days"
- Personalized suggestions: "Consider adding 15 minutes of cardio on Tuesdays — you skipped 3 of 4"
- Report stored in `ai_reports` table; accessible in Reports page
- On-demand: "Generate report for this week" button in UI

### 4. Trend Charts (Plotly)
- Weight chart: line chart with 7-day moving average, goal line overlay
- Sleep chart: bar chart (hours) with quality color-coding (green/yellow/red)
- Mood & energy: dual-axis line chart
- Calories: stacked bar (by meal type) with BMR baseline marker
- Exercise frequency: weekly heatmap (GitHub-style)
- All charts interactive: zoom, hover tooltips, date range slider

### 5. Goal Tracking
- Create goals: "Sleep ≥ 7 hours for 21 consecutive days"
- Goal types: streak (consecutive days), cumulative (total over period), average
- Progress bar in Dashboard for each active goal
- Notification when goal achieved (plyer desktop notification)
- Goal history: completed, failed, in-progress

### 6. Export Options
- CSV export for doctor visits: all data or per-category, date range selectable
- PDF weekly report: fpdf2, includes all charts as PNG, AI summary text
- Data portability: full SQLite DB backup (single file copy)
- Import from CSV: bulk historical data import with column mapping wizard

### 7. Reminder Notifications
- Daily reminder time configurable per category (e.g., 9pm sleep log reminder)
- Plyer sends OS-native desktop notification with "Log Now" action
- Notification scheduler runs in background thread when Streamlit is active
- Snooze support: remind again in 30 minutes

### 8. Dashboard Overview
- Today's summary: calories consumed, exercise done, sleep last night, water count
- Week-at-a-glance: completion rings (like Apple Watch) for each category
- Streak counters: current and best streak for daily logging
- Quick add buttons for common entries (recent meals listed for one-click re-add)

---

## Database Schema

```sql
CREATE TABLE daily_logs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    log_date    DATE NOT NULL,
    weight_kg   REAL,
    water_glasses INTEGER DEFAULT 0,
    mood_score  INTEGER CHECK(mood_score BETWEEN 1 AND 10),
    energy_level INTEGER CHECK(energy_level BETWEEN 1 AND 10),
    mood_notes  TEXT,
    sleep_start DATETIME,
    sleep_end   DATETIME,
    sleep_quality INTEGER CHECK(sleep_quality BETWEEN 1 AND 5),
    sleep_notes TEXT,
    UNIQUE(log_date)
);

CREATE TABLE meals (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    log_date    DATE NOT NULL,
    logged_at   DATETIME NOT NULL,
    meal_type   TEXT NOT NULL,          -- 'breakfast'|'lunch'|'dinner'|'snack'
    name        TEXT NOT NULL,
    calories    INTEGER,
    protein_g   REAL,
    carbs_g     REAL,
    fat_g       REAL,
    source      TEXT DEFAULT 'manual'   -- 'manual' | 'cli' | 'ai_parsed'
);

CREATE TABLE exercises (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    log_date        DATE NOT NULL,
    logged_at       DATETIME NOT NULL,
    exercise_type   TEXT NOT NULL,
    duration_mins   INTEGER NOT NULL,
    intensity       INTEGER CHECK(intensity BETWEEN 1 AND 10),
    calories_burned INTEGER,
    notes           TEXT
);

CREATE TABLE goals (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    category        TEXT NOT NULL,      -- 'sleep'|'weight'|'exercise'|'calories'
    goal_type       TEXT NOT NULL,      -- 'streak'|'cumulative'|'average'
    target_value    REAL NOT NULL,
    target_unit     TEXT,               -- 'hours', 'days', 'kg', etc.
    period_days     INTEGER DEFAULT 7,
    started_at      DATE NOT NULL,
    ended_at        DATE,
    status          TEXT DEFAULT 'active' -- 'active'|'completed'|'failed'
);

CREATE TABLE ai_reports (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    report_date DATE NOT NULL,
    period_start DATE NOT NULL,
    period_end   DATE NOT NULL,
    summary_text TEXT NOT NULL,
    raw_claude_response TEXT,
    generated_at DATETIME NOT NULL
);
```

---

## Architecture / UI Layout

```
Streamlit Multi-Page App (5 pages):

┌──────────────────────────────────────────────────────────────┐
│  SIDEBAR                                                      │
│  📊 Dashboard                                                 │
│  ✏️  Log Today                                                │
│  📈 Charts                                                    │
│  🤖 AI Report                                                 │
│  ⚙️  Settings                                                 │
└──────────────────────────────────────────────────────────────┘

Dashboard Page:
┌─────────────┬─────────────┬─────────────┬─────────────┐
│  Calories   │  Exercise   │  Sleep      │  Water      │
│  1,840 kcal │  45 min     │  7.2 hrs    │  6 glasses  │
│  ▓▓▓▓▓▓▓░  │  ▓▓▓▓▓▓░░  │  ▓▓▓▓▓▓▓░  │  ▓▓▓▓▓▓░░  │
└─────────────┴─────────────┴─────────────┴─────────────┘
  [Week at a glance — 7-day completion grid]
  [Active Goals: Weight: ▓▓▓▓▓░ 68% | Sleep streak: 12 days]

CLI Interface:
  healthlog [meal|sleep|weight|mood|water|report|export] [args] [options]
```

---

## Key Interactions

### Flow 1: Daily Quick Logging via CLI
1. User runs `healthlog meal "chicken salad 500cal 35g protein" --time lunch`
2. CLI invokes Claude to parse the description and extract macro breakdown
3. Validated entry inserted into `meals` table with current timestamp
4. Terminal confirms: "Logged: Chicken salad — 500 kcal, 35g protein, est. 20g carbs, 18g fat"
5. If daily calorie goal would be exceeded, CLI prints a yellow warning

### Flow 2: Weekly AI Report Generation
1. Sunday 8am background task triggers (or user clicks "Generate Report" in UI)
2. pandas aggregates past 7 days from `daily_logs`, `meals`, `exercises` tables
3. Summary statistics sent to Claude (averages, totals, distribution data — not raw rows)
4. Claude returns structured text: overview paragraph + pattern findings + 3 suggestions
5. Report saved to `ai_reports` and rendered in the AI Report page with syntax highlighting

### Flow 3: Reviewing Charts and Exporting for Doctor
1. User navigates to Charts page, selects "Last 90 days" from date slider
2. Weight chart renders with 7-day MA line and goal target overlay
3. User selects Export > "Doctor Visit CSV" with all categories checked
4. CSV downloaded with one row per day, columns for all logged metrics
5. Optionally generates PDF report including Plotly charts saved as PNG

---

## Implementation Steps

1. **Project scaffold** — `pyproject.toml`, `src/healthlog/`, Click CLI entry point, Streamlit pages
2. **SQLAlchemy models** — 5 tables with constraints, Alembic migrations, seed data script
3. **CLI commands** — `meal`, `sleep`, `weight`, `mood`, `water` with Click options + Claude macro parser
4. **Data aggregation layer** — pandas queries for daily, weekly, monthly summaries
5. **Streamlit pages** — Dashboard, Log Today form, Charts (Plotly), AI Report, Settings
6. **Claude integration** — weekly report prompt with summary statistics, macro parsing prompt
7. **Notification system** — background threading, plyer notifications, configurable schedule
8. **Export modules** — CSV (pandas), PDF (fpdf2 + Plotly PNG export)

---

## Success Criteria

### Functional
- All 6 log categories accept valid input via both CLI and web UI
- Weekly AI report generates in under 15 seconds and covers all 6 metrics
- Charts render correctly for date ranges from 7 days to 365 days

### UX
- CLI log commands complete in under 3 seconds including Claude macro parsing
- Dashboard loads in under 2 seconds for 1-year dataset
- All charts mobile-friendly (Plotly responsive layout in Streamlit)

### Technical Quality
- `log_date` UNIQUE constraint prevents duplicate daily_logs rows
- All Claude calls use summary statistics only (no raw PII health rows in prompts)
- SQLite WAL mode enabled for concurrent CLI + Streamlit access
- Unit tests cover CLI argument parsing, macro extraction, and report generation
