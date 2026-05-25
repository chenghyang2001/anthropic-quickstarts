# 應用程式規格書：DailyMind — AI 智慧個人日記

## 專案概述

打造一款以 Claude AI 驅動的**桌面日記應用程式**。
DailyMind 結合豐富文字日記編輯與智慧 AI 功能：
情緒分析、自動標籤、反思提示與習慣追蹤 —
所有資料完全本地儲存，無任何雲端依賴。

目標使用者：希望擁有私密、AI 增強個人日記的開發者、作家與知識工作者。

---

## 技術堆疊

### 執行環境與語言
- **Python 3.12+**（主要語言 — 不使用 JavaScript）
- **PyQt6** — 桌面 GUI 框架
- **SQLite + SQLAlchemy** — 本地持久化儲存

### AI 整合
- **Anthropic SDK**（`anthropic`）— 所有 AI 功能使用 Claude API
- 預設模型：`claude-haiku-4-5-20251001`（快速、低成本，適合即時建議）
- 進階模式：`claude-sonnet-4-6`（深度分析）
- API 金鑰：從 `~/.dailymind/config.json` 或 `ANTHROPIC_API_KEY` 環境變數讀取

### 相依套件
- `markdown2` — 在預覽面板中渲染 Markdown
- `PyQtChart` — 情緒趨勢圖表
- `reportlab` — PDF 匯出
- `cryptography` — 日記條目的選用本地加密
- `platformdirs` — 跨平台資料目錄解析

### 資料儲存
- 所有資料儲存於 `~/.dailymind/journal.db`（SQLite）
- 附件儲存於 `~/.dailymind/attachments/`
- 設定存於 `~/.dailymind/config.json`
- 匯出至 `~/Documents/DailyMind/`（或使用者自訂路徑）

### 打包
- 使用 `PyInstaller` 打包為獨立執行檔
- 支援：Windows 10+、macOS 12+、Ubuntu 20.04+

---

## 核心功能

### 1. 日記編輯器
- 分割面板：Markdown 編輯器（左）+ 即時預覽（右）
- 完整 Markdown 支援：標題、粗體、斜體、清單、程式碼區塊、表格
- 拖放插入圖片（儲存於本地附件資料夾）
- 每 60 秒自動儲存 + 關閉視窗時儲存
- 狀態列顯示字數與預估閱讀時間
- 專注模式：隱藏側邊欄，編輯器展開至全寬

### 2. AI 反思與提示
- 「與 AI 反思」按鈕：Claude 分析今日條目並提問 2-3 個深度問題
- 每日寫作提示（應用程式開啟時生成，本地快取）
- 「展開這個想法」— 選取文字後，Claude 在側邊面板展開說明
- 「摘要本週」— Claude 將最近 7 篇條目摘要成週報
- 所有 AI 請求非阻塞（背景執行緒 + 進度指示器）

### 3. 情緒追蹤
- 每篇條目頂部的情緒選擇器：5 個表情等級（😞 😐 🙂 😊 🤩）
- 情緒備註（「睡眠不好」、「會議順利」）
- AI 情緒推斷：未設定時，Claude 從條目內容推斷（含使用者確認）
- 每週情緒長條圖（透過 PyQtChart）
- 每月情緒熱力圖日曆視圖

### 4. 自動標籤與搜尋
- Claude 從條目內容自動生成標籤（儲存時或手動觸發）
- 手動編輯標籤（標籤欄位中以逗號分隔）
- 側邊欄標籤雲視圖
- 跨所有條目的全文搜尋（SQLite FTS5）
- 篩選條件：日期範圍、標籤、情緒、含圖片
- 搜尋結果中高亮顯示匹配詞

### 5. 習慣追蹤
- 定義自訂習慣（如「運動」、「冥想」、「閱讀」）
- 在每日條目底部勾選習慣
- 每個習慣的連續天數計數器
- 每週習慣完成格線（日曆熱力圖）
- Claude 習慣洞察：「你本週運動了 3 次 — 是什麼讓你堅持？」

### 6. 條目組織
- 日曆視圖：點擊任意日期跳至該條目
- 條目分組：今天 / 本週 / 本月 / 封存
- 釘選條目（標記為最愛）
- 範本：晨間筆記、感恩日記、目標回顧（使用者可編輯）
- 條目版本控制：復原歷史保存於 DB（最近 10 個版本）

### 7. 隱私與安全性
- 預設僅限本地（無雲端同步）
- 選用 AES-256 加密整個資料庫（首次執行時設定密碼）
- 可全域停用 AI 功能（無 API 金鑰時完全離線運作）
- API 金鑰儲存於作業系統金鑰鏈（keyring 套件）— 不以明文儲存

### 8. 匯出
- 匯出單一條目：Markdown、PDF、HTML
- 匯出日期範圍：Markdown 檔案的 ZIP 壓縮包
- 匯出全部：完整 JSON 備份
- 匯入：JSON 備份還原、Day One JSON 格式

### 9. 設定與個人化
- 主題：淺色 / 深色 / Solarized / Nord（QSS 樣式表）
- 編輯器字型與大小
- 編輯器行距
- 自動儲存間隔
- AI 模型選擇（Haiku / Sonnet）
- AI 功能開關（提示 / 情緒推斷 / 自動標籤）
- 備份排程（每日 / 每週自動匯出至使用者資料夾）

---

## 資料庫結構

### `entries`（條目）
```sql
id          TEXT PRIMARY KEY  -- UUID
date        TEXT NOT NULL     -- YYYY-MM-DD（每天一篇）
title       TEXT              -- 自動生成或使用者設定
body        TEXT NOT NULL     -- 原始 Markdown 內容
mood        INTEGER           -- 1-5（未設定時為 NULL）
mood_note   TEXT
tags        TEXT              -- JSON 字串陣列
word_count  INTEGER
created_at  TEXT              -- ISO 8601
updated_at  TEXT
is_pinned   INTEGER DEFAULT 0
is_deleted  INTEGER DEFAULT 0
```

### `entry_versions`（條目版本）
```sql
id          TEXT PRIMARY KEY
entry_id    TEXT REFERENCES entries(id)
body        TEXT
saved_at    TEXT
version_num INTEGER
```

### `habits`（習慣）
```sql
id          TEXT PRIMARY KEY
name        TEXT NOT NULL
icon        TEXT              -- 表情符號
color       TEXT              -- 十六進位色碼
sort_order  INTEGER
is_active   INTEGER DEFAULT 1
created_at  TEXT
```

### `habit_logs`（習慣記錄）
```sql
id          TEXT PRIMARY KEY
habit_id    TEXT REFERENCES habits(id)
date        TEXT              -- YYYY-MM-DD
completed   INTEGER DEFAULT 0
note        TEXT
```

### `ai_insights`（AI 洞察）
```sql
id          TEXT PRIMARY KEY
entry_id    TEXT REFERENCES entries(id)
type        TEXT              -- 'reflection' | 'summary' | 'tags' | 'mood_inference'
prompt      TEXT
response    TEXT
model       TEXT
created_at  TEXT
tokens_used INTEGER
```

### `templates`（範本）
```sql
id          TEXT PRIMARY KEY
name        TEXT
body        TEXT              -- Markdown 範本
is_default  INTEGER DEFAULT 0
created_at  TEXT
```

---

## UI 版面

### 主視窗（預設 1200×800，可調整大小）
```
┌─────────────────────────────────────────────────────────┐
│  [☀ DailyMind]  [今天] [日曆] [習慣] [搜尋]             │
├──────────────┬──────────────────────────────────────────┤
│  側邊欄      │  編輯區                                   │
│              │                                          │
│  📅 今天     │  📝 2025年5月26日，星期一                │
│  📅 昨天     │  情緒：😊  標籤：[工作] [寫程式] [+]     │
│  ─────────── │  ─────────────────────────────────────── │
│  本週        │  [Markdown 編輯器]   [預覽]               │
│  • 週一 26   │                                          │
│  • 週日 25   │  今天非常有生產力...                      │
│  • 週六 24   │                                          │
│  ─────────── │                                          │
│  標籤雲      │  ─────────────────────────────────────── │
│  #工作 #AI   │  習慣：✅ 運動  ☐ 冥想                   │
│  #閱讀       │  ─────────────────────────────────────── │
│              │  [💾 儲存] [✨ 與AI反思] [📤 匯出]        │
│  [⚙ 設定]   │                                          │
└──────────────┴──────────────────────────────────────────┘
```

### AI 面板（從右側滑入，寬 400px）
- 由「與 AI 反思」或「展開」按鈕觸發
- 以串流文字顯示 AI 回應
- 複製 / 插入至條目按鈕
- 關閉按鈕

### 日曆視圖（全視窗覆蓋層）
- 月份格線，依情緒顏色標記
- 點擊日期開啟該條目
- 每個日期下方顯示習慣完成點

---

## 關鍵互動流程

### 每日寫作流程
1. 應用程式開啟 → 顯示今日條目（若無則建立）
2. 選用：AI 生成寫作提示（顯示於頂部，可關閉）
3. 使用者以 Markdown 寫作，預覽即時更新
4. 從表情列選擇情緒
5. 勾選完成的習慣
6. 每 60 秒觸發自動儲存
7. 選用：點擊「與 AI 反思」→ AI 提出後續問題
8. 關閉應用程式 → 最終自動儲存 + 若已啟用則加密

### AI 反思流程
1. 使用者點擊「與 AI 反思」
2. 條目內容傳送至 Claude（Haiku 模型）
3. AI 面板顯示串流進度指示
4. Claude 回應 2-3 個反思問題
5. 使用者閱讀後，可選擇將回答寫入條目
6. 互動記錄儲存至 `ai_insights` 表

### 標籤自動生成流程
1. 條目儲存時：背景任務以條目內文呼叫 Claude
2. Claude 回傳 3-5 個建議標籤（JSON）
3. 標籤欄位顯示通知徽章
4. 使用者審閱並接受 / 編輯標籤
5. 標籤儲存至條目

---

## 實作步驟

### 第 1 步：專案基礎
- 設定 Python 虛擬環境 + `requirements.txt`
- 以 SQLAlchemy migrations 初始化 SQLite DB
- 建立帶有功能表列的 PyQt6 主視窗框架
- 實作設定檔（JSON）讀寫
- 設定 loguru 記錄至 `~/.dailymind/logs/`

### 第 2 步：核心編輯器
- 建立分割面板編輯器（QSplitter）
- 整合 markdown2 實現即時預覽（QWebEngineView 或 QTextBrowser）
- 實作條目存取 SQLite 的儲存/載入
- 新增自動儲存計時器
- 狀態列字數顯示

### 第 3 步：側邊欄與導航
- 條目清單面板（依週分組）
- 日曆日期選擇器整合
- 標籤雲元件
- 搜尋列（SQLite FTS5 搜尋）

### 第 4 步：AI 功能
- Anthropic SDK 整合（背景 QThread）
- 「與 AI 反思」按鈕 + 串流回應面板
- 啟動時生成每日寫作提示
- 儲存時自動標籤

### 第 5 步：情緒與習慣追蹤
- 情緒表情選擇器元件
- 習慣核取清單元件（編輯器底部）
- PyQtChart 情緒趨勢圖
- 習慣連續天數計算

### 第 6 步：匯出與隱私
- Markdown / PDF / JSON 匯出（PDF 使用 reportlab）
- 選用 DB 加密（cryptography 套件）
- API 金鑰安全儲存（keyring）

### 第 7 步：精修
- 4 個 QSS 主題（淺色 / 深色 / Solarized / Nord）
- 鍵盤快捷鍵（Cmd+S 儲存、Cmd+K 搜尋等）
- 首次執行的引導精靈
- 錯誤處理與使用者提示訊息

---

## 成功標準

### 功能性
- 每日條目可靠地儲存與載入
- AI 反思在 3 秒內回應（Haiku 模型）
- 1000+ 條條目的搜尋在 500ms 內回傳結果
- 匯出能產生有效的 PDF 和 Markdown 檔案
- 習慣連續天數計算正確

### 使用者體驗
- 應用程式在 2 秒內啟動
- Markdown 預覽即時渲染，無延遲
- AI 面板逐字串流回應（無需等待完整回應）
- 所有鍵盤快捷鍵有文件說明且可正常使用
- 首次使用引導可在 2 分鐘內完成

### 技術品質
- 所有 AI 呼叫包含 try/except，並顯示使用者可讀的錯誤訊息
- API 金鑰不會記錄於日誌或明文檔案
- 無硬編碼路徑（使用 `platformdirs.user_data_dir`）
- 所有 DB 操作使用參數化查詢（無 SQL 注入）
- 單元測試涵蓋：DB 模型、AI 提示詞範本、匯出功能
