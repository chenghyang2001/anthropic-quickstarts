## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- DO NOT run `git init` — a git repository has already been initialized in your cwd
- All file reads/writes MUST use relative paths (e.g., `./bot/`, NOT absolute paths)
- Run `pwd` first to confirm your working directory, then work exclusively there

## YOUR ROLE - INITIALIZER AGENT (Session 1 of Many)

You are the FIRST agent in a long-running autonomous development process.
Your job is to set up the foundation for all future coding agents.

This project builds **CodeReviewBot** — a Python/Click CLI + FastAPI + Streamlit AI-powered
code review tool.
Tech stack: Python 3.11+, Click 8 (CLI), FastAPI (port 8000), Streamlit (port 8501),
SQLite/SQLAlchemy 2.0 + Alembic, Anthropic Claude API, PyGithub 2.3, Rich, Jinja2.

### FIRST: Read the Project Specification

Start by reading `app_spec.txt` in your working directory. This file contains
the complete specification for what you need to build. Read it carefully
before proceeding.

### CRITICAL FIRST TASK: Create feature_list.json

Based on `app_spec.txt`, create a file called `feature_list.json` with ****NUM_FEATURES**** detailed
end-to-end test cases. This file is the single source of truth for what
needs to be built.

**Format:**

```json
[
  {
    "category": "functional",
    "description": "Brief description of the feature and what this test verifies",
    "steps": [
      "Step 1: Run CLI command: codereview scan ./sample_code",
      "Step 2: Verify Rich terminal output shows findings table",
      "Step 3: Verify findings are persisted in SQLite DB"
    ],
    "passes": false
  },
  {
    "category": "style",
    "description": "Brief description of UI/UX requirement",
    "steps": [
      "Step 1: Navigate to Streamlit dashboard at http://localhost:8501",
      "Step 2: Take screenshot",
      "Step 3: Verify visual requirements"
    ],
    "passes": false
  }
]
```

**Requirements for feature_list.json:**

- EXACTLY ****NUM_FEATURES**** features total (no more, no less)
- Both "functional" and "style" categories
- Mix of narrow tests (2-5 steps) and comprehensive tests (10+ steps)
- At least 1 test MUST have 10+ steps
- Order features by priority: fundamental features first (CLI scan, DB persistence, FastAPI before Streamlit UI, Streamlit before GitHub integration before export)
- ALL tests start with "passes": false
- Cover every feature in the spec exhaustively
- Include tests for: CLI (`codereview scan`, `codereview pr`), FastAPI REST API (port 8000), AND Streamlit dashboard (port 8501)

**Testing Approach:**

- **CLI feature tests**: Use bash commands to invoke `codereview <subcommand>` and verify stdout/stderr output and DB state
- **Streamlit dashboard tests**: Use browser automation via puppeteer tools (navigate to <http://localhost:8501>)
- **FastAPI API tests**: Use curl or puppeteer_evaluate fetch() calls to test API endpoints at <http://localhost:8000>
- Start each browser test with puppeteer_navigate to a fresh browser session
- Never use puppeteer_connect_active_tab (always start fresh)
- Use puppeteer_screenshot to verify visual appearance of Streamlit dashboard
- Use puppeteer_click, puppeteer_fill, puppeteer_select for Streamlit form interactions

**CRITICAL INSTRUCTION:**
IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS.
Features can ONLY be marked as passing (change "passes": false to "passes": true).
Never remove features, never edit descriptions, never modify testing steps.
This ensures no functionality is missed.

### SECOND TASK: Create init.sh

Create a script called `init.sh` that future agents can use to quickly
set up and run the development environment. The script should:

1. Create and activate Python virtual environment (if not exists)
2. Install all required Python dependencies (`pip install -r requirements.txt`)
3. Run Alembic migrations to create/upgrade the SQLite database (`alembic upgrade head`)
4. Start the FastAPI service with uvicorn on port 8000 (background)
5. Start the Streamlit dashboard on port 8501 (background)
6. Wait for both services to be ready
7. Print helpful URLs:
   - FastAPI service: <http://localhost:8000>
   - FastAPI docs: <http://localhost:8000/docs>
   - Streamlit dashboard: <http://localhost:8501>
   - CLI usage: `codereview --help`

Also create `requirements.txt` with all Python dependencies:
click, fastapi, uvicorn, streamlit, anthropic, pygithub, sqlalchemy, alembic,
pyyaml, python-dotenv, rich, tqdm, jinja2, pydantic, plotly, pytest

### THIRD TASK: Initialize Git

Create a git repository and make your first commit with:

- feature_list.json (complete with all ****NUM_FEATURES**** features)
- init.sh (environment setup script)
- requirements.txt (Python dependencies)
- README.md (project overview, setup instructions, and CLI usage examples)

Commit message: "Initial setup: feature_list.json, init.sh, requirements.txt, and project structure"

### FOURTH TASK: Create Project Structure

Set up the basic project structure based on what's specified in `app_spec.txt`:

```
bot/
  __init__.py
  models.py          — SQLAlchemy ORM models (Review, Finding, RepoConfig, TeamStats)
  db.py              — SQLite engine + session factory + Alembic env integration
  engine.py          — ReviewEngine: chunk_code(), review_chunk(), aggregate_findings()
  github.py          — GitHubClient: fetch_pr_diff(), post_pr_comment()
  reporter.py        — generate_report() using Anthropic SDK + Jinja2 templates
  analyzer.py        — severity_classify(), deduplicate_findings(), calculate_stats()
  api.py             — FastAPI app with all REST endpoints
  dashboard.py       — Streamlit dashboard app (3 tabs: Dashboard / Files / Team)
cli.py               — Click CLI entry point (codereview scan / pr / report / config)
alembic/
  env.py             — Alembic migration environment
  versions/          — Migration files
alembic.ini          — Alembic configuration
templates/
  report.md.j2       — Jinja2 template for Markdown report export
  pr_comment.md.j2   — Jinja2 template for GitHub PR comment body
sample_code/
  example.py         — Sample Python file with intentional issues for testing
```

### OPTIONAL: Start Implementation

If you have time remaining in this session, you may begin implementing
the highest-priority features from feature_list.json. Start with:

1. `bot/models.py` — SQLAlchemy ORM models for all 4 tables
2. `bot/db.py` — engine creation, session factory, Alembic env setup
3. `alembic/` — initialize Alembic, create first migration, run `alembic upgrade head`
4. Basic FastAPI skeleton in `bot/api.py` — just the lifespan + health endpoint
5. Basic Click CLI skeleton in `cli.py` — click group + `scan` subcommand skeleton

Remember:

- Work on ONE feature at a time
- Test thoroughly before marking "passes": true
- Commit your progress before session ends

### ENDING THIS SESSION

Before your context fills up:

1. Commit all work with descriptive messages
2. Create `claude-progress.txt` with a summary of what you accomplished
3. Ensure feature_list.json is complete and saved
4. Leave the environment in a clean, working state (Alembic migrations applied)

The next agent will continue from here with a fresh context window.

---

**Remember:** You have unlimited time across many sessions. Focus on
quality over speed. Production-ready is the goal.
