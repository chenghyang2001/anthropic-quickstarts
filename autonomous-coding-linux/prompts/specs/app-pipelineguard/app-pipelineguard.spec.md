# App Specification: PipelineGuard — Data Pipeline Monitoring Platform

## Project Overview

Build a **Python-based data pipeline monitoring and observability platform**.
PipelineGuard lets data engineers define, monitor, and debug data pipelines —
with Claude AI providing automated anomaly detection, root-cause analysis,
and plain-English alerts.

Target users: data engineers and analysts who run scheduled ETL jobs,
data quality checks, or automated reporting pipelines.

---

## Technology Stack

### Runtime & Language
- **Python 3.12+** (primary language — no JavaScript)
- **FastAPI** — backend API server
- **Streamlit** — web dashboard UI (Python-only frontend)
- **SQLite** (development) / **PostgreSQL** (production) via SQLAlchemy

### AI Integration
- **Anthropic SDK** (`anthropic`) — Claude API
- Default model: `claude-sonnet-4-6` (analysis requires stronger reasoning)
- Used for: anomaly explanation, failure root-cause, alert summarization
- API key: `ANTHROPIC_API_KEY` environment variable

### Background Jobs
- **APScheduler** — cron-style pipeline execution scheduler
- **Celery + Redis** (optional, for distributed mode)

### Data Sources Supported
- **Files**: CSV, JSON, Parquet (via pandas + pyarrow)
- **Databases**: PostgreSQL, MySQL, SQLite (via SQLAlchemy)
- **APIs**: REST endpoints with configurable auth headers
- **Cloud**: AWS S3, Google Cloud Storage (optional, pluggable)

### Libraries
- `pandas` — data processing and quality checks
- `great_expectations` — data validation rules
- `plotly` — interactive charts in Streamlit
- `httpx` — async HTTP client for REST source polling
- `pydantic` — config validation and API request/response models
- `loguru` — structured logging
- `python-dotenv` — environment config

### Deployment
- Runs as two processes: `uvicorn` (FastAPI) + `streamlit run`
- `docker-compose.yml` for local development
- Configurable via `config/pipelines.yaml` or REST API

---

## Core Features

### 1. Pipeline Definition
- Define pipelines in YAML or via web UI
- Pipeline = Source → Transform → Destination + Schedule
- Supported sources: file path, DB query, REST URL
- Supported transforms: filter rows, rename columns, type cast, join, aggregate
- Supported destinations: file, DB table, webhook, email
- Dry-run mode: validate pipeline config without executing

### 2. Pipeline Execution Engine
- APScheduler runs pipelines on cron schedule or on-demand
- Each run creates an `Execution` record with: status, start/end time, row counts, errors
- Row-level error capture (failed rows written to error log)
- Parallel execution for independent pipelines
- Execution timeout with configurable limit per pipeline

### 3. Data Quality Checks
- Define quality rules per pipeline step:
  - `not_null`: column must have no null values
  - `unique`: column values must be unique
  - `range`: numeric column must be within [min, max]
  - `regex`: string column must match pattern
  - `row_count`: output must have >= N rows
  - `schema`: output must match expected column types
- Configurable severity: `warning` (log only) vs `error` (fail pipeline)
- Quality score per run (% rules passed)

### 4. AI-Powered Anomaly Detection
- After each run, Claude analyzes:
  - Row count vs historical average (sudden drops/spikes)
  - Null rate changes
  - Execution time vs baseline
  - Error messages
- Claude generates plain-English explanation and suggested fix
- Anomaly severity: `info` / `warning` / `critical`
- All AI analysis stored in `ai_analyses` table (no re-running on page reload)

### 5. Alerting System
- Configure alerts per pipeline: email, Slack webhook, or webhook URL
- Alert triggers: pipeline failure, quality check error, anomaly detected
- Claude-generated alert message (concise, actionable, < 280 chars)
- Alert deduplication: don't re-alert for same issue within cooldown window
- Alert history log with acknowledgment tracking

### 6. Dashboard (Streamlit)
- **Overview page**: all pipelines status grid (green/yellow/red)
- **Pipeline detail page**: execution history chart, quality score trend, last AI analysis
- **Execution log page**: filterable log table, row-level errors download
- **Anomaly feed**: chronological feed of AI-detected anomalies
- **Settings page**: manage pipelines, alerts, API keys

### 7. REST API (FastAPI)
- Full CRUD for pipelines, quality rules, alert configs
- Trigger pipeline run on-demand: `POST /api/pipelines/{id}/run`
- Get execution status: `GET /api/executions/{id}`
- Get AI analysis for execution: `GET /api/executions/{id}/analysis`
- Webhook receiver for external trigger: `POST /api/webhooks/trigger`

### 8. Observability & Logging
- Structured JSON logs via loguru to file + stdout
- Per-execution log file stored in `data/logs/{execution_id}.log`
- Metrics endpoint: `GET /api/metrics` (Prometheus-compatible)
- Execution duration histogram, row count timeseries, error rate per pipeline

---

## Database Schema

### `pipelines`
```sql
id              TEXT PRIMARY KEY    -- UUID
name            TEXT NOT NULL
description     TEXT
schedule_cron   TEXT                -- e.g. "0 6 * * *"
config          TEXT                -- JSON: source/transform/dest config
is_active       INTEGER DEFAULT 1
timeout_seconds INTEGER DEFAULT 300
created_at      TEXT
updated_at      TEXT
```

### `executions`
```sql
id              TEXT PRIMARY KEY
pipeline_id     TEXT REFERENCES pipelines(id)
status          TEXT                -- 'running'|'success'|'failed'|'timeout'
started_at      TEXT
finished_at     TEXT
rows_input      INTEGER
rows_output     INTEGER
rows_failed     INTEGER
error_message   TEXT
log_path        TEXT
triggered_by    TEXT                -- 'schedule'|'api'|'manual'
```

### `quality_checks`
```sql
id              TEXT PRIMARY KEY
pipeline_id     TEXT REFERENCES pipelines(id)
column_name     TEXT
check_type      TEXT                -- 'not_null'|'unique'|'range'|'regex'|'row_count'|'schema'
config          TEXT                -- JSON: params for this check type
severity        TEXT DEFAULT 'error'
is_active       INTEGER DEFAULT 1
```

### `quality_results`
```sql
id              TEXT PRIMARY KEY
execution_id    TEXT REFERENCES executions(id)
check_id        TEXT REFERENCES quality_checks(id)
passed          INTEGER
actual_value    TEXT
expected_value  TEXT
message         TEXT
```

### `ai_analyses`
```sql
id              TEXT PRIMARY KEY
execution_id    TEXT REFERENCES executions(id)
anomaly_type    TEXT                -- 'row_count_drop'|'quality_degradation'|'slowdown'|'failure'
severity        TEXT
summary         TEXT
root_cause      TEXT
suggested_fix   TEXT
model           TEXT
tokens_used     INTEGER
created_at      TEXT
```

### `alert_configs`
```sql
id              TEXT PRIMARY KEY
pipeline_id     TEXT REFERENCES pipelines(id)
channel         TEXT                -- 'email'|'slack'|'webhook'
config          TEXT                -- JSON: email address / Slack URL / webhook URL
trigger_on      TEXT                -- JSON array: ['failure','quality_error','anomaly']
cooldown_minutes INTEGER DEFAULT 60
is_active       INTEGER DEFAULT 1
```

### `alert_logs`
```sql
id              TEXT PRIMARY KEY
alert_config_id TEXT REFERENCES alert_configs(id)
execution_id    TEXT REFERENCES executions(id)
message         TEXT
sent_at         TEXT
acknowledged    INTEGER DEFAULT 0
acknowledged_at TEXT
```

---

## API Endpoints

### Pipelines
- `GET    /api/pipelines`                 — list all pipelines
- `POST   /api/pipelines`                 — create pipeline
- `GET    /api/pipelines/{id}`            — get pipeline detail
- `PUT    /api/pipelines/{id}`            — update pipeline
- `DELETE /api/pipelines/{id}`            — delete pipeline
- `POST   /api/pipelines/{id}/run`        — trigger immediate run
- `POST   /api/pipelines/{id}/validate`   — dry-run validation
- `GET    /api/pipelines/{id}/executions` — execution history

### Executions
- `GET    /api/executions`                — list executions (filterable)
- `GET    /api/executions/{id}`           — execution detail
- `GET    /api/executions/{id}/logs`      — raw log file content
- `GET    /api/executions/{id}/errors`    — failed rows download (CSV)
- `GET    /api/executions/{id}/analysis`  — AI analysis for this execution
- `POST   /api/executions/{id}/rerun`     — re-run failed execution

### Quality Checks
- `GET    /api/pipelines/{id}/checks`     — list quality rules for pipeline
- `POST   /api/pipelines/{id}/checks`     — add quality rule
- `PUT    /api/checks/{id}`               — update rule
- `DELETE /api/checks/{id}`              — delete rule

### Alerts
- `GET    /api/pipelines/{id}/alerts`     — list alert configs
- `POST   /api/pipelines/{id}/alerts`     — add alert config
- `PUT    /api/alerts/{id}`              — update alert config
- `GET    /api/alerts/history`           — alert log (all pipelines)
- `PUT    /api/alerts/{log_id}/ack`      — acknowledge alert

### AI & Analytics
- `GET    /api/anomalies`                 — anomaly feed (all pipelines)
- `POST   /api/executions/{id}/analyze`   — force re-run AI analysis
- `GET    /api/pipelines/{id}/stats`      — aggregated stats (success rate, avg duration)
- `GET    /api/metrics`                   — Prometheus-format metrics

---

## UI Layout (Streamlit Pages)

### Overview Page (`/`)
```
┌────────────────────────────────────────────────────────────┐
│  PipelineGuard  [Overview] [Pipelines] [Anomalies] [⚙]    │
├────────────────────────────────────────────────────────────┤
│  Status Summary: ✅ 8 healthy  ⚠ 2 warning  🔴 1 failed    │
│  ─────────────────────────────────────────────────────────  │
│  Pipeline Status Grid:                                      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ sales_daily  │ │ user_metrics │ │ log_etl      │       │
│  │ ✅ SUCCESS   │ │ ⚠ WARNING   │ │ 🔴 FAILED   │       │
│  │ 2h ago       │ │ 34m ago      │ │ 12m ago      │       │
│  │ 142K rows    │ │ 8.1K rows    │ │ ERROR: conn  │       │
│  └──────────────┘ └──────────────┘ └──────────────┘       │
│  ─────────────────────────────────────────────────────────  │
│  Recent Anomalies (AI):                                     │
│  🟡 user_metrics: Row count 23% below 7-day average        │
│  🔴 log_etl: Connection timeout — possible DB overload      │
└────────────────────────────────────────────────────────────┘
```

### Pipeline Detail Page
- Execution history line chart (success/fail/warning by date)
- Quality score trend chart
- Latest execution detail (rows, duration, errors)
- AI analysis card (anomaly explanation + suggested fix)
- Quality check results table

### Execution Log Page
- Filterable log table (severity, timestamp, message)
- Download log button
- Failed rows download (if any)

---

## Key Interactions

### Pipeline Run Flow
1. APScheduler triggers pipeline at cron time
2. Engine reads source data (file/DB/API)
3. Apply transforms row by row (errors collected, not halted)
4. Run quality checks on output DataFrame
5. Write to destination
6. Update `executions` record with final status + counts
7. If any anomaly detected: background task calls Claude API
8. Claude analysis stored in `ai_analyses`
9. If alert triggered: send notification with Claude-generated message

### Anomaly Analysis Flow
1. Execution finishes (success or fail)
2. Background task compares this run's stats to last 30 runs
3. If deviation > threshold: prepare context for Claude
4. Claude prompt: execution stats + recent history + error message
5. Claude returns: anomaly_type, severity, summary, root_cause, suggested_fix
6. Result stored in DB, shown in dashboard immediately

### Manual Trigger Flow
1. User clicks "Run Now" in dashboard or calls `POST /api/pipelines/{id}/run`
2. Returns `execution_id` immediately (202 Accepted)
3. Dashboard polls `GET /api/executions/{id}` every 5 seconds
4. Progress bar shows row count if available
5. On completion: show result + AI analysis

---

## Implementation Steps

### Step 1: Project Foundation
- Set up FastAPI app with SQLAlchemy + SQLite
- Define all ORM models and run `create_all()`
- Implement `POST /api/pipelines` and `GET /api/pipelines`
- Docker Compose: FastAPI + Redis (for future Celery)
- Health check endpoint

### Step 2: Pipeline Execution Engine
- Build `PipelineRunner` class (source → transform → dest)
- CSV/JSON file source reader
- SQLite/PostgreSQL DB query source
- REST API source (httpx async)
- Basic transforms: filter, rename, cast
- DB and file destination writers

### Step 3: Quality Checks
- Implement each check type as a Python function
- Run checks against output DataFrame
- Store results in `quality_results`
- Quality score calculation per execution

### Step 4: Scheduler
- APScheduler integration with cron expressions
- Load active pipelines from DB on startup
- Add/remove jobs dynamically when pipeline config changes
- Manual trigger API endpoint

### Step 5: AI Anomaly Detection
- Anthropic SDK wrapper with error handling
- Build historical stats aggregation query
- Design Claude prompts for each anomaly type
- Background task triggered after execution
- Store result in `ai_analyses`

### Step 6: Alerting
- Alert config CRUD API
- Email sender (smtplib with TLS)
- Slack webhook sender (httpx)
- Generic webhook sender
- Cooldown deduplication logic
- Claude-generated alert message

### Step 7: Streamlit Dashboard
- Overview page with status grid
- Pipeline detail page with Plotly charts
- Execution log page with filters
- Anomaly feed page
- Settings page (pipeline CRUD form)

### Step 8: Polish
- Prometheus metrics endpoint
- Structured logging with loguru
- Environment-based config (pydantic-settings)
- Docker Compose with environment file
- README with setup guide and YAML pipeline examples

---

## File & Directory Conventions

```
pipelineguard/
├── docker-compose.yml
├── .env.example
├── requirements.txt
├── config/
│   └── pipelines.yaml         -- example pipeline definitions
├── api/
│   ├── main.py                -- FastAPI app entry point
│   ├── routers/
│   │   ├── pipelines.py
│   │   ├── executions.py
│   │   ├── quality.py
│   │   ├── alerts.py
│   │   └── analytics.py
│   ├── models/                -- SQLAlchemy ORM
│   │   ├── base.py
│   │   ├── pipeline.py
│   │   ├── execution.py
│   │   └── alert.py
│   ├── schemas/               -- Pydantic request/response models
│   └── services/              -- business logic
│       ├── runner.py          -- PipelineRunner
│       ├── scheduler.py       -- APScheduler wrapper
│       ├── quality.py         -- quality check engine
│       ├── ai_analyzer.py     -- Claude anomaly analysis
│       └── alerting.py        -- alert dispatch
├── dashboard/
│   ├── app.py                 -- Streamlit entry point
│   └── pages/
│       ├── overview.py
│       ├── pipeline_detail.py
│       ├── executions.py
│       ├── anomalies.py
│       └── settings.py
├── data/
│   ├── db/                    -- SQLite DB files
│   └── logs/                  -- per-execution log files
└── tests/
    ├── test_runner.py
    ├── test_quality.py
    ├── test_ai_analyzer.py
    └── test_api.py
```

---

## Success Criteria

### Functionality
- Pipelines execute on schedule without drift (< 1 minute late)
- Quality checks correctly pass/fail test datasets
- AI analysis generated within 10 seconds of execution completion
- Alerts sent within 30 seconds of trigger condition
- Dashboard reflects execution results in real-time (5-second polling)

### User Experience
- Dashboard loads in under 2 seconds
- Plain-English AI anomaly explanations understandable without data engineering background
- Pipeline CRUD completable in under 3 clicks from dashboard
- Log download works for executions with 1M+ rows

### Technical Quality
- All DB operations use parameterized queries
- API key never logged
- All external calls (DB, REST, Claude) have timeout + retry logic
- Tests cover: PipelineRunner, quality check engine, AI prompt correctness
- Docker Compose brings up full stack with one command
