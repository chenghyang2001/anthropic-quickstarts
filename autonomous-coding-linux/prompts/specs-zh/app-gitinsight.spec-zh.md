# 應用程式規格：GitInsight — Git 儲存庫分析與健康儀表板

## 專案概述

GitInsight 是一款 Streamlit 網頁應用程式，分析任何本地端 Git 儲存庫並產生全面的健康與活動儀表板。GitPython 在不修改儲存庫的前提下讀取提交歷史、檔案變更日誌及分支中繼資料。pandas 將原始提交資料彙總為貢獻者統計、程式碼流動指標及時序活動模式，並以 Plotly 視覺化呈現。Claude 將所有指標綜合為白話文儲存庫健康報告，標示風險、陳舊區域和團隊動態。結果快取至 SQLite，重複檢視時無需重新解析整個提交記錄，可立即顯示。

---

## 技術堆疊

| 層級           | 技術                                           |
|----------------|------------------------------------------------|
| 語言           | Python 3.11+                                   |
| Web 框架       | Streamlit                                      |
| Git 存取       | GitPython                                      |
| 資料分析       | pandas                                         |
| 圖表           | Plotly Express + Plotly Graph Objects          |
| 資料庫         | SQLite（透過 SQLAlchemy 2.x ORM，結果快取）    |
| AI             | Anthropic Claude API (`claude-sonnet-4-6`)     |
| PDF 匯出       | reportlab                                      |
| 依賴套件       | streamlit, gitpython, pandas, plotly,          |
|                | sqlalchemy, anthropic, reportlab               |

---

## 核心功能

### 1. 儲存庫選擇與載入
- 儲存庫路徑輸入：文字欄位或資料夾瀏覽對話框（透過 `tkinter.filedialog`）
- 驗證：確認 `.git` 目錄存在、儲存庫非裸儲存庫、有讀取權限
- 載入選項：完整歷史（所有提交）或最近 N 天（預設：90 天）
- 偵測淺層複製並警告（可用歷史有限）
- 多個儲存庫分頁：同時開啟並比較最多 3 個儲存庫
- 顯示儲存庫中繼資料：總提交數、貢獻者數、分支數、首次提交日期、最後提交日期

### 2. 提交活動熱力圖日曆
- GitHub 風格貢獻日曆：依提交數量強度為日期格子著色
- 色階：白色（0）→ 淺綠色 → 深綠色（最高活動日）
- 工具提示：懸停時顯示精確數量，及該日期的作者清單
- 篩選條件：依作者、依檔案路徑前綴（例如僅顯示 `src/` 提交）
- 年度週次和小時分布（提交發生在哪些時段？）
- 動畫：播放功能，可隨時間觀看提交活動（Plotly 動畫幀）

### 3. 程式碼流動分析
- 每個檔案的流動分數：`(新增行 + 刪除行) / 總行數`（分析期間）
- 前 20 個最高流動檔案以可排序表格顯示
- 風險指示邏輯：流動分數 > 0.8 且 commit_count > 10 → 標示為高風險
- 流動與缺陷關聯性（若提交訊息包含「fix」/「bug」/「hotfix」）
- 檔案類型分布：哪些副檔名有最高流動率
- 樹狀圖：依目錄呈現流動強度，顏色 = 風險等級

### 4. 貢獻者統計
- 每位作者的指標：提交數、新增行、刪除行、淨變化、活動天數、最後提交
- 作者活動時間軸：每位作者每週提交數的堆疊面積圖（Plotly）
- 所有權地圖：哪些檔案主要由哪位作者擁有（> 50% 的變更）
- 匯流排因子警告：單一作者 > 80% 提交的檔案（關鍵人員依賴）
- 不活躍貢獻者偵測：> 45 天未提交，在表格中標記
- 作者提交訊息品質（供功能 8 使用）

### 5. 檔案老化地圖
- 整個追蹤檔案樹的每個檔案「最後修改」日期
- 熱力圖：目錄樹，顏色 = 距上次提交的天數
  - 綠色：< 30 天，黃色：30–90 天，橘色：90–180 天，紅色：> 180 天
- 「古老檔案」清單：所有超過 6 個月未修改的檔案，含最後作者和最後提交訊息
- 篩選條件：副檔名、目錄前綴
- 廢棄程式碼候選：超過 12 個月且終身提交次數 < 5 的檔案
- 點擊檔案 → 顯示該特定檔案的完整提交歷史

### 6. Claude 儲存庫健康報告
- 彙總指標送至 Claude（不含實際程式碼內容，僅統計資料）
- 報告章節：
  - 執行摘要（3–4 句，非技術語言）
  - 風險指示器：高流動檔案、匯流排因子警告、陳舊分支
  - 團隊健康：貢獻者多樣性、活動趨勢、不活躍成員
  - 程式碼庫老化：超過 6 個月未修改的檔案百分比、最舊 vs 最新區域
  - 5 項具體可行建議，依優先順序排列
- 報告快取至 SQLite；提供重新產生按鈕
- 在完整儲存庫 PDF 報告中以 PDF 章節匯出

### 7. 分支分析
- 列出所有分支：本地 + 遠端、最後提交日期、作者、相對 main 的超前 / 落後
- 陳舊分支：> 30 天無提交，列出其存在時間和最後作者
- 分支數量趨勢：每月開啟 / 關閉多少分支
- 合併頻率：從分支建立到合併的平均天數（PR 週期時間代理指標）
- 孤立分支：0 次合併且 > 60 天的分支（可能已放棄）
- 分支命名慣例分析：遵循 `feature/`、`fix/`、`hotfix/` 前綴的百分比

### 8. 提交訊息品質評分
- Claude 評估最近 50 個提交訊息的樣本（非程式碼）
- 評分標準：
  - 清晰度：是否說明了變更了什麼？（0–3 分）
  - 意圖：是否說明了為什麼？（0–3 分）
  - 慣例：是否遵循 Conventional Commits / 團隊標準？（0–2 分）
  - 長度：主旨行 20–72 字元？（0–2 分）
- 每則訊息評分（0–10），儲存庫平均分數
- 顯示範例：Claude 標注的最佳 3 則和最差 3 則訊息
- 團隊分布：每位作者的平均分數

---

## 資料庫 Schema（快取層）

```sql
CREATE TABLE repo_analyses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    repo_path       TEXT NOT NULL,               -- 儲存庫路徑
    repo_name       TEXT NOT NULL,               -- 儲存庫名稱
    analyzed_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    days_analyzed   INTEGER DEFAULT 90,          -- 分析天數範圍
    total_commits   INTEGER,                     -- 總提交數
    total_files     INTEGER,                     -- 總檔案數
    total_authors   INTEGER,                     -- 總作者數
    first_commit    DATE,                        -- 首次提交日期
    last_commit     DATE,                        -- 最後提交日期
    claude_report   TEXT,                        -- AI 健康報告
    commit_quality_score REAL                    -- 提交訊息品質平均分數
);

CREATE TABLE file_metrics (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id     INTEGER NOT NULL REFERENCES repo_analyses(id) ON DELETE CASCADE,
    file_path       TEXT NOT NULL,               -- 檔案路徑
    churn_score     REAL,                        -- 流動分數
    commit_count    INTEGER,                     -- 提交次數
    last_touched    DATE,                        -- 最後修改日期
    primary_author  TEXT,                        -- 主要作者
    lines_added     INTEGER,                     -- 新增行數
    lines_deleted   INTEGER,                     -- 刪除行數
    risk_level      TEXT DEFAULT 'LOW'           -- LOW | MEDIUM | HIGH
);

CREATE TABLE contributor_stats (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id     INTEGER NOT NULL REFERENCES repo_analyses(id) ON DELETE CASCADE,
    author_name     TEXT NOT NULL,               -- 作者姓名
    author_email    TEXT,                        -- 作者電子郵件
    commit_count    INTEGER,                     -- 提交次數
    lines_added     INTEGER,                     -- 新增行數
    lines_deleted   INTEGER,                     -- 刪除行數
    active_days     INTEGER,                     -- 活動天數
    first_commit    DATE,                        -- 首次提交日期
    last_commit     DATE,                        -- 最後提交日期
    is_active       BOOLEAN DEFAULT 1            -- 是否仍活躍
);

CREATE TABLE branch_info (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_id     INTEGER NOT NULL REFERENCES repo_analyses(id) ON DELETE CASCADE,
    branch_name     TEXT NOT NULL,               -- 分支名稱
    last_commit_date DATE,                       -- 最後提交日期
    last_author     TEXT,                        -- 最後提交作者
    is_merged       BOOLEAN DEFAULT 0,           -- 是否已合併
    days_inactive   INTEGER,                     -- 不活躍天數
    is_stale        BOOLEAN DEFAULT 0,           -- 是否已陳舊
    commit_count    INTEGER                      -- 提交次數
);
```

---

## 架構 / UI 版面

```
┌───────────────────────────────────────────────────────────────────┐
│  GitInsight                                                       │
├──────────────────┬────────────────────────────────────────────────┤
│  側邊欄          │  主要儀表板                                    │
│                  │                                                │
│  儲存庫：        │  [概覽][提交][流動][作者]                      │
│  [瀏覽...  ]     │  [檔案][分支][品質][健康報告]                  │
│  /repos/my-app   │  ──────────────────────────────────────────    │
│                  │                                                │
│  分析範圍：      │  概覽分頁：                                    │
│  ○ 最近 30 天   │  ┌─────────┐ ┌─────────┐ ┌─────────────────┐ │
│  ● 最近 90 天   │  │ 1,247   │ │  12     │ │  89.2%          │ │
│  ○ 最近 1 年    │  │ 提交數  │ │ 作者數  │ │ 已修改檔案      │ │
│  ○ 全部時間     │  └─────────┘ └─────────┘ └─────────────────┘ │
│                  │                                                │
│  ─────────────── │  提交熱力圖（Plotly）                          │
│  快取：5 月 26 日│  Mon ▓░░▓▓░▓▓░░░▓▓▓░░░░░░▓▓░░░░░░░░░░░░░░░░  │
│  [重新分析]      │  Tue ░░▓░▓▓░░░░▓░░░▓░░░░░░░░░░░░░░░░░░░░░░░░  │
│  [匯出 PDF]      │  Wed ▓▓░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│                  │  ... 1 月 ←─────────────────────────→ 5 月   │
│  已開啟儲存庫：  │                                                │
│  ● my-app        │  主要貢獻者                                    │
│  ○ [+ 新增]      │  Alice ██████████ 423 提交  最後：2 天前      │
│                  │  Bob   ████░░░░░░ 198 提交  最後：12 天前     │
│                  │  Carol ██░░░░░░░░  87 提交  最後：48 天前 ⚠  │
└──────────────────┴────────────────────────────────────────────────┘

健康報告分頁：
┌───────────────────────────────────────────────────────────────────┐
│  🤖 Claude 健康報告 — my-app（截至 2025 年 5 月 26 日）          │
│  ─────────────────────────────────────────────────────────────   │
│  執行摘要                                                         │
│  儲存庫在 90 天內有 1,247 次提交，提交頻率健康。然而，3 個       │
│  檔案佔所有缺陷修復的 40%，顯示集中的技術債。兩名貢獻者          │
│  已超過 45 天未活躍。                                             │
│                                                                   │
│  ⚠️ 風險（3 項）                                                  │
│  🔴 src/auth/token.py — 流動 0.91，2 位作者（匯流排因子風險）    │
│  🟡 2 名貢獻者不活躍超過 45 天（知識流失風險）                   │
│  🟡 14 個陳舊分支超過 30 天                                       │
│                                                                   │
│  ✅ 建議                                                          │
│  1. 為 src/auth/token.py 新增測試（最高流動，無測試檔案）         │
│  2. 封存或刪除 14 個陳舊分支以減少雜訊                           │
│  ...                                                              │
│                                         [重新產生] [複製] [匯出]  │
└───────────────────────────────────────────────────────────────────┘
```

---

## 關鍵互動

### 互動 1：儲存庫載入與分析
```
使用者輸入 /repos/my-app 並點擊「分析」
  → 驗證：Path(repo_path / '.git').exists()
  → 檢查 SQLite 快取：SELECT * FROM repo_analyses WHERE repo_path=? AND analyzed_at > ?
  → 快取命中（< 6 小時舊）：從資料庫載入，跳過 git 解析
  → 快取未命中 → 開始 GitPython 分析：
      repo = git.Repo(repo_path)
      commits = list(repo.iter_commits(since=cutoff_date))
      對每個提交：
        - 萃取：hash、作者、日期、訊息、統計（已變更檔案、新增、刪除）
      建構 DataFrame：commit_df（每列一個提交）
      建構 file_df：依檔案路徑分組，彙總流動指標
  → 分析結果寫入 repo_analyses + file_metrics + contributor_stats + branch_info
  → Streamlit 以從資料庫載入的資料重新執行
  → 所有圖表從記憶體 DataFrames 渲染
```

### 互動 2：Claude 健康報告生成
```
使用者點擊「產生健康報告」（或首次載入且無快取報告時）
  → 從資料庫計算彙總統計：
      {
        summary: {commits, authors, files, date_range},
        high_risk_files: [{path, churn, bug_commits, primary_author}],
        bus_factor: [{file, author, ownership_pct}],
        inactive_authors: [{name, days_inactive}],
        stale_branches: [{name, age_days}],
        file_age: {pct_untouched_6mo, oldest_file, oldest_date},
        quality_score: 6.4
      }
  → 以彙總 JSON（不含程式碼內容）呼叫 Claude API：
      提示詞：「分析這個 git 儲存庫指標並產生健康報告。
               聚焦於：風險、團隊健康、程式碼庫老化。給出 5 項按優先順序排列的建議。」
  → Claude 回傳結構化報告文字（600–800 字）
  → 報告儲存至 repo_analyses.claude_report
  → 健康報告分頁從儲存的報告渲染 markdown
```

### 互動 3：程式碼流動深入分析
```
使用者點擊「最高流動檔案」表格中的某個檔案（例如 src/auth/token.py）
  → 開啟檔案詳細側邊欄（st.sidebar 或 st.expander）
  → 查詢：所有修改此特定檔案的提交
      repo.iter_commits(paths='src/auth/token.py')
  → 顯示：
      - 提交時間軸：隨時間的提交散點圖
      - 含日期和作者的提交訊息清單
      - 缺陷提交比率：訊息含「fix/bug/hotfix」的百分比
      - 修改此檔案的作者：所有權分布（長條圖）
      - 最後 5 則提交訊息含完整文字
  → 「詢問 Claude 關於此檔案」按鈕：
      提示詞：「此檔案 {path} 的流動分數為 {score}。
               以下是最後 10 則提交訊息：{messages}
               高流動的可能原因是什麼，如何降低？」
  → Claude 回應顯示在可展開的面板中
```

---

## 實作步驟

1. **專案鷹架**：Streamlit 應用程式結構，4 個快取資料表的 SQLAlchemy ORM 模型，`repo_loader.py` 模組含 GitPython 提交解析和 DataFrame 建構。

2. **Git 解析引擎**：`git_parser.py` — 以 GitPython 迭代提交，萃取每個檔案的統計資料，處理合併提交（跳過或計數），透過 `--follow` 偵測重新命名 / 移動。

3. **指標計算**：`metrics.py` — pandas 函式計算流動分數、匯流排因子、貢獻者活動、檔案老化、分支陳舊度；全部回傳 DataFrames。

4. **Streamlit UI — 概覽與熱力圖**：以 Plotly `px.density_heatmap` 建立含週 / 日軸的日曆熱力圖，以 `st.metric` 建立摘要指標卡，作者篩選元件。

5. **Streamlit UI — 流動與檔案老化**：目錄流動的 Plotly 樹狀圖，檔案風險表格的可排序 `st.dataframe`，顏色標示的目錄樹顯示檔案老化。

6. **Streamlit UI — 貢獻者與分支**：作者統計表格，提交頻率堆疊面積圖，依存在時間排序的分支陳舊度表格。

7. **Claude 整合**：`claude_reporter.py` — 將指標彙總為 JSON 酬載，呼叫 Claude API，解析回應，快取至資料庫；`commit_quality.py` — 批次評估提交訊息，回傳含標注的評分清單。

8. **匯出與快取**：以 reportlab 匯出 PDF（所有圖表以圖片嵌入），匯出任何 DataFrame 為 CSV，快取失效邏輯（重新分析按鈕清除資料庫列）。

---

## 成功標準

### 功能性
- 從大型儲存庫解析 10,000 個提交 < 30 秒（GitPython + pandas）
- 流動分數準確識別前 20 個最高變更檔案
- 匯流排因子正確標示單一作者 > 80% 提交的檔案
- Claude 報告在 20 秒內產生，含所有 5 個章節
- PDF 匯出產生含所有圖表嵌入的有效檔案

### 使用者體驗
- 重複檢視時儀表板從快取 < 1 秒載入
- 熱力圖日曆流暢渲染 365 天，無延遲
- 點擊檔案列後 2 秒內開啟檔案深入分析面板
- 所有圖表含懸停工具提示，有意義的資料標籤

### 技術品質
- GitPython 解析使用生成器 `iter_commits`（非 list()），節省記憶體
- 快取失效：分析超過 6 小時提示「已過期 — 重新分析？」
- 所有資料庫操作使用 SQLAlchemy session 搭配適當的 `try/finally` 關閉
- Claude 僅接收彙總指標，絕不接收原始程式碼內容（隱私設計原則）
- `ANTHROPIC_API_KEY` 從環境變數讀取，絕不硬編碼
- 單元測試：流動分數計算、匯流排因子偵測、陳舊分支識別、提交訊息品質評分標準
