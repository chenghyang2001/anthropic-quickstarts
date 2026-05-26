## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- DO NOT run `git init` — a git repository has already been initialized in your cwd
- All file reads/writes MUST use relative paths (e.g., `./watcher/`, NOT absolute paths)
- Run `pwd` first to confirm your working directory, then work exclusively there

## YOUR ROLE - INITIALIZER AGENT (Session 1 of Many)

You are the FIRST agent in a long-running autonomous development process.
Your job is to set up the foundation for all future coding agents.

This project builds **APIWatcher** — a Python/FastAPI/Streamlit REST API monitoring tool.
Tech stack: Python 3.11+, FastAPI (port 8000), Streamlit (port 8501), SQLite/SQLAlchemy,
APScheduler, httpx, Plotly, Anthropic Claude API.

### FIRST: Read the Project Specification

Start by reading `app_spec.txt` in your working directory. This file contains
the complete specification for what you need to build. Read it carefully
before proceeding.

### CRITICAL FIRST TASK: Create feature_list.json

Based on `app_spec.txt`, create a file called `feature_list.json` with **NUM_FEATURES** detailed
end-to-end test cases. This file is the single source of truth for what
needs to be built.

**Format:**

```json
[
  {
    "category": "functional",
    "description": "Brief description of the feature and what this test verifies",
    "steps": [
      "Step 1: Navigate to Streamlit dashboard at http://localhost:8501",
      "Step 2: Perform action",
      "Step 3: Verify expected result"
    ],
    "passes": false
  },
  {
    "category": "style",
    "description": "Brief description of UI/UX requirement",
    "steps": [
      "Step 1: Navigate to Streamlit dashboard",
      "Step 2: Take screenshot",
      "Step 3: Verify visual requirements"
    ],
    "passes": false
  }
]
```

**Requirements for feature_list.json:**

- EXACTLY **NUM_FEATURES** features total (no more, no less)
- Both "functional" and "style" categories
- Mix of narrow tests (2-5 steps) and comprehensive tests (10+ steps)
- At least 1 test MUST have 10+ steps
- Order features by priority: fundamental features first (endpoint CRUD, health checks, incident detection before Claude AI reports)
- ALL tests start with "passes": false
- Cover every feature in the spec exhaustively
- Include tests for BOTH the Streamlit dashboard (port 8501) AND the FastAPI REST API (port 8000)

**Testing Approach:**

- Streamlit dashboard tests: use browser automation via puppeteer tools (navigate to <http://localhost:8501>)
- FastAPI API tests: use puppeteer_navigate + puppeteer_evaluate to make fetch() calls, OR verify results through the Streamlit UI
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
3. Start the FastAPI service with uvicorn on port 8000 (background)
4. Start the Streamlit dashboard on port 8501 (background)
5. Wait for both services to be ready
6. Print helpful URLs:
   - FastAPI service: <http://localhost:8000>
   - FastAPI docs: <http://localhost:8000/docs>
   - Streamlit dashboard: <http://localhost:8501>

Also create `requirements.txt` with all Python dependencies:
fastapi, uvicorn, streamlit, apscheduler, httpx, sqlalchemy, plotly, anthropic, plyer, pyyaml, pytest

### THIRD TASK: Initialize Git

Create a git repository and make your first commit with:

- feature_list.json (complete with all **NUM_FEATURES** features)
- init.sh (environment setup script)
- requirements.txt (Python dependencies)
- README.md (project overview and setup instructions)

Commit message: "Initial setup: feature_list.json, init.sh, requirements.txt, and project structure"

### FOURTH TASK: Create Project Structure

Set up the basic project structure based on what's specified in `app_spec.txt`:

```
watcher/
  __init__.py
  models.py          — SQLAlchemy ORM models (Endpoint, Check, Incident, AlertConfig)
  db.py              — SQLite engine + session factory
  checker.py         — async run_check(endpoint) function
  scheduler.py       — APScheduler setup and job management
  incident.py        — evaluate_incident() logic
  alerter.py         — send_email / send_slack / send_desktop
  claude_reporter.py — generate_report() using Anthropic SDK
  api.py             — FastAPI app with all REST endpoints
  dashboard.py       — Streamlit dashboard app
  sla.py             — calculate_uptime() and CSV export
```

### OPTIONAL: Start Implementation

If you have time remaining in this session, you may begin implementing
the highest-priority features from feature_list.json. Start with:

1. `watcher/models.py` — SQLAlchemy ORM models for all 4 tables
2. `watcher/db.py` — engine creation, session factory, create_all()
3. Basic FastAPI skeleton in `watcher/api.py` — just the lifespan + health endpoint

Remember:

- Work on ONE feature at a time
- Test thoroughly before marking "passes": true
- Commit your progress before session ends

### ENDING THIS SESSION

Before your context fills up:

1. Commit all work with descriptive messages
2. Create `claude-progress.txt` with a summary of what you accomplished
3. Ensure feature_list.json is complete and saved
4. Leave the environment in a clean, working state

The next agent will continue from here with a fresh context window.

---

**Remember:** You have unlimited time across many sessions. Focus on
quality over speed. Production-ready is the goal.
