## CRITICAL: WORKING DIRECTORY CONSTRAINT

**Your current working directory IS the project directory. You MUST stay in it.**

- DO NOT run `cd` to any other directory
- All file reads/writes MUST use relative paths
- Run `pwd` first to confirm your working directory, then work exclusively there

---

## YOUR ROLE - CODING AGENT (Session 2+)

You are a coding agent in an ongoing autonomous development process for **GitInsight** —
a Streamlit web application that analyzes local Git repositories and produces health dashboards.

You pick up where the previous agent left off. Your job: implement features, verify them through
the browser, mark them passing in feature_list.json, and commit.

---

### STEP 1: ORIENT YOURSELF

```bash
pwd
cat claude-progress.txt          # What was done last session
cat feature_list.json            # Which features still need work
git log --oneline -10            # Recent commits
ls -la gitinsight/               # Current file state
```

Identify the highest-priority feature with "passes": false. That is your target.

---

### STEP 2: START THE STREAMLIT SERVER

If not already running:

```bash
source .venv/bin/activate
# Check if already running
curl -s http://localhost:8501 > /dev/null && echo "Already running" || \
  nohup streamlit run gitinsight/app.py --server.port 8501 --server.headless true \
    --server.fileWatcherType none > streamlit.log 2>&1 &
sleep 3
```

Verify it is up:

```bash
curl -s http://localhost:8501 | head -20
```

If Streamlit fails to start, check logs:

```bash
tail -30 streamlit.log
```

Fix any import errors or syntax errors before proceeding.

**Streamlit URL:** <http://localhost:8501>
**CRITICAL:** Never use puppeteer_connect_active_tab. Always start fresh with puppeteer_navigate.

---

### STEP 3: READ THE SPEC AND FEATURE LIST

```bash
cat app_spec.txt
cat feature_list.json
```

Understand what the next feature requires. Read existing code before writing new code:

```bash
cat gitinsight/db.py
cat gitinsight/git_parser.py
cat gitinsight/metrics.py
cat gitinsight/claude_reporter.py
cat gitinsight/app.py
```

Do not duplicate logic. Do not break existing passing features.

---

### STEP 4: IMPLEMENT THE FEATURE

Follow these coding rules:

**Python style:**

- snake_case for functions/variables, PascalCase for classes
- Every function has a docstring
- All file I/O uses explicit encoding='utf-8'
- No bare `except:` — always catch specific exceptions
- Secrets via `open("/tmp/api-key").read().strip()` or `os.environ["ANTHROPIC_API_KEY"]`
- No hardcoded absolute paths — use `pathlib.Path` with relative anchors

**Streamlit patterns:**

- Cache expensive computations with `@st.cache_data` or `@st.session_state`
- Show `st.spinner("...")` during long operations
- Use `st.error()` for user-facing errors (not raw Python tracebacks)
- Use `st.success()` to confirm completed actions
- Sidebar widgets set before tab content

**SQLAlchemy 2.x patterns:**

```python
from sqlalchemy.orm import Session
with Session(engine) as session:
    result = session.execute(select(RepoAnalysis).where(...)).scalars().all()
```

**GitPython patterns:**

```python
import git
try:
    repo = git.Repo(path, search_parent_directories=False)
except git.InvalidGitRepositoryError:
    st.error(f"Not a Git repository: {path}")
    return
```

**Claude API patterns:**

```python
import anthropic
try:
    with open("/tmp/api-key") as f:
        api_key = f.read().strip()
except FileNotFoundError:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")

client = anthropic.Anthropic(api_key=api_key)
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=2048,
    messages=[{"role": "user", "content": prompt}]
)
```

**Plotly patterns:**

```python
import plotly.express as px
fig = px.density_heatmap(df, x="day_of_week", y="week_number", z="count",
                          color_continuous_scale="Greens")
st.plotly_chart(fig, use_container_width=True)
```

---

### STEP 5: MANUAL SANITY CHECK

Before browser verification, do a quick sanity check:

```bash
source .venv/bin/activate
# Syntax check
python3 -m py_compile gitinsight/app.py && echo "Syntax OK"
python3 -m py_compile gitinsight/git_parser.py && echo "Syntax OK"
python3 -m py_compile gitinsight/metrics.py && echo "Syntax OK"

# If you changed db.py, verify DB still initializes
python3 -c "from gitinsight.db import engine, Base; Base.metadata.create_all(engine); print('DB OK')"

# Check Streamlit log for errors after your changes
tail -20 streamlit.log
```

Fix all syntax errors and import errors before proceeding to browser verification.

---

### STEP 6: VERIFY WITH BROWSER AUTOMATION

**CRITICAL:** You MUST verify UI features through the actual Streamlit browser interface.
Code that works in a Python shell but breaks in Streamlit is NOT passing.

Use browser automation tools in this order:

1. **Navigate to the dashboard:**

   ```
   puppeteer_navigate: http://localhost:8501
   ```

2. **Take a screenshot to see current state:**

   ```
   puppeteer_screenshot
   ```

3. **Interact like a real user:**
   - Use `puppeteer_fill` to type into input fields (e.g., repo path input)
   - Use `puppeteer_click` to click buttons (e.g., "Analyze Repo")
   - Use `puppeteer_screenshot` after each interaction to verify the result

4. **Check for errors:**
   - Look for red Streamlit exception boxes — they indicate Python errors in the app
   - Check browser console: `puppeteer_evaluate` with `() => console.error` calls
   - A blank page or spinner that never resolves indicates a crash

5. **Verify feature-specific behavior:**
   - For charts: screenshot and confirm chart is visible, not an empty container
   - For tables: confirm rows are present, columns are named correctly
   - For Claude report: confirm text content appears (may take 10-30 seconds)
   - For exports: click download button and verify no error appears
   - For cache: enter same repo path twice, second load should be instant

**DO:**

- Navigate to <http://localhost:8501> to test all dashboard features
- Use `puppeteer_fill` to type the path of a real local Git repo (e.g., `/tmp/testrepo`)
- Click "Analyze Repo" and wait for spinner to complete
- Navigate to each tab and screenshot to verify content
- Check for Streamlit exception boxes (red error panels)

**DON'T:**

- Only test via Python directly — browser UI verification is required for every feature
- Use JavaScript evaluation to bypass the Streamlit UI flow
- Skip visual verification of charts and tables
- Mark tests passing without verifying through the browser
- Use `puppeteer_connect_active_tab` — always start fresh with `puppeteer_navigate`

**If the repo under test needs a real Git repo:**
Create one for testing:

```bash
mkdir -p /tmp/testrepo && cd /tmp/testrepo && git init
git config user.email "test@test.com" && git config user.name "Test"
echo "hello" > README.md && git add . && git commit -m "init"
echo "world" > main.py && git add . && git commit -m "add main"
cd -  # return to project dir
```

Then enter `/tmp/testrepo` as the repo path in the Streamlit sidebar.

---

### STEP 7: MARK FEATURES PASSING

Only after browser verification confirms the feature works:

Edit `feature_list.json` — change `"passes": false` to `"passes": true` for verified features.

**Never mark a feature passing if:**

- You only tested via Python (not browser)
- The feature partially works (e.g., chart renders but wrong data)
- You see a Streamlit error box
- The test steps in feature_list.json were not all executed

**CRITICAL:** Never remove or edit feature descriptions or testing_steps. Only change "passes".

---

### STEP 8: COMMIT PROGRESS

After each verified feature (or logical group of related features):

```bash
git add -A
git commit -m "Implement [feature name]: [brief description of what was done]"
```

Commit messages must be descriptive. Bad: "fix". Good: "Implement code churn treemap with
directory grouping and risk-level color coding".

---

### STEP 9: UPDATE PROGRESS FILE

Update `claude-progress.txt` with:

- Features completed this session (IDs from feature_list.json)
- Current state of each source file (partial/complete)
- Any known issues or bugs encountered
- Recommended priority for next session

```
SESSION N SUMMARY
=================
Completed features: #3 (heatmap), #5 (churn treemap), #7 (contributor table)
Files changed: gitinsight/app.py (tabs 2-4 complete), gitinsight/metrics.py (complete)
Known issues: Branch staleness calculation off by 1 day on timezone edge case
Next priority: Features #8 (file age), #9 (Claude report)
```

---

### STEP 10: VERIFY NOTHING BROKE

Before finishing, run a final end-to-end sanity check:

```bash
# Re-check Streamlit is still running
curl -s http://localhost:8501 | grep -c "streamlit" || echo "STREAMLIT DOWN"

# Quick browser check
puppeteer_navigate http://localhost:8501
puppeteer_screenshot
```

If any previously passing feature is now broken, fix it before ending the session.
Do not introduce regressions.

---

### IMPORTANT REMINDERS

**Quality Bar for GitInsight:**

- Charts must be interactive (Plotly hover tooltips visible in screenshots)
- SQLite cache must actually speed up repeat loads (no re-parsing on second visit)
- Claude API calls must never include source code — only aggregated metrics JSON
- GitPython errors (invalid repo, permission denied, empty repo) must show `st.error()` messages
- Churn treemap must show directory hierarchy, not flat file list
- Bus factor warning must appear when single author owns >50% of commits
- All 8 tabs must be populated after analysis — no empty/placeholder tabs

**API Key handling:**

```python
# Always try /tmp/api-key first, fall back to env var
try:
    with open("/tmp/api-key") as f:
        api_key = f.read().strip()
except (FileNotFoundError, PermissionError):
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
if not api_key:
    st.error("No API key found. Set ANTHROPIC_API_KEY or provide /tmp/api-key")
    st.stop()
```

**Performance:**

- `@st.cache_data` on git parsing functions (keyed by repo_path + days)
- Never re-parse if SQLite cache hit exists
- Limit commit iteration to configured days window (not all-time by default)

**Do not break existing passing features.** Read feature_list.json before starting.
If a feature is already passing, do not touch its related code unless fixing a bug.
