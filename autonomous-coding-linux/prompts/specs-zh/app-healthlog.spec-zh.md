# 應用程式規格書：HealthLog

## 專案概述

HealthLog 是一款完全在本機執行的個人健康追蹤工具。使用者可透過 Streamlit 網頁 UI 或快速輸入 CLI，記錄餐食、運動、睡眠、體重、情緒及飲水量。Claude 產生每週 AI 健康報告，識別「睡眠不足 7 小時與較低情緒分數相關」等規律。所有資料儲存於 SQLite——無需雲端同步，無需帳號。

**主要受眾：** 注重健康的個人，希望擁有附有 AI 洞察的個人資料日誌，同時不需訂閱健身應用程式或與第三方分享健康資料。

---

## 技術堆疊

| 層級          | 技術                                                |
|---------------|-----------------------------------------------------|
| 網頁 UI       | Streamlit 1.35（多頁面應用程式）                   |
| CLI           | Python + Click 8                                    |
| AI 報告       | Anthropic Claude (claude-sonnet-4-6)               |
| 資料庫        | SQLite（透過 SQLAlchemy 2.0）                       |
| 資料分析      | pandas 2.2                                          |
| 圖表          | Plotly 5.22                                         |
| 通知          | plyer 2.1（跨平台桌面通知）                        |
| 匯出          | pandas CSV 匯出 + fpdf2 產生 PDF                   |

---

## 核心功能

### 1. 多類別記錄（網頁 UI）
- 餐食：名稱、卡路里、蛋白質（g）、碳水化合物（g）、脂肪（g）、餐食類型（早餐/午餐/晚餐/點心）
- 運動：類型（有氧/肌力/瑜伽/其他）、時長（分鐘）、強度（1-10）、消耗卡路里
- 睡眠：就寢時間、起床時間、品質評分（1-5）、備注（夢境、中斷）
- 體重：數值（kg/lbs，可設定）、體脂率（選填）
- 情緒：分數（1-10）、精力水平（1-10）、自由輸入備注
- 飲水量：每天杯數（UI 中提供快速增加按鈕）

### 2. 快速 CLI 記錄
- `healthlog meal "oatmeal 400cal" --time breakfast` — 以自然語言解析快速輸入
- `healthlog sleep 7.5 --quality 4` — 幾秒內記錄昨晚的睡眠
- `healthlog weight 72.5` — 自動帶入時間戳記的體重記錄
- `healthlog mood 7 --energy 8 --note "productive day"` — 情緒記錄
- `healthlog water +1` — 增加今日飲水計數
- 若未提供宏量營養素，Claude 解析模糊的餐食描述以萃取宏量

### 3. 每週 AI 健康報告
- 每週日早上 8 點（可設定）Claude 產生結構化報告
- 報告涵蓋：平均睡眠、運動頻率、卡路里趨勢、情緒規律
- 規律偵測：「您在睡眠 < 7 小時的天數情緒分數平均 6.1，≥ 7 小時為 7.8」
- 個人化建議：「考慮在週二增加 15 分鐘有氧——最近 4 週有 3 週跳過」
- 報告儲存於 `ai_reports` 表；可在報告頁面存取
- 隨選報告：UI 中的「產生本週報告」按鈕

### 4. 趨勢圖表（Plotly）
- 體重圖：折線圖附 7 天移動平均線及目標線疊加
- 睡眠圖：長條圖（小時數）附品質色彩編碼（綠/黃/紅）
- 情緒 & 精力：雙軸折線圖
- 卡路里：依餐食類型的堆疊長條圖，附基礎代謝率基準標記
- 運動頻率：每週熱力圖（GitHub 風格）
- 所有圖表支援互動：縮放、懸停提示、日期範圍滑桿

### 5. 目標追蹤
- 建立目標：「連續 21 天睡眠 ≥ 7 小時」
- 目標類型：連續（連續天數）、累積（期間內的總計）、平均
- 儀表板中每個活躍目標的進度條
- 達成目標時發送通知（plyer 桌面通知）
- 目標歷史：已完成、已失敗、進行中

### 6. 匯出選項
- CSV 匯出供就醫使用：全部資料或依類別，可選擇日期範圍
- PDF 週報：fpdf2，包含所有圖表（PNG）及 AI 摘要文字
- 資料可攜性：完整 SQLite 資料庫備份（單一檔案複製）
- 從 CSV 匯入：大量歷史資料匯入，附欄位對應精靈

### 7. 提醒通知
- 每個類別的每日提醒時間可獨立設定（例如晚上 9 點睡眠記錄提醒）
- plyer 發送作業系統原生桌面通知，附「立即記錄」動作
- Streamlit 啟動時，通知排程器在背景執行緒中執行
- 支援貪睡：30 分鐘後再次提醒

### 8. 儀表板總覽
- 今日摘要：已攝入卡路里、完成運動、昨晚睡眠、飲水計數
- 一週概覽：每個類別的完成圓環（類似 Apple Watch）
- 連續記錄計數：當前及最佳連續天數
- 快速新增按鈕（列出最近餐食，可一鍵重新記錄）

---

## 資料庫 Schema

```sql
CREATE TABLE daily_logs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    log_date    DATE NOT NULL,
    weight_kg   REAL,
    water_glasses INTEGER DEFAULT 0,
    mood_score  INTEGER CHECK(mood_score BETWEEN 1 AND 10),
    energy_level INTEGER CHECK(energy_level BETWEEN 1 AND 10),
    mood_notes  TEXT,
    sleep_start DATETIME,
    sleep_end   DATETIME,
    sleep_quality INTEGER CHECK(sleep_quality BETWEEN 1 AND 5),
    sleep_notes TEXT,
    UNIQUE(log_date)
);

CREATE TABLE meals (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    log_date    DATE NOT NULL,
    logged_at   DATETIME NOT NULL,
    meal_type   TEXT NOT NULL,          -- 'breakfast'|'lunch'|'dinner'|'snack'
    name        TEXT NOT NULL,
    calories    INTEGER,
    protein_g   REAL,
    carbs_g     REAL,
    fat_g       REAL,
    source      TEXT DEFAULT 'manual'   -- 'manual' | 'cli' | 'ai_parsed'
);

CREATE TABLE exercises (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    log_date        DATE NOT NULL,
    logged_at       DATETIME NOT NULL,
    exercise_type   TEXT NOT NULL,
    duration_mins   INTEGER NOT NULL,
    intensity       INTEGER CHECK(intensity BETWEEN 1 AND 10),
    calories_burned INTEGER,
    notes           TEXT
);

CREATE TABLE goals (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    name            TEXT NOT NULL,
    category        TEXT NOT NULL,      -- 'sleep'|'weight'|'exercise'|'calories'
    goal_type       TEXT NOT NULL,      -- 'streak'|'cumulative'|'average'
    target_value    REAL NOT NULL,
    target_unit     TEXT,               -- 'hours', 'days', 'kg' 等
    period_days     INTEGER DEFAULT 7,
    started_at      DATE NOT NULL,
    ended_at        DATE,
    status          TEXT DEFAULT 'active' -- 'active'|'completed'|'failed'
);

CREATE TABLE ai_reports (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    report_date DATE NOT NULL,
    period_start DATE NOT NULL,
    period_end   DATE NOT NULL,
    summary_text TEXT NOT NULL,
    raw_claude_response TEXT,
    generated_at DATETIME NOT NULL
);
```

---

## 架構 / UI 版面

```
Streamlit 多頁面應用程式（5 個頁面）：

┌──────────────────────────────────────────────────────────────┐
│  側邊欄                                                       │
│  📊 儀表板                                                    │
│  ✏️  今日記錄                                                 │
│  📈 圖表                                                      │
│  🤖 AI 報告                                                   │
│  ⚙️  設定                                                     │
└──────────────────────────────────────────────────────────────┘

儀表板頁面：
┌─────────────┬─────────────┬─────────────┬─────────────┐
│  卡路里     │  運動       │  睡眠       │  飲水       │
│  1,840 大卡 │  45 分鐘    │  7.2 小時   │  6 杯       │
│  ▓▓▓▓▓▓▓░  │  ▓▓▓▓▓▓░░  │  ▓▓▓▓▓▓▓░  │  ▓▓▓▓▓▓░░  │
└─────────────┴─────────────┴─────────────┴─────────────┘
  [一週概覽——7 天完成度格狀圖]
  [活躍目標：體重：▓▓▓▓▓░ 68% | 睡眠連續：12 天]

CLI 介面：
  healthlog [meal|sleep|weight|mood|water|report|export] [args] [options]
```

---

## 主要互動流程

### 流程 1：透過 CLI 快速每日記錄
1. 使用者執行 `healthlog meal "chicken salad 500cal 35g protein" --time lunch`
2. CLI 呼叫 Claude 解析描述並萃取宏量分解
3. 經驗證的條目附帶當前時間戳記插入 `meals` 表
4. 終端機確認：「已記錄：雞肉沙拉——500 大卡，35g 蛋白質，預估 20g 碳水，18g 脂肪」
5. 若當日卡路里目標即將超標，CLI 顯示黃色警告

### 流程 2：每週 AI 報告產生
1. 週日早上 8 點背景任務觸發（或使用者在 UI 點擊「產生報告」）
2. pandas 從 `daily_logs`、`meals`、`exercises` 表彙總過去 7 天資料
3. 摘要統計數字送至 Claude（平均值、總計、分佈資料——不含原始資料列）
4. Claude 回傳結構化文字：概覽段落 + 規律發現 + 3 個建議
5. 報告儲存至 `ai_reports`，在 AI 報告頁面以語法醒目提示渲染

### 流程 3：查看圖表並為就醫匯出資料
1. 使用者進入圖表頁面，從日期滑桿選擇「最近 90 天」
2. 體重圖渲染附 7 天移動平均線及目標值疊加
3. 使用者選擇「匯出 > 就醫用 CSV」，勾選所有類別
4. CSV 下載完成，每天一列，包含所有已記錄指標的欄位
5. 可選擇性產生 PDF 報告，包含以 PNG 格式儲存的 Plotly 圖表

---

## 實作步驟

1. **專案骨架** — `pyproject.toml`、`src/healthlog/`、Click CLI 進入點、Streamlit 頁面
2. **SQLAlchemy 模型** — 5 張表含約束條件，Alembic 遷移，種子資料腳本
3. **CLI 指令** — `meal`、`sleep`、`weight`、`mood`、`water`，附 Click 選項 + Claude 宏量解析器
4. **資料彙總層** — 每日、每週、每月摘要的 pandas 查詢
5. **Streamlit 頁面** — 儀表板、今日記錄表單、圖表（Plotly）、AI 報告、設定
6. **Claude 整合** — 附摘要統計的週報提示，宏量解析提示
7. **通知系統** — 背景執行緒、plyer 通知、可設定排程
8. **匯出模組** — CSV（pandas）、PDF（fpdf2 + Plotly PNG 匯出）

---

## 成功標準

### 功能性
- 全部 6 個記錄類別透過 CLI 及網頁 UI 均可接受有效輸入
- 每週 AI 報告在 15 秒內產生，並涵蓋全部 6 個指標
- 圖表在 7 天至 365 天的日期範圍內正確渲染

### 使用者體驗
- CLI 記錄指令（含 Claude 宏量解析）在 3 秒內完成
- 儀表板在 1 年資料集下 2 秒內載入
- 所有圖表支援行動裝置（Streamlit 中 Plotly 響應式版面）

### 技術品質
- `log_date` UNIQUE 約束防止 daily_logs 出現重複列
- 所有 Claude 呼叫僅使用摘要統計（prompt 中不含原始個人健康資料列）
- SQLite WAL 模式啟用，支援 CLI 與 Streamlit 並行存取
- 單元測試涵蓋 CLI 引數解析、宏量萃取及報告產生
