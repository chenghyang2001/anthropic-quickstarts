# 應用程式規格：APIWatcher — REST API 端點監控工具

## 專案概述

APIWatcher 是一款輕量的網頁版監控工具，持續檢查 REST API 端點的可用性、正確性與效能。背景排程器執行可設定的健康檢查並將結果記錄至 SQLite，Streamlit 儀表板則即時呈現可用率、回應時間趨勢及事件歷史。當 Claude 偵測到檢查歷史中的異常模式時，會產生白話文事件報告並建議可能的根本原因。團隊可透過單一儀表板同時監控開發、測試及正式環境。

---

## 技術堆疊

| 層級           | 技術                                            |
|----------------|-------------------------------------------------|
| 語言           | Python 3.11+                                    |
| Web 框架       | FastAPI（背景服務 + REST 設定 API）             |
| 儀表板         | Streamlit                                       |
| 排程器         | APScheduler 3.x（AsyncIOScheduler）             |
| HTTP 客戶端    | httpx（非同步）                                 |
| 資料庫         | SQLite（透過 SQLAlchemy 2.x）                   |
| AI             | Anthropic Claude API (`claude-sonnet-4-6`)      |
| 圖表           | Plotly Express                                  |
| 通知           | smtplib（電子郵件）、httpx（Slack webhook）     |
| 依賴套件       | fastapi, streamlit, apscheduler, httpx,         |
|                | sqlalchemy, plotly, anthropic, uvicorn          |

---

## 核心功能

### 1. 端點設定
- 透過 Streamlit 表單或 REST API（POST /endpoints）新增 / 編輯 / 刪除端點
- 欄位：名稱、URL、HTTP 方法（GET/POST/PUT）、標頭（JSON）、請求本體（JSON）
- 環境群組分配：dev / staging / production
- 可個別啟用 / 停用端點而不需刪除
- 以 YAML 檔案匯入 / 匯出端點設定

### 2. 健康檢查引擎
- APScheduler 依設定間隔（60 秒至 86400 秒）對每個端點觸發檢查
- 每次檢查的驗證項目：
  - 狀態碼符合預期值（預設：200）
  - 回應時間低於閾值（預設：2000ms）
  - 回應本體包含必要關鍵字（可選）
  - 回應 JSON 符合 schema（可選 jsonschema 驗證）
- 檢查結果儲存：狀態、response_time_ms、status_code、error_message
- 非同步執行：所有到期檢查以 httpx AsyncClient 並發執行

### 3. SLA 可用率追蹤
- 可用率百分比以滾動時間窗口計算：過去 24 小時 / 7 天 / 30 天
- 公式：`(通過檢查次數 / 總檢查次數) * 100`（每端點每時間窗口）
- SLA 目標可依端點設定（預設：99.9%）
- 儀表板格狀圖顯示 SLA 違反指示器
- 可依端點匯出歷史 SLA CSV

### 4. 事件偵測與生命週期
- 事件觸發條件：同一端點連續 3 次檢查失敗
- 事件欄位：start_time、end_time、duration_minutes、failure_count、resolved_at
- 事件自動關閉條件：事件開始後連續 2 次檢查通過
- 事件嚴重度：LOW（回應緩慢）、MEDIUM（部分失敗）、HIGH（完全停擺）
- 事件時間軸檢視：顯示事件時間窗口內的檢查結果

### 5. Claude AI 事件報告
- 事件開啟時：以最近 20 次檢查結果為上下文呼叫 Claude
- Claude 報告範本：
  - 什麼出了問題、持續多久
  - 最後一次成功檢查的時間戳記
  - 錯誤模式分析（逾時 vs 503 vs 400 等）
  - 2–3 個可能根本原因（含可能性百分比）
  - 建議的立即修復步驟
- 報告儲存於 incidents 資料表，可在 Streamlit 事件詳細頁面檢視
- 手動「重新分析」按鈕，以最新資料更新 Claude 報告

### 6. 警報通知管道
- 電子郵件警報：SMTP 含可設定的寄件人 / 收件人、TLS 支援、每端點開關
- Slack webhook：發送含事件摘要的 JSON 酬載至 webhook URL
- 桌面通知：`plyer.notification`，供本地開發使用
- 觸發時機：事件開啟、事件解決、SLA 違反
- 警報冷卻：同一端點重複警報之間最少間隔 15 分鐘
- 警報日誌：所有已傳送警報儲存含時間戳記、管道、訊息預覽

### 7. 回應時間趨勢圖
- Plotly 折線圖：每端點過去 24 小時的 response_time_ms
- 疊加：設定最大回應時間的閾值線（紅色虛線）
- 縮放、平移、懸停工具提示（顯示精確 ms 值）
- 多端點疊加模式：在同一圖表上比較多個端點
- 透過 Streamlit `st.rerun()` 每 60 秒自動更新

### 8. 多環境儀表板
- 環境選擇器：全部 / Dev / Staging / Production 分頁
- 狀態格狀圖：每端點一張卡片，綠 / 黃 / 紅色標示
- 摘要列：每環境的端點總數、通過、失敗、事件中數量
- 篩選條件：狀態（up/down/degraded）、SLA 合規、最後事件時間
- 「批次立即檢查」按鈕：觸發群組中所有端點的即時檢查

---

## 資料庫 Schema

```sql
CREATE TABLE endpoints (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,             -- 端點名稱
    url             TEXT NOT NULL,             -- 端點 URL
    method          TEXT NOT NULL DEFAULT 'GET',
    headers         TEXT DEFAULT '{}',         -- JSON 字串
    body            TEXT DEFAULT '{}',         -- JSON 字串
    environment     TEXT DEFAULT 'production', -- dev | staging | production
    check_interval  INTEGER DEFAULT 300,       -- 秒數
    timeout_ms      INTEGER DEFAULT 5000,      -- 逾時毫秒
    expected_status INTEGER DEFAULT 200,       -- 預期狀態碼
    keyword_check   TEXT,                      -- 回應本體中的可選關鍵字
    sla_target      REAL DEFAULT 99.9,         -- SLA 目標百分比
    enabled         BOOLEAN DEFAULT 1,         -- 是否啟用
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE checks (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id     INTEGER NOT NULL REFERENCES endpoints(id) ON DELETE CASCADE,
    checked_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    passed          BOOLEAN NOT NULL,          -- 是否通過
    status_code     INTEGER,                   -- 實際狀態碼
    response_time   INTEGER,                   -- 毫秒
    error_message   TEXT,                      -- 錯誤訊息
    response_body   TEXT                       -- 截斷至 500 字元
);

CREATE TABLE incidents (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id     INTEGER NOT NULL REFERENCES endpoints(id) ON DELETE CASCADE,
    started_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    resolved_at     DATETIME,                  -- 解決時間
    duration_mins   INTEGER,                   -- 持續分鐘數
    failure_count   INTEGER DEFAULT 1,         -- 失敗次數
    severity        TEXT DEFAULT 'MEDIUM',     -- LOW | MEDIUM | HIGH
    claude_report   TEXT,                      -- AI 事件報告
    acknowledged    BOOLEAN DEFAULT 0          -- 是否已確認
);

CREATE TABLE alert_configs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    endpoint_id     INTEGER REFERENCES endpoints(id) ON DELETE CASCADE,
    channel         TEXT NOT NULL,             -- email | slack | desktop
    target          TEXT NOT NULL,             -- 電子郵件地址或 webhook URL
    on_incident     BOOLEAN DEFAULT 1,         -- 事件開啟時通知
    on_resolve      BOOLEAN DEFAULT 1,         -- 事件解決時通知
    on_sla_breach   BOOLEAN DEFAULT 1,         -- SLA 違反時通知
    cooldown_mins   INTEGER DEFAULT 15,        -- 冷卻分鐘數
    last_sent_at    DATETIME                   -- 最後傳送時間
);
```

---

## 架構 / UI 版面

```
┌─────────────────────────────────────────────────────────────────┐
│  程序架構                                                        │
│                                                                 │
│  ┌─────────────────┐      SQLite DB      ┌──────────────────┐  │
│  │  FastAPI 伺服器 │ ←──────────────────→│  Streamlit UI    │  │
│  │  :8000          │                     │  :8501           │  │
│  │                 │                     │                  │  │
│  │  APScheduler    │                     │  儀表板          │  │
│  │  （背景）       │                     │  （讀取 DB）     │  │
│  │       ↓         │                     └──────────────────┘  │
│  │  httpx 檢查     │──→ Claude API                             │
│  │       ↓         │    （事件發生時）                         │
│  │  警報傳送器     │──→ 電子郵件 / Slack / 桌面               │
│  └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘

Streamlit 儀表板版面：
┌──────────────────────────────────────────────────────────────┐
│  APIWatcher      [全部][Dev][Staging][Production]             │
├──────────────────────────────────────────────────────────────┤
│  摘要：12 個端點  ✅ 9 正常  ⚠️ 2 降級  🔴 1 停擺           │
├──────────────────────────────────────────────────────────────┤
│  狀態格狀圖                                                   │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐          │
│  │ ✅ 驗證 API  │ │ ⚠️ 訂單      │ │ 🔴 付款      │          │
│  │ 99.97% 24h  │ │ 98.12% 24h  │ │ 91.3% 24h   │          │
│  │ 142ms 平均  │ │ 847ms 平均  │ │ 事件 12 分鐘 │          │
│  └──────────────┘ └──────────────┘ └──────────────┘          │
├───────────────────────────────────┬──────────────────────────┤
│  回應時間圖表（Plotly）           │  事件日誌                │
│                                   │                          │
│  ms                               │  🔴 付款 API            │
│  2000 ─ ─ ─ ─ ─ ─ ─[閾值]       │  開始：14:32             │
│  1000 │   ╭─╮   ╭╮               │  持續：12 分鐘           │
│   500 │───╯ ╰───╯ ╰──────        │  [查看 Claude 報告]     │
│       └────────────────── 時間   │                          │
│                                   │  ✅ 驗證 API 已解決     │
│                                   │  昨日 09:15，3 分鐘      │
└───────────────────────────────────┴──────────────────────────┘
```

---

## 關鍵互動

### 互動 1：排程檢查執行
```
APScheduler 為 endpoint_id=5 觸發任務（間隔：60 秒）
  → httpx.AsyncClient.request(method, url, headers, json, timeout)
  → 收到回應（或捕獲例外）
  → 評估檢查結果：
      pass_conditions = [
          status_code == endpoint.expected_status,
          response_time <= endpoint.timeout_ms,
          keyword in response.text（若已設定），
      ]
      passed = all(pass_conditions)
  → 插入 checks 列
  → 事件邏輯：
      last_3 = SELECT passed FROM checks WHERE endpoint_id=5 ORDER BY id DESC LIMIT 3
      若全部失敗 → 開啟新事件（若無進行中事件）
      若最後 2 次通過 → 關閉進行中事件，設定 resolved_at，計算持續時間
  → 若事件開啟 → alert_sender.send_all(endpoint, incident)
  → 若事件開啟 → claude_reporter.generate(endpoint, incident)（非同步，不阻塞）
```

### 互動 2：Claude 事件報告生成
```
「付款閘道」端點開啟事件
  → 從資料庫取得該端點最近 20 次檢查
  → 建構 Claude 提示詞：
      「分析這些 API 檢查結果並產生事件報告。
       端點：{name}（{url}）
       最近檢查（最新優先）：{json_checks}
       包含：失敗持續時間、錯誤模式、根本原因、修復步驟。」
  → Claude API 呼叫（逾時 30 秒，重試 2 次）
  → 解析回應，儲存至 incidents.claude_report
  → Streamlit 下次更新時從資料庫抓取報告
  → 事件卡片顯示「AI 報告已就緒」標記
```

### 互動 3：Streamlit 儀表板即時更新
```
Streamlit 應用程式啟動
  → 從 SQLite 讀取所有端點 + 每個端點的最新檢查
  → 渲染狀態格狀圖（顏色依最後檢查結果）
  → 渲染 Plotly 圖表（過去 24 小時回應時間）
  → 渲染事件日誌（進行中 + 最後 5 筆已解決）
  → 每 60 秒執行 st.rerun()
  → 使用者點擊端點卡片 → 開啟詳細側邊欄：
      - SLA 指標（24 小時 / 7 天 / 30 天可用率百分比）
      - 回應時間直方圖
      - 檢查歷史表格（分頁，每頁 50 筆）
      - Claude 事件報告（若存在）
      - 警報設定表單
```

---

## 實作步驟

1. **專案結構**：建立 `watcher/` 套件，包含模組：`models.py`、`scheduler.py`、`checker.py`、`incident.py`、`alerter.py`、`claude_reporter.py`、`api.py`、`dashboard.py`。

2. **資料庫層**：為 4 張資料表定義 SQLAlchemy ORM 模型，建立含 `check_same_thread=False` 的引擎（供多執行緒存取），撰寫 `db.py` session 工廠。

3. **HTTP 檢查器**：`checker.py` — 非同步函式 `run_check(endpoint) -> CheckResult`，處理：連線錯誤、逾時、JSON 解碼錯誤、狀態碼不符、關鍵字不符。

4. **排程器設定**：`scheduler.py` — AsyncIOScheduler，啟動時載入所有已啟用端點，將每個端點排程為 IntervalTrigger 任務，公開 `add_job/remove_job/update_job` 函式。

5. **事件與警報邏輯**：`incident.py` — 每次檢查後執行 `evaluate_incident(endpoint_id)`；`alerter.py` — `send_email`、`send_slack`、`send_desktop`，含冷卻時間強制執行。

6. **Claude 報告器**：`claude_reporter.py` — 非同步函式 `generate_report(endpoint, incident)`，從檢查歷史建構提示詞，呼叫 Claude API，將報告文字儲存至資料庫。

7. **FastAPI 服務**：`api.py` — 端點設定的 CRUD 端點、手動觸發檢查、事件確認。在 lifespan 事件中啟動 APScheduler。執行於 port 8000。

8. **Streamlit 儀表板**：`dashboard.py` — 以 `st.columns` 建立狀態格狀圖，以 `st.plotly_chart` 建立 Plotly 圖表，以 `st.expander` 建立事件日誌，透過 `st.rerun` 自動更新。

---

## 成功標準

### 功能性
- 50 個端點並發檢查，無遺漏間隔（非同步 httpx）
- 3 次失敗檢查內開啟事件（最多 3 個檢查間隔延遲）
- 事件開啟後 10 秒內產生 Claude 報告
- 偵測到事件後 5 秒內傳送電子郵件和 Slack 警報
- SLA 計算與人工計數誤差在 0.1% 以內

### 使用者體驗
- 儀表板狀態格狀圖無需全頁重載即可更新（60 秒間隔）
- 端點詳細面板 500ms 內開啟（SQLite 讀取）
- Claude 事件報告可作為獨立文件閱讀（無技術術語）
- 檢查歷史表格分頁顯示 10,000 筆以上列，無延遲

### 技術品質
- 所有資料庫寫入使用 SQLAlchemy session 搭配 `try/finally` 關閉
- httpx 檢查有明確逾時，無懸掛連線
- APScheduler 任務在 FastAPI 重啟後仍存活（啟動時從資料庫重新載入任務）
- Claude API Key 僅從 `ANTHROPIC_API_KEY` 環境變數載入
- 單元測試涵蓋：SM-2 邏輯、事件偵測、SLA 計算
