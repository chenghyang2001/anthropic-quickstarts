# HealthLog — Initializer Prompt (Session 1)

You are an expert Python engineer. Your job is to set up the HealthLog project from scratch
so that a future coding agent can implement features session by session.

## Your mission

Read `app_spec.txt` in the same directory. Then create:

1. The complete project scaffold (directories, empty files, pyproject.toml, requirements.txt)
2. All SQLAlchemy ORM models and database initialization code
3. A working `init.sh` that any agent can run to boot the environment
4. A `feature_list.json` tracking all features with initial state `"passes": false`
5. A `progress.md` for session notes

## Step-by-step instructions

### Step 1 — Read the spec

Read `app_spec.txt` carefully. Extract:

- All 8 core features with their IDs and names
- All 5 DB table schemas
- The technology stack (Python version, packages, ports)
- The package structure

### Step 2 — Create directory structure

Create the full package layout:

```
healthlog/
  src/
    healthlog/
      __init__.py
      models.py
      db.py
      cli.py
      dashboard.py
      pages/
        __init__.py
        dashboard_page.py
        log_today.py
        charts.py
        ai_report.py
        settings.py
      services/
        __init__.py
        meal_service.py
        sleep_service.py
        aggregation.py
        claude_client.py
        notifier.py
      export.py
  requirements.txt
  pyproject.toml
  README.md
  alembic.ini
  alembic/
    env.py
    versions/
      __init__.py
```

### Step 3 — Write requirements.txt

Include exact versions:

```
streamlit==1.35.0
click==8.1.7
sqlalchemy==2.0.30
alembic==1.13.1
anthropic>=0.28.0
pandas==2.2.2
plotly==5.22.0
plyer==2.1.0
fpdf2==2.7.9
kaleido==0.2.1
rich==13.7.1
```

### Step 4 — Write pyproject.toml

```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.backends.legacy:build"

[project]
name = "healthlog"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[project.scripts]
healthlog = "healthlog.cli:cli"

[tool.setuptools.packages.find]
where = ["src"]
```

### Step 5 — Write models.py

Implement all 5 SQLAlchemy 2.0 ORM models exactly matching the DB schema in app_spec.txt:

- DailyLog
- Meal
- Exercise
- Goal
- AiReport

Use `DeclarativeBase`, `mapped_column`, `Mapped` typing style from SQLAlchemy 2.0.
Add `__repr__` to each model. Add relationships where useful.

### Step 6 — Write db.py

```python
"""Database engine and session factory."""
import os
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from healthlog.models import Base

DB_DIR = Path.home() / ".healthlog"
DB_DIR.mkdir(exist_ok=True)
DB_PATH = DB_DIR / "healthlog.db"
DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(DATABASE_URL, echo=False)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def init_db():
    """Create all tables if they don't exist."""
    Base.metadata.create_all(bind=engine)

def get_session():
    """Context manager for DB sessions."""
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()
```

### Step 7 — Write stub files

For each file in pages/ and services/, write a stub with:

- Module docstring explaining what it will contain
- Import statements
- Empty function stubs with docstrings (use `pass` as body)
- `if __name__ == "__main__":` block where appropriate

cli.py stub: import click, define `cli = click.group()`, add 6 empty subcommand stubs.
dashboard.py stub: `import streamlit as st`, `st.set_page_config(...)`, basic navigation.

### Step 8 — Write init.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== HealthLog Initializer ==="

# Read API key from /tmp/api-key if env var not set
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f /tmp/api-key ]; then
    export ANTHROPIC_API_KEY="$(cat /tmp/api-key)"
    echo "API key loaded from /tmp/api-key"
fi

# Create and activate virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --quiet -r requirements.txt
pip install --quiet -e .

# Initialize database (create tables)
echo "Initializing database..."
python3 -c "from healthlog.db import init_db; init_db(); print('Database initialized at ~/.healthlog/healthlog.db')"

# Start Streamlit
echo "Starting Streamlit on port 8501..."
nohup streamlit run src/healthlog/dashboard.py \
    --server.port 8501 \
    --server.headless true \
    --server.address 0.0.0.0 \
    > /tmp/healthlog-streamlit.log 2>&1 &
STREAMLIT_PID=$!
echo "Streamlit PID: $STREAMLIT_PID"

# Wait for Streamlit to be ready
echo "Waiting for Streamlit to start..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:8501/_stcore/health > /dev/null 2>&1; then
        echo "Streamlit is ready!"
        break
    fi
    sleep 1
done

# Print CLI usage
echo ""
echo "=== HealthLog is running ==="
echo "Web UI:  http://localhost:8501"
echo ""
echo "CLI usage:"
echo "  healthlog meal \"oatmeal 400cal\" --time breakfast"
echo "  healthlog sleep 7.5 --quality 4"
echo "  healthlog weight 72.5"
echo "  healthlog mood 7 --energy 8 --note \"productive day\""
echo "  healthlog water +1"
echo "  healthlog report --week"
echo "  healthlog export --format csv --days 90"
echo ""
echo "Logs: /tmp/healthlog-streamlit.log"
```

### Step 9 — Write feature_list.json

Create `feature_list.json` in the project root with all __NUM_FEATURES__ features from app_spec.txt.
Each entry must have: id (int), name (string), description (string, 1-2 sentences), passes (boolean false).

```json
{
  "app_name": "HealthLog",
  "total_features": __NUM_FEATURES__,
  "features": [
    {
      "id": 1,
      "name": "Multi-category Web Logging",
      "description": "Streamlit multi-page app with dedicated log forms for all 6 health categories with validation and immediate confirmation.",
      "passes": false
    },
    {
      "id": 2,
      "name": "Quick-Entry Click CLI",
      "description": "healthlog command with 6 subcommands for rapid terminal-based health data entry including natural language meal parsing.",
      "passes": false
    },
    {
      "id": 3,
      "name": "Weekly AI Health Report",
      "description": "Claude-generated weekly analysis detecting cross-category patterns like sleep-mood correlation with personalized suggestions.",
      "passes": false
    },
    {
      "id": 4,
      "name": "Trend Charts with Plotly",
      "description": "Five interactive Plotly charts: weight MA, sleep quality bars, mood dual-axis, calories stacked bar, exercise heatmap.",
      "passes": false
    },
    {
      "id": 5,
      "name": "Goal Tracking with Notifications",
      "description": "streak/cumulative/average goals with progress bars in dashboard and plyer OS-native desktop notifications on milestones.",
      "passes": false
    },
    {
      "id": 6,
      "name": "Export Options",
      "description": "CSV export via pandas, PDF report via fpdf2 with embedded Plotly charts, and full SQLite database backup.",
      "passes": false
    },
    {
      "id": 7,
      "name": "Reminder Notifications",
      "description": "Configurable daily per-category reminders firing plyer desktop notifications when category not yet logged for the day.",
      "passes": false
    },
    {
      "id": 8,
      "name": "Dashboard Overview",
      "description": "Main dashboard showing today's completion summary, 7-day grid, streak counters, quick-add recent meals, and active goals.",
      "passes": false
    }
  ]
}
```

IMPORTANT: Replace __NUM_FEATURES__ with the actual count of features from app_spec.txt.

### Step 10 — Write progress.md

```markdown
# HealthLog — Progress Notes

## Session 1 (Initializer)
- Created full project scaffold
- Implemented all 5 SQLAlchemy ORM models
- Created db.py with session factory and init_db()
- Wrote stub files for all pages and services
- Created feature_list.json with 8 features
- init.sh tested and working

## Implementation Order (recommended)
1. Feature 2 (CLI) — test with bash, no browser needed
2. Feature 1 (Streamlit Logging) — depends on DB models done
3. Feature 3 (Claude Macros) — depends on Feature 2 CLI
4. Feature 8 (Dashboard) — depends on Feature 1 logging
5. Feature 4 (Charts) — depends on data in DB
6. Feature 5 (Goals) — depends on DB and Dashboard
7. Feature 7 (Reminders) — depends on Goals
8. Feature 6 (Export) — depends on data in DB
9. Feature 3 (AI Report) — depends on aggregation service

## Known Issues
(none yet)
```

### Step 11 — Run init.sh and verify

```bash
chmod +x init.sh
bash init.sh
```

Confirm:

- No errors during pip install
- Database created at ~/.healthlog/healthlog.db
- Streamlit accessible at <http://localhost:8501>
- `healthlog --help` shows 6 subcommands

### Step 12 — Commit

```bash
git add -A
git commit -m "init: HealthLog scaffold — models, DB, stubs, init.sh, feature_list.json"
```

## CRITICAL RULES

- IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS. feature_list.json is append-only. Never delete a feature entry. Never change a feature's id or name.
- The `passes` field is the ONLY field future coding agents are allowed to modify.
- All DB access must use SQLAlchemy ORM. No raw SQL string concatenation.
- ANTHROPIC_API_KEY must be read from os.environ only. Never hardcode it.
- Do not start implementing features in this session — only scaffold and stubs.
