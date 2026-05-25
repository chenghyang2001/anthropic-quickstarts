# App Specification: APIWatcher — REST API Endpoint Monitor

## Project Overview

APIWatcher is a lightweight web-based monitoring tool that continuously checks REST API
endpoints for availability, correctness, and performance. A background scheduler runs
configurable health checks and records results to SQLite, while a Streamlit dashboard
visualizes uptime, response time trends, and incident history in real time. When Claude
detects anomaly patterns across check history, it generates plain-English incident reports
and suggests probable root causes. Teams can monitor development, staging, and production
environments from a single dashboard.

---

## Technology Stack

| Layer           | Technology                                      |
|-----------------|-------------------------------------------------|
| Language        | Python 3.11+                                    |
| Web Framework   | FastAPI (background service + REST config API)  |
| Dashboard       | Streamlit                                       |
| Scheduler       | APScheduler 3.x (AsyncIOScheduler)              |
| HTTP Client     | httpx (async)                                   |
| Database        | SQLite (via SQLAlchemy 2.x)                     |
| AI              | Anthropic Claude API (`claude-sonnet-4-6`)      |
| Charts          | Plotly Express                                  |
| Notifications   | smtplib (email), httpx (Slack webhook)          |
| Dependencies    | fastapi, streamlit, apscheduler, httpx,         |
|                 | sqlalchemy, plotly, anthropic, uvicorn          |

---

## Core Features

### 1. Endpoint Configuration
- Add/edit/delete endpoints via Streamlit form or REST API (POST /endpoints)
- Fields: name, URL, HTTP method (GET/POST/PUT), headers (JSON), request body (JSON)
- Environment group assignment: dev / staging / production
- Enable/disable individual endpoints without deleting them
- Import/export endpoint configuration as YAML file

### 2. Health Check Engine
- APScheduler fires checks per endpoint at configured interval (60s to 86400s)
- Per-check validations:
  - Status code matches expected value (default: 200)
  - Response time below threshold (default: 2000ms)
  - Response body contains required keyword (optional)
  - Response JSON matches schema (optional jsonschema validation)
- Check result stored with: status, response_time_ms, status_code, error_message
- Async execution: all due checks fire concurrently with httpx AsyncClient

### 3. SLA Uptime Tracking
- Uptime % calculated over rolling windows: last 24h / 7d / 30d
- Formula: `(passing_checks / total_checks) * 100` per endpoint per window
- SLA target configurable per endpoint (default: 99.9%)
- SLA breach indicator shown on dashboard grid
- Historical SLA CSV export per endpoint

### 4. Incident Detection & Lifecycle
- Incident opened when: 3 consecutive check failures for same endpoint
- Incident fields: start_time, end_time, duration_minutes, failure_count, resolved_at
- Incident auto-closed when: 2 consecutive passing checks after incident start
- Incident severity: LOW (response slow), MEDIUM (partial failure), HIGH (complete down)
- Incident timeline view: shows check results during incident window

### 5. Claude AI Incident Reports
- On incident open: Claude called with last 20 check results as context
- Claude report template:
  - What failed and for how long
  - Last successful check timestamp
  - Error pattern analysis (timeout vs 503 vs 400 etc.)
  - 2-3 probable root causes with likelihood %
  - Suggested immediate remediation steps
- Report stored in incidents table, viewable in Streamlit incident detail
- Manual "Re-analyze" button to refresh Claude report with latest data

### 6. Alert Channels
- Email alert: SMTP with configurable from/to, TLS support, per-endpoint toggle
- Slack webhook: POST JSON payload with incident summary to webhook URL
- Desktop notification: `plyer.notification` for local development use
- Alert on: incident open, incident resolved, SLA breach
- Alert cooldown: minimum 15 minutes between repeat alerts for same endpoint
- Alert log: all sent alerts stored with timestamp, channel, message preview

### 7. Response Time Trend Chart
- Plotly line chart: response_time_ms over last 24h per endpoint
- Overlay: threshold line (red dashed) at configured max response time
- Zoom, pan, hover tooltip with exact ms value
- Multi-endpoint overlay mode: compare endpoints on same chart
- Auto-refresh every 60 seconds via Streamlit `st.rerun()`

### 8. Multi-Environment Dashboard
- Environment selector: All / Dev / Staging / Production tabs
- Status grid: card per endpoint, color-coded green/yellow/red
- Summary row: total endpoints, passing, failing, in-incident per environment
- Filter by: status (up/down/degraded), SLA compliance, last incident time
- "Bulk check now" button: trigger immediate check for all endpoints in group

---

## Database Schema

```sql
CREATE TABLE endpoints (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    url             TEXT NOT NULL,
    method          TEXT NOT NULL DEFAULT 'GET',
    headers         TEXT DEFAULT '{}',       -- JSON string
    body            TEXT DEFAULT '{}',       -- JSON string
    environment     TEXT DEFAULT 'production',
    check_interval  INTEGER DEFAULT 300,     -- seconds
    timeout_ms      INTEGER DEFAULT 5000,
    expected_status INTEGER DEFAULT 200,
    keyword_check   TEXT,                    -- optional keyword in response body
    sla_target      REAL DEFAULT 99.9,
    enabled         BOOLEAN DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE checks (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id     INTEGER NOT NULL REFERENCES endpoints(id) ON DELETE CASCADE,
    checked_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    passed          BOOLEAN NOT NULL,
    status_code     INTEGER,
    response_time   INTEGER,                 -- milliseconds
    error_message   TEXT,
    response_body   TEXT                     -- truncated to 500 chars
);

CREATE TABLE incidents (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id     INTEGER NOT NULL REFERENCES endpoints(id) ON DELETE CASCADE,
    started_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_at     DATETIME,
    duration_mins   INTEGER,
    failure_count   INTEGER DEFAULT 1,
    severity        TEXT DEFAULT 'MEDIUM',   -- LOW | MEDIUM | HIGH
    claude_report   TEXT,
    acknowledged    BOOLEAN DEFAULT 0
);

CREATE TABLE alert_configs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id     INTEGER REFERENCES endpoints(id) ON DELETE CASCADE,
    channel         TEXT NOT NULL,           -- email | slack | desktop
    target          TEXT NOT NULL,           -- email address or webhook URL
    on_incident     BOOLEAN DEFAULT 1,
    on_resolve      BOOLEAN DEFAULT 1,
    on_sla_breach   BOOLEAN DEFAULT 1,
    cooldown_mins   INTEGER DEFAULT 15,
    last_sent_at    DATETIME
);
```

---

## Architecture / UI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  Process Layout                                                 │
│                                                                 │
│  ┌─────────────────┐      SQLite DB      ┌──────────────────┐  │
│  │  FastAPI Server │ ←──────────────────→│ Streamlit UI     │  │
│  │  :8000          │                     │ :8501            │  │
│  │                 │                     │                  │  │
│  │  APScheduler    │                     │  Dashboard       │  │
│  │  (background)   │                     │  (reads DB)      │  │
│  │       ↓         │                     └──────────────────┘  │
│  │  httpx checks   │──→ Claude API                             │
│  │       ↓         │    (on incident)                          │
│  │  Alert sender   │──→ Email / Slack / Desktop                │
│  └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘

Streamlit Dashboard Layout:
┌──────────────────────────────────────────────────────────────┐
│  APIWatcher                [All][Dev][Staging][Production]    │
├──────────────────────────────────────────────────────────────┤
│  Summary: 12 endpoints  ✅ 9 UP  ⚠️ 2 Degraded  🔴 1 Down   │
├──────────────────────────────────────────────────────────────┤
│  STATUS GRID                                                  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐          │
│  │ ✅ Auth API  │ │ ⚠️ Orders    │ │ 🔴 Payments  │          │
│  │ 99.97% 24h  │ │ 98.12% 24h  │ │ 91.3% 24h   │          │
│  │ 142ms avg   │ │ 847ms avg   │ │ INCIDENT 12m │          │
│  └──────────────┘ └──────────────┘ └──────────────┘          │
├───────────────────────────────────┬──────────────────────────┤
│  RESPONSE TIME CHART (Plotly)     │  INCIDENT LOG            │
│                                   │                          │
│  ms                               │  🔴 Payments API         │
│  2000 ─ ─ ─ ─ ─ ─ ─[threshold]  │  Started: 14:32          │
│  1000 │   ╭─╮   ╭╮               │  Duration: 12 min        │
│   500 │───╯ ╰───╯ ╰──────        │  [View Claude Report]    │
│       └────────────────── time   │                          │
│                                   │  ✅ Auth API resolved    │
│                                   │  Yesterday 09:15, 3 min  │
└───────────────────────────────────┴──────────────────────────┘
```

---

## Key Interactions

### Interaction 1: Scheduled Check Execution
```
APScheduler fires job for endpoint_id=5 (interval: 60s)
  → httpx.AsyncClient.request(method, url, headers, json, timeout)
  → Response received (or exception caught)
  → Check result evaluated:
      pass_conditions = [
          status_code == endpoint.expected_status,
          response_time <= endpoint.timeout_ms,
          keyword in response.text (if configured),
      ]
      passed = all(pass_conditions)
  → checks row inserted
  → Incident logic:
      last_3 = SELECT passed FROM checks WHERE endpoint_id=5 ORDER BY id DESC LIMIT 3
      if all failed → open new incident (if none open)
      if last_2 passed → close open incident, set resolved_at, calc duration
  → If incident opened → alert_sender.send_all(endpoint, incident)
  → If incident opened → claude_reporter.generate(endpoint, incident) (async, non-blocking)
```

### Interaction 2: Claude Incident Report Generation
```
Incident opened for endpoint "Payment Gateway"
  → Fetch last 20 checks for endpoint from DB
  → Build Claude prompt:
      "Analyze these API check results and generate an incident report.
       Endpoint: {name} ({url})
       Recent checks (newest first): {json_checks}
       Include: failure duration, error pattern, root causes, remediation steps."
  → Claude API call (timeout 30s, retry 2x)
  → Response parsed, stored in incidents.claude_report
  → Streamlit next refresh picks up report from DB
  → Incident card shows "AI Report Available" badge
```

### Interaction 3: Streamlit Dashboard Real-Time Refresh
```
Streamlit app starts
  → Reads all endpoints + latest check per endpoint from SQLite
  → Renders status grid (color based on last check result)
  → Renders Plotly chart (last 24h response times)
  → Renders incident log (open + last 5 resolved)
  → st.rerun() scheduled every 60 seconds
  → User clicks endpoint card → detail sidebar opens:
      - SLA metrics (24h/7d/30d uptime %)
      - Response time histogram
      - Check history table (paginated, 50 per page)
      - Claude incident report (if exists)
      - Alert configuration form
```

---

## Implementation Steps

1. **Project structure**: Create `watcher/` package with modules: `models.py`, `scheduler.py`,
   `checker.py`, `incident.py`, `alerter.py`, `claude_reporter.py`, `api.py`, `dashboard.py`.

2. **Database layer**: Define SQLAlchemy ORM models for all 4 tables, create engine with
   `check_same_thread=False` for multi-threaded access, write `db.py` session factory.

3. **HTTP checker**: `checker.py` — async function `run_check(endpoint) -> CheckResult`,
   handle: connection error, timeout, JSON decode error, status mismatch, keyword mismatch.

4. **Scheduler setup**: `scheduler.py` — AsyncIOScheduler, load all enabled endpoints on start,
   schedule each as IntervalTrigger job, expose `add_job/remove_job/update_job` functions.

5. **Incident & alert logic**: `incident.py` — `evaluate_incident(endpoint_id)` after each check,
   `alerter.py` — `send_email`, `send_slack`, `send_desktop` with cooldown enforcement.

6. **Claude reporter**: `claude_reporter.py` — async function `generate_report(endpoint, incident)`,
   builds prompt from check history, calls Claude API, saves report text to DB.

7. **FastAPI service**: `api.py` — CRUD endpoints for endpoint config, manual check trigger,
   incident acknowledge. Starts APScheduler in lifespan event. Runs on port 8000.

8. **Streamlit dashboard**: `dashboard.py` — status grid with `st.columns`, Plotly chart
   with `st.plotly_chart`, incident log with `st.expander`, auto-refresh via `st.rerun`.

---

## Success Criteria

### Functional
- 50 endpoints checked concurrently with no missed intervals (async httpx)
- Incident opens within 3 failed checks (≤ 3 check intervals delay)
- Claude report generated within 10 seconds of incident open
- Email and Slack alerts fire within 5 seconds of incident detection
- SLA calculation matches manual count within 0.1%

### UX
- Dashboard status grid refreshes without full page reload (60s interval)
- Endpoint detail panel opens within 500ms (SQLite read)
- Claude incident report readable as standalone document (no technical jargon)
- Check history table paginates 10,000+ rows without lag

### Technical Quality
- All DB writes use SQLAlchemy sessions with `try/finally` close
- httpx checks have explicit timeout, no hanging connections
- APScheduler jobs survive FastAPI restart (jobs re-loaded from DB on startup)
- Claude API key loaded from `ANTHROPIC_API_KEY` environment variable only
- Unit tests for: SM-2 logic, incident detection, SLA calculation
