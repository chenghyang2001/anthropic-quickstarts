# 應用程式規格書：PipelineGuard — 資料管道監控平台

## 專案概述

打造一個以 **Python 為基礎的資料管道監控與可觀測性平台**。
PipelineGuard 讓資料工程師定義、監控並除錯資料管道 —
並由 Claude AI 自動偵測異常、分析根本原因，並以人類語言發送告警。

目標使用者：執行排程 ETL 任務、資料品質檢查或自動化報告管道的資料工程師與分析師。

---

## 技術堆疊

### 執行環境與語言
- **Python 3.12+**（主要語言 — 不使用 JavaScript）
- **FastAPI** — 後端 API 伺服器
- **Streamlit** — 網頁儀表板 UI（純 Python 前端）
- **SQLite**（開發）/ **PostgreSQL**（生產）透過 SQLAlchemy

### AI 整合
- **Anthropic SDK**（`anthropic`）— Claude API
- 預設模型：`claude-sonnet-4-6`（分析需要較強的推理能力）
- 用途：異常說明、失敗根本原因分析、告警摘要
- API 金鑰：`ANTHROPIC_API_KEY` 環境變數

### 背景排程
- **APScheduler** — cron 風格的管道執行排程器
- **Celery + Redis**（選用，分散式模式）

### 支援的資料來源
- **檔案**：CSV、JSON、Parquet（透過 pandas + pyarrow）
- **資料庫**：PostgreSQL、MySQL、SQLite（透過 SQLAlchemy）
- **API**：可設定認證標頭的 REST 端點
- **雲端**：AWS S3、Google Cloud Storage（選用，可插拔）

### 相依套件
- `pandas` — 資料處理與品質檢查
- `great_expectations` — 資料驗證規則
- `plotly` — Streamlit 中的互動式圖表
- `httpx` — REST 來源輪詢的非同步 HTTP 客戶端
- `pydantic` — 設定驗證與 API 請求/回應模型
- `loguru` — 結構化日誌記錄
- `python-dotenv` — 環境設定

### 部署
- 以兩個程序運行：`uvicorn`（FastAPI）+ `streamlit run`
- `docker-compose.yml` 用於本地開發
- 可透過 `config/pipelines.yaml` 或 REST API 設定

---

## 核心功能

### 1. 管道定義
- 以 YAML 或網頁 UI 定義管道
- 管道 = 來源 → 轉換 → 目的地 + 排程
- 支援的來源：檔案路徑、DB 查詢、REST URL
- 支援的轉換：篩選列、重新命名欄位、型別轉換、合併、聚合
- 支援的目的地：檔案、DB 表格、Webhook、電子郵件
- 乾跑模式：驗證管道設定而不實際執行

### 2. 管道執行引擎
- APScheduler 依 cron 排程或手動觸發管道
- 每次執行建立一筆 `Execution` 記錄：狀態、開始/結束時間、列數、錯誤
- 列級錯誤捕獲（失敗的列寫入錯誤日誌）
- 獨立管道並行執行
- 每個管道可設定執行超時限制

### 3. 資料品質檢查
- 為每個管道步驟定義品質規則：
  - `not_null`：欄位不得有空值
  - `unique`：欄位值必須唯一
  - `range`：數值欄位必須在 [最小值, 最大值] 範圍內
  - `regex`：字串欄位必須符合正規表達式
  - `row_count`：輸出必須有 >= N 列
  - `schema`：輸出必須符合預期欄位型別
- 可設定嚴重程度：`warning`（僅記錄）vs `error`（管道失敗）
- 每次執行的品質分數（通過規則的百分比）

### 4. AI 自動異常偵測
- 每次執行後，Claude 分析：
  - 列數與歷史平均比較（突然下降/上升）
  - 空值率變化
  - 執行時間與基準比較
  - 錯誤訊息
- Claude 生成人類語言說明和建議修復方案
- 異常嚴重程度：`info` / `warning` / `critical`
- 所有 AI 分析儲存於 `ai_analyses` 表（頁面重載不重複執行）

### 5. 告警系統
- 為每個管道設定告警：電子郵件、Slack Webhook 或 Webhook URL
- 告警觸發：管道失敗、品質檢查錯誤、偵測到異常
- Claude 生成告警訊息（簡潔、可操作、< 280 字）
- 告警去重：冷卻視窗內相同問題不重複告警
- 含確認追蹤的告警歷史日誌

### 6. 儀表板（Streamlit）
- **總覽頁面**：所有管道狀態格線（綠/黃/紅）
- **管道詳情頁面**：執行歷史圖表、品質分數趨勢、最新 AI 分析
- **執行日誌頁面**：可篩選的日誌表格、列級錯誤下載
- **異常消息頁面**：AI 偵測異常的時間軸消息
- **設定頁面**：管理管道、告警、API 金鑰

### 7. REST API（FastAPI）
- 管道、品質規則、告警設定的完整 CRUD
- 手動觸發管道執行：`POST /api/pipelines/{id}/run`
- 查詢執行狀態：`GET /api/executions/{id}`
- 取得執行的 AI 分析：`GET /api/executions/{id}/analysis`
- 外部觸發 Webhook 接收器：`POST /api/webhooks/trigger`

### 8. 可觀測性與日誌記錄
- 透過 loguru 輸出結構化 JSON 日誌至檔案和標準輸出
- 每次執行的日誌檔儲存於 `data/logs/{execution_id}.log`
- 指標端點：`GET /api/metrics`（Prometheus 相容格式）
- 執行時間直方圖、列數時間序列、每個管道的錯誤率

---

## 資料庫結構

### `pipelines`（管道）
```sql
id              TEXT PRIMARY KEY    -- UUID
name            TEXT NOT NULL
description     TEXT
schedule_cron   TEXT                -- 例：「0 6 * * *」
config          TEXT                -- JSON：來源/轉換/目的地設定
is_active       INTEGER DEFAULT 1
timeout_seconds INTEGER DEFAULT 300
created_at      TEXT
updated_at      TEXT
```

### `executions`（執行記錄）
```sql
id              TEXT PRIMARY KEY
pipeline_id     TEXT REFERENCES pipelines(id)
status          TEXT                -- 'running'|'success'|'failed'|'timeout'
started_at      TEXT
finished_at     TEXT
rows_input      INTEGER
rows_output     INTEGER
rows_failed     INTEGER
error_message   TEXT
log_path        TEXT
triggered_by    TEXT                -- 'schedule'|'api'|'manual'
```

### `quality_checks`（品質檢查）
```sql
id              TEXT PRIMARY KEY
pipeline_id     TEXT REFERENCES pipelines(id)
column_name     TEXT
check_type      TEXT                -- 'not_null'|'unique'|'range'|'regex'|'row_count'|'schema'
config          TEXT                -- JSON：此檢查類型的參數
severity        TEXT DEFAULT 'error'
is_active       INTEGER DEFAULT 1
```

### `quality_results`（品質結果）
```sql
id              TEXT PRIMARY KEY
execution_id    TEXT REFERENCES executions(id)
check_id        TEXT REFERENCES quality_checks(id)
passed          INTEGER
actual_value    TEXT
expected_value  TEXT
message         TEXT
```

### `ai_analyses`（AI 分析）
```sql
id              TEXT PRIMARY KEY
execution_id    TEXT REFERENCES executions(id)
anomaly_type    TEXT                -- 'row_count_drop'|'quality_degradation'|'slowdown'|'failure'
severity        TEXT
summary         TEXT
root_cause      TEXT
suggested_fix   TEXT
model           TEXT
tokens_used     INTEGER
created_at      TEXT
```

### `alert_configs`（告警設定）
```sql
id              TEXT PRIMARY KEY
pipeline_id     TEXT REFERENCES pipelines(id)
channel         TEXT                -- 'email'|'slack'|'webhook'
config          TEXT                -- JSON：電子郵件地址 / Slack URL / Webhook URL
trigger_on      TEXT                -- JSON 陣列：['failure','quality_error','anomaly']
cooldown_minutes INTEGER DEFAULT 60
is_active       INTEGER DEFAULT 1
```

### `alert_logs`（告警日誌）
```sql
id              TEXT PRIMARY KEY
alert_config_id TEXT REFERENCES alert_configs(id)
execution_id    TEXT REFERENCES executions(id)
message         TEXT
sent_at         TEXT
acknowledged    INTEGER DEFAULT 0
acknowledged_at TEXT
```

---

## API 端點

### 管道
- `GET    /api/pipelines`                  — 列出所有管道
- `POST   /api/pipelines`                  — 建立管道
- `GET    /api/pipelines/{id}`             — 取得管道詳情
- `PUT    /api/pipelines/{id}`             — 更新管道
- `DELETE /api/pipelines/{id}`             — 刪除管道
- `POST   /api/pipelines/{id}/run`         — 立即觸發執行
- `POST   /api/pipelines/{id}/validate`    — 乾跑驗證
- `GET    /api/pipelines/{id}/executions`  — 執行歷史

### 執行記錄
- `GET    /api/executions`                 — 列出執行記錄（可篩選）
- `GET    /api/executions/{id}`            — 執行詳情
- `GET    /api/executions/{id}/logs`       — 原始日誌檔案內容
- `GET    /api/executions/{id}/errors`     — 失敗列下載（CSV）
- `GET    /api/executions/{id}/analysis`   — 此次執行的 AI 分析
- `POST   /api/executions/{id}/rerun`      — 重新執行失敗的管道

### 品質檢查
- `GET    /api/pipelines/{id}/checks`      — 列出管道的品質規則
- `POST   /api/pipelines/{id}/checks`      — 新增品質規則
- `PUT    /api/checks/{id}`               — 更新規則
- `DELETE /api/checks/{id}`               — 刪除規則

### 告警
- `GET    /api/pipelines/{id}/alerts`      — 列出告警設定
- `POST   /api/pipelines/{id}/alerts`      — 新增告警設定
- `PUT    /api/alerts/{id}`               — 更新告警設定
- `GET    /api/alerts/history`            — 告警日誌（所有管道）
- `PUT    /api/alerts/{log_id}/ack`        — 確認告警

### AI 與分析
- `GET    /api/anomalies`                  — 異常消息（所有管道）
- `POST   /api/executions/{id}/analyze`    — 強制重新執行 AI 分析
- `GET    /api/pipelines/{id}/stats`       — 聚合統計（成功率、平均時長）
- `GET    /api/metrics`                    — Prometheus 格式指標

---

## UI 版面（Streamlit 頁面）

### 總覽頁面（`/`）
```
┌────────────────────────────────────────────────────────────┐
│  PipelineGuard  [總覽] [管道] [異常] [⚙]                  │
├────────────────────────────────────────────────────────────┤
│  狀態摘要：✅ 8 正常  ⚠ 2 警告  🔴 1 失敗                │
│  ─────────────────────────────────────────────────────────  │
│  管道狀態格線：                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐       │
│  │ sales_daily  │ │ user_metrics │ │ log_etl      │       │
│  │ ✅ 成功      │ │ ⚠ 警告      │ │ 🔴 失敗      │       │
│  │ 2 小時前     │ │ 34 分鐘前    │ │ 12 分鐘前    │       │
│  │ 14.2 萬列    │ │ 8,100 列     │ │ 錯誤：連線   │       │
│  └──────────────┘ └──────────────┘ └──────────────┘       │
│  ─────────────────────────────────────────────────────────  │
│  近期異常（AI）：                                           │
│  🟡 user_metrics：列數低於 7 日平均 23%                    │
│  🔴 log_etl：連線逾時 — 可能是資料庫過載                   │
└────────────────────────────────────────────────────────────┘
```

### 管道詳情頁面
- 執行歷史折線圖（依日期顯示成功/失敗/警告）
- 品質分數趨勢圖
- 最新執行詳情（列數、時長、錯誤）
- AI 分析卡片（異常說明 + 建議修復方案）
- 品質檢查結果表格

### 執行日誌頁面
- 可篩選的日誌表格（嚴重程度、時間戳、訊息）
- 下載日誌按鈕
- 失敗列下載（若有）

---

## 關鍵互動流程

### 管道執行流程
1. APScheduler 在 cron 時間觸發管道
2. 引擎讀取來源資料（檔案/DB/API）
3. 逐列套用轉換（收集錯誤，不中斷執行）
4. 對輸出 DataFrame 執行品質檢查
5. 寫入目的地
6. 更新 `executions` 記錄（最終狀態 + 列數）
7. 若偵測到異常：背景任務呼叫 Claude API
8. Claude 分析儲存至 `ai_analyses`
9. 若觸發告警：傳送含 Claude 生成訊息的通知

### 異常分析流程
1. 執行完成（成功或失敗）
2. 背景任務將此次執行統計與近 30 次比較
3. 若偏差超過閾值：準備 Claude 的上下文
4. Claude 提示詞：執行統計 + 近期歷史 + 錯誤訊息
5. Claude 回傳：anomaly_type、severity、summary、root_cause、suggested_fix
6. 結果儲存至 DB，立即顯示於儀表板

### 手動觸發流程
1. 使用者在儀表板點擊「立即執行」或呼叫 `POST /api/pipelines/{id}/run`
2. 立即回傳 `execution_id`（202 已接受）
3. 儀表板每 5 秒輪詢 `GET /api/executions/{id}`
4. 若可取得列數則顯示進度條
5. 完成後：顯示結果 + AI 分析

---

## 實作步驟

### 第 1 步：專案基礎
- 建立 FastAPI 應用程式，整合 SQLAlchemy + SQLite
- 定義所有 ORM 模型並執行 `create_all()`
- 實作 `POST /api/pipelines` 和 `GET /api/pipelines`
- Docker Compose：FastAPI + Redis（為未來 Celery 準備）
- 健康檢查端點

### 第 2 步：管道執行引擎
- 建立 `PipelineRunner` 類別（來源 → 轉換 → 目的地）
- CSV/JSON 檔案來源讀取器
- SQLite/PostgreSQL DB 查詢來源
- REST API 來源（httpx 非同步）
- 基本轉換：篩選、重新命名、型別轉換
- DB 和檔案目的地寫入器

### 第 3 步：品質檢查
- 將每種檢查類型實作為 Python 函式
- 對輸出 DataFrame 執行檢查
- 將結果儲存至 `quality_results`
- 計算每次執行的品質分數

### 第 4 步：排程器
- APScheduler 整合 cron 表達式
- 啟動時從 DB 載入啟用的管道
- 管道設定變更時動態新增/移除任務
- 手動觸發 API 端點

### 第 5 步：AI 異常偵測
- Anthropic SDK 包裝器（含錯誤處理）
- 建立歷史統計聚合查詢
- 為每種異常類型設計 Claude 提示詞
- 執行後觸發的背景任務
- 將結果儲存至 `ai_analyses`

### 第 6 步：告警
- 告警設定 CRUD API
- 電子郵件傳送器（smtplib 含 TLS）
- Slack Webhook 傳送器（httpx）
- 通用 Webhook 傳送器
- 冷卻去重邏輯
- Claude 生成告警訊息

### 第 7 步：Streamlit 儀表板
- 含狀態格線的總覽頁面
- 含 Plotly 圖表的管道詳情頁面
- 含篩選器的執行日誌頁面
- 異常消息頁面
- 設定頁面（管道 CRUD 表單）

### 第 8 步：精修
- Prometheus 指標端點
- 使用 loguru 的結構化日誌
- 基於環境的設定（pydantic-settings）
- 含環境檔案的 Docker Compose
- 含設定指南和 YAML 管道範例的 README

---

## 成功標準

### 功能性
- 管道按排程執行，無時鐘漂移（延遲 < 1 分鐘）
- 品質檢查對測試資料集正確通過/失敗
- 執行完成後 10 秒內生成 AI 分析
- 觸發條件滿足後 30 秒內傳送告警
- 儀表板即時反映執行結果（5 秒輪詢）

### 使用者體驗
- 儀表板在 2 秒內載入
- AI 異常說明無需資料工程背景即可理解
- 從儀表板完成管道 CRUD 只需 3 次點擊
- 超過 100 萬列的執行日誌下載正常

### 技術品質
- 所有 DB 操作使用參數化查詢
- API 金鑰不記錄於日誌
- 所有外部呼叫（DB、REST、Claude）含超時和重試邏輯
- 測試涵蓋：PipelineRunner、品質檢查引擎、AI 提示詞正確性
- Docker Compose 一個指令啟動完整服務
