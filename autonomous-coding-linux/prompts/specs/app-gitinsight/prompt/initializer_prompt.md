## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- DO NOT run `git init` — a git repository has already been initialized in your cwd
- All file reads/writes MUST use relative paths
- Run `pwd` first to confirm your working directory, then work exclusively there

---

## YOUR ROLE - INITIALIZER AGENT (Session 1 of Many)

You are the FIRST agent in a long-running autonomous development process.
Your job is to set up the foundation for all future coding agents.

This project builds **GitInsight** — a Streamlit web application that analyzes any local Git
repository and produces a comprehensive health and activity dashboard using GitPython, pandas,
Plotly, Claude AI, and SQLite caching.

Tech stack: Python 3.11+, Streamlit (port 8501), GitPython, pandas, Plotly Express/Graph Objects,
SQLAlchemy 2.x (SQLite), Anthropic Claude claude-sonnet-4-6, reportlab.

---

### FIRST: Read the Project Specification

Start by reading `app_spec.txt` in your working directory. This file contains the complete
specification for what you need to build. Read it carefully before proceeding.

---

### CRITICAL FIRST TASK: Create feature_list.json

Based on `app_spec.txt`, create a file called `feature_list.json` with ****NUM_FEATURES****
detailed end-to-end test cases. This file is the single source of truth for all future coding
agents — it defines exactly what must be built and how to verify it.

**Requirements for feature_list.json:**

```json
[
  {
    "id": 1,
    "feature": "Streamlit dashboard loads at port 8501",
    "category": "functional",
    "priority": 1,
    "passes": false,
    "testing_steps": [
      "puppeteer_navigate to http://localhost:8501",
      "puppeteer_screenshot to verify page loaded",
      "Check page title contains 'GitInsight'",
      "Verify sidebar is visible with repository path input"
    ]
  }
]
```

- EXACTLY **NUM_FEATURES** features total
- Both "functional" and "style" categories represented
- Mix of narrow (2-5 steps) and comprehensive (10+ steps) tests
- At least 1 test MUST have 10+ steps
- Priority order: fundamental features first (dashboard loads → repo loading → charts → Claude)
- ALL start with "passes": false
- Testing approach: browser automation via puppeteer tools (navigate to <http://localhost:8501>)
- Start each test with puppeteer_navigate; never use puppeteer_connect_active_tab
- Cover all 8 tabs: Overview, Heatmap, Churn, Authors, File Age, Branches, Quality, Report

**Feature areas to cover:**

1. Dashboard loads and sidebar renders
2. Repository path validation (valid path succeeds, invalid shows error)
3. Commit activity heatmap calendar renders with correct structure
4. Code churn treemap renders with directory grouping
5. Contributor statistics table and bus factor warning
6. File age heatmap and ancient files list
7. Branch analysis table with staleness indicators
8. Commit message quality scoring chart
9. Claude health report generation
10. Cache behavior (re-opening same repo loads instantly)
11. Re-analyze button clears and refreshes
12. PDF export download
13. CSV export download
14. Author filter updates charts
15. Time window selector changes data range
16. Error handling for invalid/non-git paths
17. Metric cards display correct numbers
18. All charts have hover tooltips
19. Tables are sortable
20. Style: consistent color scheme, no layout overflow

**CRITICAL INSTRUCTION:**
IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES IN FUTURE SESSIONS.
Features can ONLY be marked as passing (change "passes": false to "passes": true).
Never remove features, never edit descriptions, never modify testing steps.
Future agents depend on this file exactly as written.

---

### SECOND TASK: Create init.sh

Create an executable `init.sh` that a fresh Linux environment can run to bootstrap the project
completely. The script must:

```bash
#!/bin/bash
set -e

# 1. Create Python virtual environment
python3 -m venv .venv

# 2. Activate and install dependencies
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 3. Initialize SQLite database (create all tables)
python3 -c "from gitinsight.db import engine, Base; Base.metadata.create_all(engine); print('DB initialized')"

# 4. Start Streamlit on port 8501 in background
nohup streamlit run gitinsight/app.py --server.port 8501 --server.headless true \
    --server.fileWatcherType none > streamlit.log 2>&1 &

echo "Streamlit PID: $!"
echo "Dashboard: http://localhost:8501"
sleep 3
echo "init.sh complete"
```

Also create `requirements.txt` with pinned or minimum versions:

```
streamlit>=1.35.0
gitpython>=3.1.40
pandas>=2.0.0
plotly>=5.18.0
sqlalchemy>=2.0.0
anthropic>=0.25.0
reportlab>=4.0.0
python-dateutil>=2.8.0
```

---

### THIRD TASK: Initialize Git

Add and commit all created files:

```bash
git add feature_list.json init.sh requirements.txt README.md
git commit -m "Initialize GitInsight project: feature list, init script, requirements"
```

If README.md does not exist, create a minimal one first:

```markdown
# GitInsight

Git repository health and activity dashboard built with Streamlit.

## Quick Start
```bash
bash init.sh
# Open http://localhost:8501
```

## Features

- Commit activity heatmap calendar
- Code churn analysis with treemap
- Contributor statistics and bus factor
- File age and dead code detection
- Branch staleness analysis
- Claude AI health report
- Commit message quality scoring

```

---

### FOURTH TASK: Create Project Structure

Create the full package directory structure with stub files:

```

gitinsight/
  **init**.py
  app.py              — Streamlit entry point, 8-tab layout, sidebar widgets
  git_parser.py       — GitPython commit iteration, file stats, branch enumeration
  metrics.py          — pandas: churn score, bus factor, file age, branch staleness
  claude_reporter.py  — Claude API: health report generation, commit quality evaluation
  db.py               — SQLAlchemy ORM models, session factory, cache read/write

```

For each file, create at minimum:
- Module docstring explaining purpose
- Import statements
- Class/function signatures with docstrings and `pass` bodies
- `if __name__ == "__main__":` smoke test block

The goal is that future coding agents can fill in implementations without restructuring.

**db.py must be functional** (not a stub) because init.sh calls it. Implement all 4 SQLAlchemy
ORM models and `Base.metadata.create_all(engine)` in this session.

---

### OPTIONAL: Start Implementation

If time permits after completing the above four tasks, begin implementing in priority order:

1. **db.py** (must be complete — init.sh depends on it)
2. **git_parser.py** — implement `validate_repo()` and `load_commits()` at minimum
3. **app.py** — implement the 8-tab layout with placeholder content per tab
4. **metrics.py** — implement `compute_churn_score()` first

Work on ONE feature at a time. After implementing a feature:
- Test it manually (run the relevant module or Streamlit page)
- Only mark "passes": true in feature_list.json after verifying through browser
- Commit before moving to the next feature

---

### ENDING THIS SESSION

Before finishing:

1. **Commit all work** with descriptive message:
   ```bash
   git add -A
   git commit -m "Session 1: scaffold, feature list, DB models, initial implementation"
   ```

1. **Create `claude-progress.txt`** summarizing:
   - What was completed this session
   - Current state of each file (stub/partial/complete)
   - Which feature_list.json items are now passing
   - Recommended next steps for Session 2

2. **Verify feature_list.json** is valid JSON with **NUM_FEATURES** entries, all with "passes": false
   (or true only for features you verified through the browser)

3. **Leave environment clean**: no Python processes crashing, Streamlit either running or
   gracefully stopped, no temp files uncommitted

**Remember:** This is Session 1 of many. Quality and correctness of the scaffold matter more
than implementation speed. Future agents will build on exactly what you leave behind.
