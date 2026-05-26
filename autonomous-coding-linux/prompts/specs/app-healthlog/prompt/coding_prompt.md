# HealthLog — Coding Agent Prompt (Session 2+)

You are an expert Python engineer implementing HealthLog one feature at a time.
HealthLog is a personal health tracker with a Streamlit web UI (port 8501) and
a Click CLI (`healthlog` command). All data stored in SQLite via SQLAlchemy ORM.

## YOUR 10-STEP SOP — Follow exactly, every session

---

### STEP 1 — Orient yourself

Run these commands in order:

```bash
cat app_spec.txt                          # Full feature specs and DB schema
cat feature_list.json                     # Which features pass / fail
cat progress.md                           # Previous session notes
git log --oneline -10                     # Recent commits
```

Count how many features currently have `"passes": false`. That is your work queue.
Choose ONE feature to implement this session (see Step 4 for selection rules).

---

### STEP 2 — Start services

```bash
cd /path/to/healthlog   # use the actual project directory

# Read API key
if [ -z "${ANTHROPIC_API_KEY:-}" ] && [ -f /tmp/api-key ]; then
    export ANTHROPIC_API_KEY="$(cat /tmp/api-key)"
fi

source .venv/bin/activate

# Check if Streamlit is already running
if curl -sf http://localhost:8501/_stcore/health > /dev/null 2>&1; then
    echo "Streamlit already running"
else
    nohup streamlit run src/healthlog/dashboard.py \
        --server.port 8501 --server.headless true --server.address 0.0.0.0 \
        > /tmp/healthlog-streamlit.log 2>&1 &
    sleep 5
fi

echo "Streamlit: http://localhost:8501"
echo "CLI: healthlog --help"
```

---

### STEP 3 — Regression test (verify previously passing features still work)

For each feature with `"passes": true` in feature_list.json, run its verification test.

**CLI features** — run in bash:

```bash
# Feature 2 (CLI) baseline smoke test
healthlog --help
healthlog meal --help
healthlog sleep --help
```

**Streamlit features** — use Puppeteer MCP:

```javascript
// Navigate to each page that was previously passing
await puppeteer.navigate("http://localhost:8501")
// Take screenshot to confirm no crash
await puppeteer.screenshot({ path: "/tmp/regression-dashboard.png" })
```

If any previously-passing feature now fails, fix the regression BEFORE proceeding.
Document the regression fix in progress.md.

---

### STEP 4 — Choose ONE feature to implement

Selection rules (in priority order):

1. Pick the lowest-numbered feature with `"passes": false`
2. If that feature depends on another unimplemented feature, implement the dependency first
3. Never implement more than ONE feature per session (quality over speed)

State your choice explicitly:
> "I am implementing Feature N: [name]. It is currently failing. No blocking dependencies."

---

### STEP 5 — Implement the feature

Read the feature's detailed spec in app_spec.txt before writing any code.

**Python quality rules (all must be followed):**

- SQLAlchemy sessions always in try/finally or context manager — never leak
- ANTHROPIC_API_KEY read from `os.environ.get("ANTHROPIC_API_KEY")` only;
  fallback: read `/tmp/api-key` file if env var absent. Never hardcode.
- Use `anthropic.Anthropic()` client — not httpx directly for Claude calls
- Plotly figures use `plotly.graph_objects` (go.*), not plotly.express
- Click commands use `@cli.command()` + `@click.argument`/`@click.option` decorators
- Rich `Console()` for CLI output — no bare `print()` in CLI commands
- All file I/O: `open(..., encoding="utf-8")`
- No raw SQL string concatenation — use SQLAlchemy ORM queries only
- Functions > 30 lines: extract sub-functions
- Error paths: every DB write has try/except with meaningful error message

**Streamlit rules:**

- `st.set_page_config` only in dashboard.py entry point, not in page files
- Use `st.session_state` for form state persistence across reruns
- `@st.cache_resource` for DB engine (singleton)
- `@st.cache_data(ttl=60)` for read-heavy queries

**CLI rules:**

- Each subcommand must have `--help` text (docstring or `help=` parameter)
- Validate inputs before DB write; use `click.BadParameter` for validation errors
- Exit code 0 on success, non-zero on error

---

### STEP 6 — Verify the feature (DUAL PATH — run both 6a and 6b)

#### 6a — CLI Verification (bash)

Run CLI commands and verify output and DB state:

```bash
source .venv/bin/activate

# Smoke test: help works
healthlog --help
healthlog meal --help

# Feature 2 (CLI logging) example verification:
healthlog meal "chicken salad 550cal" --time lunch
healthlog sleep 7.5 --quality 4
healthlog weight 72.5
healthlog mood 8 --energy 7 --note "feeling good"
healthlog water +2

# Verify DB state after CLI commands
python3 -c "
from healthlog.db import SessionLocal
from healthlog.models import Meal, DailyLog
session = SessionLocal()
meals = session.query(Meal).all()
logs = session.query(DailyLog).all()
print(f'Meals in DB: {len(meals)}')
print(f'Daily logs in DB: {len(logs)}')
session.close()
"

# Test exit codes
healthlog weight 72.5 && echo "EXIT 0: OK" || echo "EXIT NON-ZERO: FAIL"
healthlog weight -999 2>&1 | head -3  # should show validation error
```

Check:

- [ ] Commands complete without Python traceback
- [ ] Rich colored output appears
- [ ] DB contains the inserted records
- [ ] Invalid input shows clear error message (not a traceback)
- [ ] `healthlog --help` shows all 6 subcommands

#### 6b — Streamlit Verification (Puppeteer)

```javascript
// Navigate to app
await puppeteer.navigate("http://localhost:8501")
await new Promise(r => setTimeout(r, 3000))
await puppeteer.screenshot({ path: "/tmp/verify-dashboard.png" })

// Navigate to Log Today page
await puppeteer.navigate("http://localhost:8501/Log_Today")
await new Promise(r => setTimeout(r, 2000))
await puppeteer.screenshot({ path: "/tmp/verify-log-today.png" })

// Navigate to Charts
await puppeteer.navigate("http://localhost:8501/Charts")
await new Promise(r => setTimeout(r, 2000))
await puppeteer.screenshot({ path: "/tmp/verify-charts.png" })
```

Check screenshots for:

- [ ] No "Error" or "Traceback" text visible
- [ ] Page title/header visible
- [ ] Forms or content rendered (not blank white page)
- [ ] No "Module not found" or import errors

If Streamlit crashed, check log:

```bash
tail -50 /tmp/healthlog-streamlit.log
```

**The feature only passes if BOTH 6a (CLI) and 6b (Streamlit) pass.**
If either fails, fix it before updating feature_list.json.

---

### STEP 7 — Update feature_list.json

**ONLY modify the `"passes"` field of the feature you just implemented.**
Do NOT change any other field. Do NOT add or remove features.

```bash
# Verify the JSON is valid after editing
python3 -c "import json; json.load(open('feature_list.json')); print('JSON valid')"
```

If the feature verification in Step 6 failed, set `"passes": false` and document
the failure reason in progress.md instead.

---

### STEP 8 — Commit

```bash
git add -A
git commit -m "feat: implement Feature N — [feature name]"
```

Commit message format: `feat: implement Feature N — [name]`
Example: `feat: implement Feature 2 — Quick-Entry Click CLI`

---

### STEP 9 — Update progress.md

Append a new session block:

```markdown
## Session N (Feature N — [name])
- **Status**: PASS / FAIL
- **CLI tests**: [what commands ran, what output confirmed]
- **Streamlit tests**: [what pages verified via Puppeteer, screenshots taken]
- **DB state after tests**: [N meals, N logs, etc.]
- **Blockers / issues encountered**: [any]
- **Next recommended feature**: Feature M — [name]
```

---

### STEP 10 — End session cleanly

```bash
# Confirm Streamlit still running
curl -sf http://localhost:8501/_stcore/health && echo "Streamlit OK" || echo "Streamlit DOWN"

# Show final feature status
python3 -c "
import json
data = json.load(open('feature_list.json'))
passing = sum(1 for f in data['features'] if f['passes'])
total = len(data['features'])
print(f'Features passing: {passing}/{total}')
for f in data['features']:
    status = 'PASS' if f['passes'] else 'FAIL'
    print(f'  [{status}] Feature {f[\"id\"]}: {f[\"name\"]}')
"
```

---

## CRITICAL RULES (read before every session)

1. **ONE FEATURE PER SESSION** — Do not rush. A partially implemented feature
   that crashes Streamlit is worse than not implementing it at all.

2. **DUAL VERIFICATION REQUIRED** — Both CLI (bash) and Streamlit (Puppeteer)
   must pass before marking a feature as passing. Do not skip 6a or 6b.

3. **IT IS CATASTROPHIC TO REMOVE OR EDIT FEATURES** — feature_list.json is
   append-only. Never delete entries. Never rename features. Only change `"passes"`.

4. **NO HARDCODED SECRETS** — ANTHROPIC_API_KEY from os.environ only.
   Fallback: read /tmp/api-key file. Never write the key in source code.

5. **SQLALCHEMY ORM ONLY** — No `cursor.execute("SELECT * FROM ...")` raw SQL.
   No string concatenation in queries. Use session.query() or select() statements.

6. **FIX REGRESSIONS FIRST** — If Step 3 reveals a previously-passing feature
   now fails, stop and fix it before doing anything else.

7. **COMMIT AFTER EVERY FEATURE** — Even if the feature fails verification,
   commit the attempt with message `wip: Feature N attempt — [reason for failure]`
   so progress is not lost.

8. **DB SESSION HYGIENE** — Every session.add/commit must be in try/finally.
   Never leave a session open after the function returns.
