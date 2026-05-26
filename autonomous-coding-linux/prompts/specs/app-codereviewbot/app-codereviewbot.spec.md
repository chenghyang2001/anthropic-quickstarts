# App Specification: CodeReviewBot

## Project Overview

CodeReviewBot is an AI-powered code review tool that combines a CLI interface with an optional
web dashboard. Developers run `codereview scan ./src` locally or point it at a GitHub PR, and
Claude returns structured findings (critical / warning / suggestion) with file-line context.
All findings are persisted in SQLite so teams can track quality trends over time.

**Primary audience:** Individual developers and small engineering teams wanting automated
pre-merge code review without sending code to a third-party SaaS.

---

## Technology Stack

| Layer        | Technology                              |
|--------------|-----------------------------------------|
| CLI          | Python 3.11 + Click 8                  |
| API server   | FastAPI 0.111                           |
| Dashboard    | Streamlit 1.35                          |
| AI           | Anthropic Claude (claude-sonnet-4-6)   |
| GitHub       | PyGithub 2.3                            |
| Database     | SQLite (via SQLAlchemy 2.0)             |
| Config       | PyYAML + python-dotenv                  |
| Export       | Markdown (built-in) + Jinja2 templates  |

---

## Core Features

### 1. Local File Scanner
- Recursively scan a directory for Python, TypeScript, and Go source files
- Respect `.codereviewbotignore` patterns (same syntax as `.gitignore`)
- Chunk large files into overlapping segments before sending to Claude
- Display real-time progress bar (tqdm) as files are processed

### 2. GitHub PR Integration
- Authenticate via `GITHUB_TOKEN` environment variable
- Fetch PR diff using PyGithub, reconstruct per-file diffs
- Post review findings as inline PR comments (GitHub Review API)
- Support `--dry-run` flag to preview without posting

### 3. Severity Classification
- Claude returns structured JSON: `{ "findings": [{ "severity", "line", "message", "suggestion" }] }`
- Three levels: `critical` (blocks merge), `warning` (should fix), `suggestion` (optional)
- CLI exit code 1 if any `critical` findings exist (suitable for CI gates)
- Color-coded terminal output (Rich library)

### 4. Review History & Storage
- Every scan result saved to SQLite with timestamp and repo context
- Query history: `codereview history --repo myrepo --last 30d`
- Diff two reviews to see quality improvement over time
- Pruning command: `codereview history prune --older-than 90d`

### 5. Streamlit Dashboard
- Summary cards: total findings by severity this week
- Line chart: findings over time (critical trend)
- Table: top 10 files with most findings (current week)
- Team statistics: findings per author (from git blame data)
- Filter by repo, date range, severity, author

### 6. Configurable Rules
- `.codereviewbot.yaml` at project root defines focus areas
- Enable/disable rule categories: security, performance, style, logic
- Custom prompt additions: "Also check for use of deprecated `requests` patterns"
- Per-language settings (e.g. Go-specific idioms, Python type-hint enforcement)

### 7. Export & Reporting
- `codereview report --format markdown > review.md` — full Markdown report
- `codereview report --format github-comment` — post summary comment to PR
- Report includes: file list, finding count by severity, top issues, remediation hints
- Scheduled reports via cron: weekly digest email (via smtplib)

---

## Database Schema

```sql
CREATE TABLE reviews (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name   TEXT NOT NULL,
    branch      TEXT,
    pr_number   INTEGER,
    scan_type   TEXT NOT NULL,          -- 'local' | 'github_pr'
    started_at  DATETIME NOT NULL,
    finished_at DATETIME,
    total_files INTEGER DEFAULT 0,
    created_by  TEXT                    -- git user or system
);

CREATE TABLE findings (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    review_id   INTEGER NOT NULL REFERENCES reviews(id),
    file_path   TEXT NOT NULL,
    line_start  INTEGER,
    line_end    INTEGER,
    severity    TEXT NOT NULL,          -- 'critical' | 'warning' | 'suggestion'
    category    TEXT,                   -- 'security' | 'performance' | 'style' | 'logic'
    message     TEXT NOT NULL,
    suggestion  TEXT,
    suppressed  BOOLEAN DEFAULT 0       -- user marked as false-positive
);

CREATE TABLE repo_configs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name   TEXT UNIQUE NOT NULL,
    config_yaml TEXT,                   -- serialized YAML content
    updated_at  DATETIME NOT NULL
);

CREATE TABLE team_stats (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    review_id   INTEGER NOT NULL REFERENCES reviews(id),
    author      TEXT NOT NULL,
    file_path   TEXT NOT NULL,
    critical_count  INTEGER DEFAULT 0,
    warning_count   INTEGER DEFAULT 0,
    suggestion_count INTEGER DEFAULT 0
);
```

---

## Architecture / UI Layout

```
┌──────────────────────────────────────────────────────────┐
│  CLI (Click)                                              │
│  codereview scan / pr / history / report / config        │
└───────────────────┬──────────────────────────────────────┘
                    │ reads/writes
          ┌─────────▼──────────┐        ┌─────────────────┐
          │  SQLite Database   │        │  Claude API      │
          │  (SQLAlchemy ORM)  │        │  (findings JSON) │
          └─────────┬──────────┘        └────────┬────────┘
                    │                             │
          ┌─────────▼──────────┐        ┌────────▼────────┐
          │  FastAPI Server    │        │  ReviewEngine   │
          │  /api/reviews      │◄───────│  (chunking +    │
          │  /api/findings     │        │   prompting)    │
          │  /api/stats        │        └─────────────────┘
          └─────────┬──────────┘
                    │ HTTP
          ┌─────────▼──────────┐
          │  Streamlit UI      │
          │  Dashboard /       │
          │  Trends / Reports  │
          └────────────────────┘
```

---

## Key Interactions

### Flow 1: Local Scan via CLI
1. Developer runs `codereview scan ./src --config .codereviewbot.yaml`
2. CLI discovers all `.py`, `.ts`, `.go` files respecting ignore patterns
3. `ReviewEngine` splits each file into ≤ 200-line chunks with 20-line overlap
4. For each chunk, Claude is called with system prompt + code + focus rules
5. JSON findings are validated, deduplicated, and persisted to SQLite
6. Terminal displays color-coded table; exit code 1 if critical findings exist

### Flow 2: GitHub PR Review
1. Developer runs `codereview pr --repo owner/repo --pr 42`
2. PyGithub fetches PR diff; per-file diffs reconstructed
3. Same `ReviewEngine` processes each changed file
4. Findings posted as inline review comments via GitHub Review API
5. Summary comment added to PR with finding counts by severity

### Flow 3: Streamlit Dashboard Navigation
1. User opens `http://localhost:8501` (Streamlit app)
2. Sidebar: select repo and date range
3. Dashboard tab: summary cards + critical trend chart
4. Files tab: top offending files table, click to see findings detail
5. Team tab: per-author breakdown, used in sprint retrospectives

---

## Implementation Steps

1. **Project scaffold** — `pyproject.toml`, `src/codereviewbot/`, `tests/`, `Makefile`
2. **Database layer** — SQLAlchemy models for all 4 tables, Alembic migrations
3. **ReviewEngine** — file chunking, Claude prompt templates, JSON response parser
4. **CLI commands** — `scan`, `pr`, `history`, `report`, `config` using Click
5. **GitHub integration** — PyGithub wrapper, diff parser, comment poster
6. **FastAPI server** — REST endpoints for reviews and findings (used by Streamlit)
7. **Streamlit dashboard** — 3-tab layout, charts with Plotly, filter widgets
8. **Export & reporting** — Jinja2 Markdown template, GitHub comment formatter

---

## Success Criteria

### Functional
- `codereview scan` completes for a 10k-line Python repo in under 60 seconds
- GitHub PR review correctly posts inline comments at the right line numbers
- History and dashboard reflect accurate finding counts matching CLI output

### UX
- CLI output readable in both light and dark terminal themes (Rich styling)
- Dashboard loads in under 2 seconds for 30-day query range
- `.codereviewbot.yaml` documented with inline comments in generated default

### Technical Quality
- All Claude responses validated against Pydantic schema before DB write
- 80%+ unit test coverage on ReviewEngine chunking and prompt logic
- SQLite queries use parameterized statements (no f-string SQL)
- README includes Docker Compose setup for full stack in one command
