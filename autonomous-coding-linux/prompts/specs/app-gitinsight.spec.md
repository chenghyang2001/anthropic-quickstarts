# App Specification: GitInsight — Git Repository Analytics & Health Dashboard

## Project Overview

GitInsight is a Streamlit web application that analyzes any local Git repository and produces
a comprehensive health and activity dashboard. GitPython reads commit history, file change logs,
and branch metadata without modifying the repository. pandas aggregates the raw commit data into
contributor statistics, code churn indicators, and temporal activity patterns visualized with
Plotly. Claude synthesizes all metrics into a plain-English repository health report that
highlights risks, stale areas, and team dynamics. Results are cached in SQLite so repeat views
are instantaneous without re-parsing the entire commit log.

---

## Technology Stack

| Layer           | Technology                                     |
|-----------------|------------------------------------------------|
| Language        | Python 3.11+                                   |
| Web Framework   | Streamlit                                      |
| Git Access      | GitPython                                      |
| Data Analysis   | pandas                                         |
| Charts          | Plotly Express + Plotly Graph Objects          |
| Database        | SQLite (via SQLAlchemy 2.x ORM, result cache)  |
| AI              | Anthropic Claude API (`claude-sonnet-4-6`)     |
| PDF Export      | reportlab                                      |
| Dependencies    | streamlit, gitpython, pandas, plotly,          |
|                 | sqlalchemy, anthropic, reportlab               |

---

## Core Features

### 1. Repository Selection and Loading
- Repository path input: text field or folder browser dialog (via `tkinter.filedialog`)
- Validation: check `.git` directory exists, repo is not bare, readable permissions
- Load options: full history (all commits) or last N days (default: 90 days)
- Shallow repos detected and warned (limited history available)
- Multiple repo tabs: open and compare up to 3 repositories simultaneously
- Repo metadata shown: total commits, contributors, branches, first commit date, last commit date

### 2. Commit Activity Heatmap Calendar
- GitHub-style contribution calendar: day cells colored by commit count intensity
- Color scale: white (0) → light green → dark green (max activity day)
- Tooltip: exact count on hover, list of authors for that day
- Filters: by author, by file path prefix (e.g., show only `src/` commits)
- Week-of-year and hour-of-day breakdown (when do commits happen?)
- Animation: playback option to watch commit activity over time (Plotly animation frames)

### 3. Code Churn Analysis
- Per-file churn score: `(additions + deletions) / total_lines` over analysis period
- Top 20 highest-churn files displayed as sortable table
- Risk indicator logic: churn > 0.8 AND commit_count > 10 → flag as HIGH RISK
- Churn vs. bug correlation (if commit messages contain "fix" / "bug" / "hotfix")
- File type breakdown: which file extensions have highest churn
- Treemap chart: churn intensity by directory, color = risk level

### 4. Contributor Statistics
- Per-author metrics: commits, lines added, lines deleted, net change, active days, last commit
- Author activity timeline: stacked area chart of commits per week per author (Plotly)
- Ownership map: which files are predominantly owned by which author (> 50% of changes)
- Bus factor warning: files where single author > 80% of commits (key person dependency)
- Inactive contributor detection: > 45 days without commit flagged in table
- Author commit message quality (feeds into Feature 8)

### 5. File Age Map
- "Last touched" date per file across entire tracked file tree
- Heatmap: directory tree with color = days since last commit
  - Green: < 30 days, Yellow: 30-90 days, Orange: 90-180 days, Red: > 180 days
- "Ancient files" list: all files untouched > 6 months with last author and last commit message
- Filter by: file extension, directory prefix
- Dead code candidates: files > 12 months old with < 5 lifetime commits
- Click file → show full commit history for that specific file

### 6. Claude Repository Health Report
- Aggregated metrics sent to Claude (no actual code content — just statistics)
- Report sections:
  - Executive summary (3-4 sentences, non-technical)
  - Risk indicators: high-churn files, bus factor warnings, stale branches
  - Team health: contributor diversity, activity trends, inactive members
  - Codebase aging: % files untouched > 6 months, oldest vs newest areas
  - 5 specific, actionable recommendations ranked by priority
- Report cached in SQLite; regenerate button available
- Export as PDF section within full repository PDF report

### 7. Branch Analysis
- List all branches: local + remote, last commit date, author, ahead/behind main
- Stale branches: no commits in > 30 days, listed with age and last author
- Branch count trend: how many branches have been opened/closed per month
- Merge frequency: avg days from branch creation to merge (PR cycle time proxy)
- Orphan branches: branches with 0 merges and > 60 days old (likely abandoned)
- Branch naming convention analysis: % following `feature/` `fix/` `hotfix/` prefixes

### 8. Commit Message Quality Scoring
- Claude evaluates a sample of 50 recent commit messages (not code)
- Scoring rubric:
  - Clarity: does it explain WHAT changed? (0-3 pts)
  - Intent: does it explain WHY? (0-3 pts)
  - Convention: follows Conventional Commits / team standard? (0-2 pts)
  - Length: 20-72 chars subject line? (0-2 pts)
- Score per message (0-10), average score for repo
- Examples shown: best 3 and worst 3 messages with Claude's annotation
- Team breakdown: average score per author

---

## Database Schema (Cache Layer)

```sql
CREATE TABLE repo_analyses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_path       TEXT NOT NULL,
    repo_name       TEXT NOT NULL,
    analyzed_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    days_analyzed   INTEGER DEFAULT 90,
    total_commits   INTEGER,
    total_files     INTEGER,
    total_authors   INTEGER,
    first_commit    DATE,
    last_commit     DATE,
    claude_report   TEXT,
    commit_quality_score REAL
);

CREATE TABLE file_metrics (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id     INTEGER NOT NULL REFERENCES repo_analyses(id) ON DELETE CASCADE,
    file_path       TEXT NOT NULL,
    churn_score     REAL,
    commit_count    INTEGER,
    last_touched    DATE,
    primary_author  TEXT,
    lines_added     INTEGER,
    lines_deleted   INTEGER,
    risk_level      TEXT DEFAULT 'LOW'  -- LOW | MEDIUM | HIGH
);

CREATE TABLE contributor_stats (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id     INTEGER NOT NULL REFERENCES repo_analyses(id) ON DELETE CASCADE,
    author_name     TEXT NOT NULL,
    author_email    TEXT,
    commit_count    INTEGER,
    lines_added     INTEGER,
    lines_deleted   INTEGER,
    active_days     INTEGER,
    first_commit    DATE,
    last_commit     DATE,
    is_active       BOOLEAN DEFAULT 1
);

CREATE TABLE branch_info (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id     INTEGER NOT NULL REFERENCES repo_analyses(id) ON DELETE CASCADE,
    branch_name     TEXT NOT NULL,
    last_commit_date DATE,
    last_author     TEXT,
    is_merged       BOOLEAN DEFAULT 0,
    days_inactive   INTEGER,
    is_stale        BOOLEAN DEFAULT 0,
    commit_count    INTEGER
);
```

---

## Architecture / UI Layout

```
┌───────────────────────────────────────────────────────────────────┐
│  GitInsight                                                       │
├──────────────────┬────────────────────────────────────────────────┤
│  SIDEBAR         │  MAIN DASHBOARD                                │
│                  │                                                │
│  Repository:     │  [Overview][Commits][Churn][Authors]           │
│  [Browse...  ]   │  [Files][Branches][Quality][Health Report]     │
│  /repos/my-app   │  ──────────────────────────────────────────    │
│                  │                                                │
│  Analysis Range: │  OVERVIEW TAB:                                 │
│  ○ Last 30 days  │  ┌─────────┐ ┌─────────┐ ┌─────────────────┐ │
│  ● Last 90 days  │  │ 1,247   │ │  12     │ │  89.2%          │ │
│  ○ Last 1 year   │  │ Commits │ │ Authors │ │ Files touched   │ │
│  ○ All time      │  └─────────┘ └─────────┘ └─────────────────┘ │
│                  │                                                │
│  ─────────────── │  COMMIT HEATMAP (Plotly)                       │
│  Cached: May 26  │  Mon ▓░░▓▓░▓▓░░░▓▓▓░░░░░░▓▓░░░░░░░░░░░░░░░░  │
│  [Re-analyze]    │  Tue ░░▓░▓▓░░░░▓░░░▓░░░░░░░░░░░░░░░░░░░░░░░░  │
│  [Export PDF]    │  Wed ▓▓░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                  │  ... Jan ←──────────────────────────→ May     │
│  Open Repos:     │                                                │
│  ● my-app        │  TOP CONTRIBUTORS                              │
│  ○ [+ Add repo]  │  Alice  ██████████ 423 commits  Last: 2d ago  │
│                  │  Bob    ████░░░░░░ 198 commits  Last: 12d ago  │
│                  │  Carol  ██░░░░░░░░  87 commits  Last: 48d ago⚠│
└──────────────────┴────────────────────────────────────────────────┘

HEALTH REPORT TAB:
┌───────────────────────────────────────────────────────────────────┐
│  🤖 Claude Health Report — my-app (as of May 26, 2025)           │
│  ─────────────────────────────────────────────────────────────   │
│  EXECUTIVE SUMMARY                                                │
│  The repository shows healthy commit frequency with 1,247 commits│
│  in 90 days. However, 3 files account for 40% of all bug fixes,  │
│  suggesting concentrated technical debt. Two contributors have    │
│  been inactive for > 45 days.                                     │
│                                                                   │
│  ⚠️ RISKS (3)                                                     │
│  🔴 src/auth/token.py — churn 0.91, 2 authors (bus factor risk)  │
│  🟡 2 contributors inactive > 45 days (knowledge loss risk)      │
│  🟡 14 stale branches older than 30 days                         │
│                                                                   │
│  ✅ RECOMMENDATIONS                                               │
│  1. Add tests for src/auth/token.py (highest churn, no test file)│
│  2. Archive or delete 14 stale branches to reduce noise          │
│  ...                                                              │
│                                [Re-generate]  [Copy]  [Export]   │
└───────────────────────────────────────────────────────────────────┘
```

---

## Key Interactions

### Interaction 1: Repository Load and Analysis
```
User enters /repos/my-app and clicks "Analyze"
  → Validation: Path(repo_path / '.git').exists()
  → Check SQLite cache: SELECT * FROM repo_analyses WHERE repo_path=? AND analyzed_at > ?
  → Cache hit (< 6 hours old): load from DB, skip git parsing
  → Cache miss → GitPython analysis begins:
      repo = git.Repo(repo_path)
      commits = list(repo.iter_commits(since=cutoff_date))
      For each commit:
        - extract: hash, author, date, message, stats (files changed, insertions, deletions)
      Build DataFrame: commit_df (one row per commit)
      Build file_df: group by file path, aggregate churn metrics
  → Analysis results written to repo_analyses + file_metrics + contributor_stats + branch_info
  → Streamlit reruns with data loaded from DB
  → All charts rendered from in-memory DataFrames
```

### Interaction 2: Claude Health Report Generation
```
User clicks "Generate Health Report" (or first time loading with no cached report)
  → Aggregate stats computed from DB:
      {
        summary: {commits, authors, files, date_range},
        high_risk_files: [{path, churn, bug_commits, primary_author}],
        bus_factor: [{file, author, ownership_pct}],
        inactive_authors: [{name, days_inactive}],
        stale_branches: [{name, age_days}],
        file_age: {pct_untouched_6mo, oldest_file, oldest_date},
        quality_score: 6.4
      }
  → Claude API call with aggregated JSON (no code content):
      Prompt: "Analyze this git repository metrics and generate a health report.
               Focus on: risks, team health, codebase aging. Give 5 ranked recommendations."
  → Claude returns structured report text (600-800 words)
  → Report stored in repo_analyses.claude_report
  → Health Report tab renders markdown from stored report
```

### Interaction 3: Code Churn Drill-Down
```
User clicks a file in the "Top Churn Files" table (e.g., src/auth/token.py)
  → File detail sidebar opens (st.sidebar or st.expander)
  → Query: all commits touching this specific file
      repo.iter_commits(paths='src/auth/token.py')
  → Show:
      - Commit timeline: scatter plot of commits over time
      - Commit messages list with dates and authors
      - Bug commit ratio: % with "fix/bug/hotfix" in message
      - Authors who touched this file: ownership breakdown (bar chart)
      - Last 5 commit messages with full text
  → "Ask Claude about this file" button:
      Prompt: "This file {path} has a churn score of {score}.
               Here are its last 10 commit messages: {messages}
               What might be causing high churn and how can it be reduced?"
  → Claude response shown in expandable panel
```

---

## Implementation Steps

1. **Project scaffold**: Streamlit app structure, SQLAlchemy ORM models for 4 cache tables,
   `repo_loader.py` module with GitPython commit parsing and DataFrame construction.

2. **Git parsing engine**: `git_parser.py` — iterate commits with GitPython, extract stats
   per file, handle merge commits (skip or count), detect renames/moves via `--follow`.

3. **Metrics computation**: `metrics.py` — pandas functions for churn score, bus factor,
   contributor activity, file age, branch staleness; all return DataFrames.

4. **Streamlit UI — Overview and Heatmap**: Calendar heatmap using Plotly `px.density_heatmap`
   with week/day axes, summary metric cards with `st.metric`, author filter widget.

5. **Streamlit UI — Churn and File Age**: Plotly treemap for directory churn, sortable
   `st.dataframe` for file risk table, file age color-coded directory tree.

6. **Streamlit UI — Contributors and Branches**: Author stats table, stacked area chart
   for commit frequency, branch staleness table with sort by age.

7. **Claude integration**: `claude_reporter.py` — aggregate metrics to JSON payload, call
   Claude API, parse response, cache in DB; `commit_quality.py` — batch evaluate commit
   messages, return scored list with annotations.

8. **Export and caching**: PDF export with reportlab (all charts as images embedded),
   CSV export of any DataFrame, cache invalidation logic (re-analyze button clears DB rows).

---

## Success Criteria

### Functional
- Parse 10,000 commits from a large repo in < 30 seconds (GitPython + pandas)
- Churn score accurately identifies the top 20 highest-change files
- Bus factor correctly flags files where one author > 80% of commits
- Claude report generated in < 20 seconds with all 5 sections present
- PDF export produces valid file with all charts embedded

### UX
- Dashboard loads from cache in < 1 second on repeat views
- Heatmap calendar renders 365 days smoothly without lag
- File drill-down panel opens within 2 seconds of clicking file row
- All charts have hover tooltips with meaningful data labels

### Technical Quality
- GitPython parsing uses generator `iter_commits` (not list()) for memory efficiency
- Cache invalidation: analysis older than 6 hours prompts "Stale — Re-analyze?"
- All DB operations use SQLAlchemy sessions with proper `try/finally` close
- Claude receives only aggregated metrics, never raw code content (privacy by design)
- `ANTHROPIC_API_KEY` read from environment variable, never hardcoded
- Unit tests: churn score calculation, bus factor detection, stale branch identification,
  commit message quality scoring rubric
