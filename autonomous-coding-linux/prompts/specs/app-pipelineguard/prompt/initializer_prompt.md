# PipelineGuard — Initializer Prompt (Session 1)

You are an expert Python engineer. Your job is to set up the PipelineGuard project
from scratch so that a future coding agent can implement features session by session.

## Your mission

Read `app_spec.txt` in the same directory. Then create:

1. The complete project scaffold (directories, empty files, pyproject.toml, requirements.txt)
2. All SQLAlchemy ORM models and database initialization code
3. A working `init.sh` that starts both FastAPI (port 8000) and Streamlit (port 8501)
4. A `feature_list.json` tracking all features with initial state `"passes": false`
5. A `progress.md` for session notes

## Step-by-step instructions

### Step 1 — Read the spec

Read `app_spec.txt` carefully. Extract:

- All 8 core features with their IDs and names
- All 7 DB table schemas
- The technology stack (Python version, packages, ports)
- The package structure

### Step 2 — Create directory structure

Create the full project layout:

```
pipelineguard/
  api/
    __init__.py
    main.py              -- FastAPI app + lifespan
    config.py            -- pydantic-settings Settings class
    models/
      __init__.py
      base.py            -- DeclarativeBase
      pipeline.py        -- Pipeline, Execution ORM models
      quality.py         -- QualityCheck, QualityResult ORM models
      ai.py              -- AiAnalysis ORM model
      alert.py           -- AlertConfig, AlertLog ORM models
    schemas/
      __init__.py
      pipeline.py        -- Pydantic request/response schemas
      execution.py
      quality.py
      alert.py
      analysis.py
    routers/
      __init__.py
      pipelines.py       -- CRUD + run + validate routes
      executions.py      -- list + detail + analysis routes
      quality.py         -- quality check CRUD routes
      alerts.py          -- alert config CRUD routes
      analytics.py       -- anomaly feed + metrics routes
    services/
      __init__.py
      runner.py          -- PipelineRunner class
      scheduler.py       -- APScheduler wrapper
      quality.py         -- quality check engine (6 check types)
      ai_analyzer.py     -- Claude anomaly analysis
      alerting.py        -- alert dispatch (email/slack/webhook)
    db.py                -- engine, session factory, init_db
  dashboard/
    __init__.py
    app.py               -- Streamlit entry point
    pages/
      __init__.py
      overview.py
      pipeline_detail.py
      executions.py
      anomalies.py
      settings.py
  data/
    db/                  -- SQLite DB files (gitignored)
    logs/                -- per-execution log files (gitignored)
  config/
    pipelines.yaml       -- example pipeline definitions
  requirements.txt
  pyproject.toml
  .env.example
  docker-compose.yml
  README.md
```

### Step 3 — Write requirements.txt

Include exact versions:

```
fastapi==0.111.0
uvicorn[standard]==0.29.0
streamlit>=1.35.0
sqlalchemy==2.0.30
apscheduler==3.10.4
httpx==0.27.0
anthropic>=0.28.0
pandas==2.2.2
pydantic==2.7.1
pydantic-settings==2.3.0
loguru==0.7.2
```

### Step 4 — Write pyproject.toml

```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.backends.legacy:build"

[project]
name = "pipelineguard"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = []

[tool.setuptools.packages.find]
where = ["."]
include = ["api*", "dashboard*"]
```

### Step 5 — Write .env.example

```
# Copy to .env and fill in values
ANTHROPIC_API_KEY=sk-ant-...
PIPELINEGUARD_DB_PATH=./data/db/pipelineguard.db
PIPELINEGUARD_LOG_LEVEL=INFO
PIPELINEGUARD_MAX_WORKERS=4
PIPELINEGUARD_LOG_DIR=./data/logs
```

### Step 6 — Write api/models/base.py

```python
"""SQLAlchemy declarative base for all ORM models."""
from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass
```

### Step 7 — Write all ORM models

In api/models/pipeline.py, implement Pipeline and Execution ORM models.
In api/models/quality.py, implement QualityCheck and QualityResult.
In api/models/ai.py, implement AiAnalysis.
In api/models/alert.py, implement AlertConfig and AlertLog.

All models must exactly match the DB schema in app_spec.txt.
Use str UUIDs for primary keys (generated with str(uuid.uuid4()) before insert).
Use TEXT columns for dates/timestamps (store ISO format strings).
Use TEXT columns for JSON fields (serialize/deserialize manually with json.dumps/loads).
Add `__tablename__` and `__repr__` to each model.

Example model pattern:

```python
import uuid, json
from datetime import datetime, timezone
from sqlalchemy import String, Integer, Text, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column
from api.models.base import Base

class Pipeline(Base):
    __tablename__ = "pipelines"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String, nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)
    schedule_cron: Mapped[str] = mapped_column(String, nullable=False)
    config: Mapped[str] = mapped_column(Text, nullable=False)  # JSON stored as TEXT
    is_active: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    timeout_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=300)
    created_at: Mapped[str] = mapped_column(String, nullable=False,
        default=lambda: datetime.now(timezone.utc).isoformat())
    updated_at: Mapped[str] = mapped_column(String, nullable=False,
        default=lambda: datetime.now(timezone.utc).isoformat())

    def get_config(self) -> dict:
        return json.loads(self.config)

    def __repr__(self) -> str:
        return f"<Pipeline id={self.id} name={self.name}>"
```

### Step 8 — Write api/db.py

```python
"""Database engine, session factory, and initialization."""
import os
from pathlib import Path
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from api.models.base import Base
# Import all models so Base.metadata knows about them
from api.models import pipeline, quality, ai, alert  # noqa: F401

DB_PATH = os.environ.get("PIPELINEGUARD_DB_PATH", "./data/db/pipelineguard.db")
Path(DB_PATH).parent.mkdir(parents=True, exist_ok=True)
DATABASE_URL = f"sqlite:///{DB_PATH}"

engine = create_engine(DATABASE_URL, echo=False, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

def init_db() -> None:
    """Create all tables if they do not exist."""
    Base.metadata.create_all(bind=engine)

def get_session():
    """Dependency for FastAPI route handlers."""
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

### Step 9 — Write api/main.py stub

```python
"""FastAPI application entry point."""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from loguru import logger
from api.db import init_db

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown lifecycle."""
    logger.info("Starting PipelineGuard API...")
    init_db()
    logger.info("Database initialized.")
    # TODO: start APScheduler in Step 4
    yield
    logger.info("Shutting down PipelineGuard API.")
    # TODO: shutdown scheduler in Step 4

app = FastAPI(
    title="PipelineGuard API",
    version="0.1.0",
    description="Data pipeline monitoring and observability platform",
    lifespan=lifespan,
)

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "ok", "version": "0.1.0"}

# TODO: include routers in Steps 2-8
# from api.routers import pipelines, executions, quality, alerts, analytics
# app.include_router(pipelines.router, prefix="/api")
```

### Step 10 — Write stub files for all services and routers

For each file in api/routers/ and api/services/, write a stub with:

- Module docstring
- Import statements
- Empty function/class stubs with docstrings (use `pass` as body)
- Properly typed function signatures

For dashboard/pages/, write stub Streamlit pages:

```python
"""Overview page stub."""
import streamlit as st

st.title("PipelineGuard — Overview")
st.info("Overview page — to be implemented in a future session.")
```

### Step 11 — Write dashboard/app.py

```python
"""Streamlit multi-page dashboard entry point."""
import streamlit as st

st.set_page_config(
    page_title="PipelineGuard",
    page_icon="pipeline",
    layout="wide",
    initial_sidebar_state="expanded",
)

pg = st.navigation([
    st.Page("pages/overview.py", title="Overview", icon=":material/dashboard:"),
    st.Page("pages/pipeline_detail.py", title="Pipeline Detail", icon=":material/analytics:"),
    st.Page("pages/executions.py", title="Executions", icon=":material/history:"),
    st.Page("pages/anomalies.py", title="Anomaly Feed", icon=":material/warning:"),
    st.Page("pages/settings.py", title="Settings", icon=":material/settings:"),
])
pg.run()
```

### Step 12 — Write init.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== PipelineGuard Initializer ==="

# Read API key from /tmp/api-key if env var not set
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f /tmp/api-key ]; then
    export ANTHROPIC_API_KEY="$(cat /tmp/api-key)"
    echo "API key loaded from /tmp/api-key"
fi

# Create data directories
mkdir -p data/db data/logs

# Create and activate virtual environment
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi

source .venv/bin/activate

# Install dependencies
echo "Installing dependencies..."
pip install --quiet -r requirements.txt

# Initialize database
echo "Initializing database..."
python3 -c "from api.db import init_db; init_db(); print('Database initialized.')"

# Start FastAPI
echo "Starting FastAPI on port 8000..."
nohup uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload \
    > /tmp/pipelineguard-api.log 2>&1 &
API_PID=$!
echo "FastAPI PID: $API_PID"

# Wait for FastAPI to be ready
echo "Waiting for FastAPI..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo "FastAPI is ready!"
        break
    fi
    sleep 1
done

# Verify FastAPI health
HEALTH=$(curl -s http://localhost:8000/health)
echo "FastAPI health: $HEALTH"

# Start Streamlit
echo "Starting Streamlit on port 8501..."
cd dashboard
nohup streamlit run app.py \
    --server.port 8501 \
    --server.headless true \
    --server.address 0.0.0.0 \
    > /tmp/pipelineguard-streamlit.log 2>&1 &
STREAMLIT_PID=$!
echo "Streamlit PID: $STREAMLIT_PID"
cd "$SCRIPT_DIR"

# Wait for Streamlit
echo "Waiting for Streamlit..."
for i in $(seq 1 30); do
    if curl -sf http://localhost:8501/_stcore/health > /dev/null 2>&1; then
        echo "Streamlit is ready!"
        break
    fi
    sleep 1
done

echo ""
echo "=== PipelineGuard is running ==="
echo "FastAPI:   http://localhost:8000"
echo "API Docs:  http://localhost:8000/docs"
echo "Streamlit: http://localhost:8501"
echo ""
echo "Logs:"
echo "  FastAPI:   /tmp/pipelineguard-api.log"
echo "  Streamlit: /tmp/pipelineguard-streamlit.log"
```

### Step 13 — Write feature_list.json

Create `feature_list.json` in the project root with all __NUM_FEATURES__ features from app_spec.txt.
Each entry must have: id (int), name (string), description (string, 1-2 sentences), passes (boolean false).

```json
{
  "app_name": "PipelineGuard",
  "total_features": __NUM_FEATURES__,
  "features": [
    {
      "id": 1,
      "name": "Pipeline Definition and Management",
      "description": "Full CRUD for pipeline definitions via FastAPI REST API and Streamlit UI, including dry-run validation endpoint.",
      "passes": false
    },
    {
      "id": 2,
      "name": "Pipeline Execution Engine",
      "description": "PipelineRunner class that loads sources, applies transforms, runs quality checks, writes destinations, and records execution metrics.",
      "passes": false
    },
    {
      "id": 3,
      "name": "Data Quality Checks",
      "description": "Six quality check types (not_null, unique, range, regex, row_count, schema) with per-execution quality score and results storage.",
      "passes": false
    },
    {
      "id": 4,
      "name": "AI Anomaly Detection",
      "description": "Claude-powered post-execution analysis detecting row count drops, null rate changes, and timing anomalies with plain-English explanations.",
      "passes": false
    },
    {
      "id": 5,
      "name": "Alerting System",
      "description": "Email/Slack/webhook alerting with Claude-generated messages, cooldown deduplication, and alert log tracking.",
      "passes": false
    },
    {
      "id": 6,
      "name": "Streamlit Dashboard",
      "description": "Five-page Streamlit dashboard: Overview status grid, Pipeline Detail charts, Executions table, Anomaly Feed, and Settings CRUD forms.",
      "passes": false
    },
    {
      "id": 7,
      "name": "REST API (FastAPI)",
      "description": "Full RESTful API with 15 endpoints covering pipeline/execution/quality/alert CRUD, manual trigger, dry-run validation, and anomaly feed.",
      "passes": false
    },
    {
      "id": 8,
      "name": "Observability and Configuration",
      "description": "loguru structured logging, per-execution log files, Prometheus-format /api/metrics endpoint, and pydantic-settings configuration.",
      "passes": false
    }
  ]
}
```

IMPORTANT: Replace __NUM_FEATURES__ with the actual count of features from app_spec.txt.

### Step 14 — Write progress.md

```markdown
# PipelineGuard — Progress Notes

## Session 1 (Initializer)
- Created full project scaffold
- Implemented all 7 SQLAlchemy ORM models
- Created api/db.py with session factory and init_db()
- Wrote stub files for all routers, services, and dashboard pages
- Created feature_list.json with 8 features
- init.sh tested: FastAPI on :8000, Streamlit on :8501

## Implementation Order (recommended)
1. Feature 7 (REST API) — core CRUD endpoints needed by everything else
2. Feature 1 (Pipeline CRUD) — depends on Feature 7 scaffolding
3. Feature 2 (Execution Engine) — core business logic
4. Feature 3 (Quality Checks) — depends on Feature 2
5. Feature 4 (APScheduler) — depends on Features 2+3
6. Feature 5 (AI Anomaly Detection) — depends on Feature 2 completing executions
7. Feature 6 (Alerting) — depends on Feature 5
8. Feature 8 (Streamlit Dashboard) — depends on Features 1-6 being functional
9. Feature 9 (Observability) — polish, can be added last

## Known Issues
(none yet)
```

### Step 15 — Write example config/pipelines.yaml

```yaml
# Example pipeline definitions for PipelineGuard
# Import via POST /api/pipelines or create via UI

pipelines:
  - name: "daily-sales-pipeline"
    description: "Load daily sales CSV, validate, write to SQLite"
    schedule_cron: "0 6 * * *"
    timeout_seconds: 300
    config:
      source:
        type: csv_file
        path: ./data/samples/sales.csv
      transforms:
        - type: filter
          query: "amount > 0"
        - type: cast
          columns:
            amount: float
            date: str
      destination:
        type: sqlite_table
        table: daily_sales

  - name: "api-health-check-pipeline"
    description: "Fetch JSON from REST API and store locally"
    schedule_cron: "*/15 * * * *"
    timeout_seconds: 60
    config:
      source:
        type: rest_api
        url: https://httpbin.org/json
      transforms:
        - type: drop_columns
          columns: []
      destination:
        type: csv_file
        path: ./data/output/api_health.csv
```

### Step 16 — Run init.sh and verify

```bash
chmod +x init.sh
bash init.sh
```

Confirm:

- No errors during pip install
- Database created at data/db/pipelineguard.db
- FastAPI accessible: `curl http://localhost:8000/health` returns `{"status":"ok"}`
- Streamlit accessible at <http://localhost:8501>
- OpenAPI docs accessible at <http://localhost:8000/docs>

### Step 17 — Commit

```bash
git add -A
git commit -m "init: PipelineGuard scaffold — models, DB, stubs, init.sh, feature_list.json"
```

## CRITICAL RULES

- IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS. feature_list.json is append-only. Never delete a feature entry. Never change a feature's id or name.
- The `passes` field is the ONLY field future coding agents are allowed to modify.
- All DB access must use SQLAlchemy ORM. No raw SQL string concatenation.
- ANTHROPIC_API_KEY must be read from os.environ only (fallback: /tmp/api-key file). Never hardcode it.
- UUID primary keys: generate with str(uuid.uuid4()) before insert, store as TEXT.
- FastAPI routes must be async def. Use Depends(get_session) for DB access.
- Do not start implementing features in this session — only scaffold and stubs.
