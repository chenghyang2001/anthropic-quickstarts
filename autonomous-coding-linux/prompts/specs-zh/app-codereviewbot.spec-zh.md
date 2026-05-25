# 應用程式規格書：CodeReviewBot

## 專案概述

CodeReviewBot 是一款以 AI 驅動的程式碼審查工具，結合 CLI 介面與可選的網頁儀表板。開發者可在本機執行 `codereview scan ./src`，或指向 GitHub PR，由 Claude 回傳帶有檔案行號脈絡的結構化審查結果（critical / warning / suggestion）。所有審查結果均持久化至 SQLite，讓團隊能追蹤程式碼品質趨勢。

**主要受眾：** 個人開發者及小型工程團隊，希望在合併前自動進行程式碼審查，且不需將程式碼上傳至第三方 SaaS 服務。

---

## 技術堆疊

| 層級         | 技術                                      |
|--------------|-------------------------------------------|
| CLI          | Python 3.11 + Click 8                    |
| API 伺服器   | FastAPI 0.111                             |
| 儀表板       | Streamlit 1.35                            |
| AI           | Anthropic Claude (claude-sonnet-4-6)     |
| GitHub       | PyGithub 2.3                              |
| 資料庫       | SQLite（透過 SQLAlchemy 2.0）             |
| 設定         | PyYAML + python-dotenv                    |
| 匯出         | Markdown（內建）+ Jinja2 範本             |

---

## 核心功能

### 1. 本機檔案掃描
- 遞迴掃描目錄中的 Python、TypeScript 及 Go 原始碼檔案
- 遵守 `.codereviewbotignore` 規則（語法同 `.gitignore`）
- 將大型檔案切分為重疊區段後再送給 Claude 處理
- 檔案處理過程中以 tqdm 顯示即時進度條

### 2. GitHub PR 整合
- 透過 `GITHUB_TOKEN` 環境變數進行身份驗證
- 使用 PyGithub 抓取 PR diff，重建每個檔案的 diff 內容
- 將審查結果以行內評論方式張貼至 PR（GitHub Review API）
- 支援 `--dry-run` 旗標，可預覽結果而不實際張貼

### 3. 嚴重性分類
- Claude 回傳結構化 JSON：`{ "findings": [{ "severity", "line", "message", "suggestion" }] }`
- 三個等級：`critical`（阻擋合併）、`warning`（應修正）、`suggestion`（選擇性）
- 若有任何 `critical` 結果，CLI 退出碼為 1（適用於 CI 閘道）
- 終端機以顏色區分輸出（Rich 函式庫）

### 4. 審查歷史與儲存
- 每次掃描結果均附帶時間戳記與 repo 脈絡儲存至 SQLite
- 查詢歷史：`codereview history --repo myrepo --last 30d`
- 比較兩次審查結果以觀察品質改善程度
- 清理指令：`codereview history prune --older-than 90d`

### 5. Streamlit 儀表板
- 摘要卡片：本週各嚴重性等級的總結果數量
- 折線圖：歷時結果趨勢（critical 趨勢）
- 表格：本週結果最多的前 10 個檔案
- 團隊統計：每位作者的結果數量（來自 git blame 資料）
- 依 repo、日期範圍、嚴重性、作者篩選

### 6. 可設定規則
- 專案根目錄的 `.codereviewbot.yaml` 定義審查重點
- 啟用/停用規則類別：security、performance、style、logic
- 自訂 prompt 追加：「同時檢查是否使用了已棄用的 `requests` 模式」
- 各語言個別設定（例如 Go 特定慣用語、Python 型別提示強制執行）

### 7. 匯出與報告
- `codereview report --format markdown > review.md` — 完整 Markdown 報告
- `codereview report --format github-comment` — 向 PR 張貼摘要評論
- 報告內容：檔案清單、各嚴重性等級的結果數量、主要問題、修正建議
- 透過 cron 排程報告：每週摘要 email（使用 smtplib）

---

## 資料庫 Schema

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
    created_by  TEXT                    -- git 使用者或系統
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
    suppressed  BOOLEAN DEFAULT 0       -- 使用者標記為誤報
);

CREATE TABLE repo_configs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_name   TEXT UNIQUE NOT NULL,
    config_yaml TEXT,                   -- 序列化的 YAML 內容
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

## 架構 / UI 版面

```
┌──────────────────────────────────────────────────────────┐
│  CLI (Click)                                              │
│  codereview scan / pr / history / report / config        │
└───────────────────┬──────────────────────────────────────┘
                    │ 讀取/寫入
          ┌─────────▼──────────┐        ┌─────────────────┐
          │  SQLite 資料庫     │        │  Claude API      │
          │  (SQLAlchemy ORM)  │        │  (findings JSON) │
          └─────────┬──────────┘        └────────┬────────┘
                    │                             │
          ┌─────────▼──────────┐        ┌────────▼────────┐
          │  FastAPI 伺服器    │        │  ReviewEngine   │
          │  /api/reviews      │◄───────│  (切塊 +        │
          │  /api/findings     │        │   提示處理)     │
          │  /api/stats        │        └─────────────────┘
          └─────────┬──────────┘
                    │ HTTP
          ┌─────────▼──────────┐
          │  Streamlit UI      │
          │  儀表板 /          │
          │  趨勢 / 報告       │
          └────────────────────┘
```

---

## 主要互動流程

### 流程 1：透過 CLI 進行本機掃描
1. 開發者執行 `codereview scan ./src --config .codereviewbot.yaml`
2. CLI 發現所有 `.py`、`.ts`、`.go` 檔案，並遵守忽略規則
3. `ReviewEngine` 將每個檔案切分為每塊 ≤ 200 行、重疊 20 行的區段
4. 對每個區段，呼叫 Claude，傳入系統提示 + 程式碼 + 重點規則
5. JSON 結果經過驗證、去重複後持久化至 SQLite
6. 終端機顯示帶顏色的表格；若有 critical 結果則退出碼為 1

### 流程 2：GitHub PR 審查
1. 開發者執行 `codereview pr --repo owner/repo --pr 42`
2. PyGithub 抓取 PR diff；重建每個檔案的 diff
3. 同一個 `ReviewEngine` 處理每個變更的檔案
4. 透過 GitHub Review API 將結果以行內審查評論張貼
5. 向 PR 新增摘要評論，包含各嚴重性等級的結果數量

### 流程 3：Streamlit 儀表板導覽
1. 使用者開啟 `http://localhost:8501`（Streamlit 應用程式）
2. 側邊欄：選擇 repo 及日期範圍
3. 儀表板頁籤：摘要卡片 + critical 趨勢圖
4. 檔案頁籤：問題最多的檔案表格，點擊可查看結果詳情
5. 團隊頁籤：每位作者的明細，用於衝刺回顧

---

## 實作步驟

1. **專案骨架** — `pyproject.toml`、`src/codereviewbot/`、`tests/`、`Makefile`
2. **資料庫層** — 4 張表的 SQLAlchemy 模型，Alembic 遷移
3. **ReviewEngine** — 檔案切塊、Claude 提示範本、JSON 回應解析器
4. **CLI 指令** — 使用 Click 實作 `scan`、`pr`、`history`、`report`、`config`
5. **GitHub 整合** — PyGithub 封裝、diff 解析器、評論張貼器
6. **FastAPI 伺服器** — reviews 及 findings 的 REST 端點（供 Streamlit 使用）
7. **Streamlit 儀表板** — 3 頁籤版面、Plotly 圖表、篩選元件
8. **匯出與報告** — Jinja2 Markdown 範本、GitHub 評論格式化器

---

## 成功標準

### 功能性
- `codereview scan` 在 60 秒內完成對 10k 行 Python repo 的掃描
- GitHub PR 審查能以正確的行號張貼行內評論
- 歷史記錄與儀表板的結果數量與 CLI 輸出一致

### 使用者體驗
- CLI 輸出在淺色及深色終端機佈景主題下均可讀（Rich 樣式）
- 儀表板在 30 天查詢範圍下 2 秒內載入完成
- `.codereviewbot.yaml` 預設產生的檔案包含行內說明注釋

### 技術品質
- 所有 Claude 回應在寫入資料庫前經 Pydantic schema 驗證
- ReviewEngine 切塊及提示邏輯的單元測試覆蓋率達 80% 以上
- SQLite 查詢使用參數化語句（不用 f-string 組合 SQL）
- README 包含 Docker Compose 設定，可用單一指令啟動完整堆疊
