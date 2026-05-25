# 應用程式規格書：DocTranslator

## 專案概述

DocTranslator 是一款批次文件翻譯桌面應用程式，以 Claude 作為 AI 翻譯引擎。使用者拖入 Word 文件、PDF 及文字檔，選擇來源語言與目標語言，即可取得保留原始格式的翻譯輸出。術語詞彙表確保技術術語翻譯的一致性。翻譯記憶庫快取先前的句子級翻譯，以降低成本並提升重複內容的一致性。

**主要受眾：** 技術文件撰寫者、法務團隊、學術研究人員，以及需要精確批次翻譯內部文件、又不願將敏感內容上傳至公開翻譯 SaaS 的企業。

---

## 技術堆疊

| 層級             | 技術                                                |
|------------------|-----------------------------------------------------|
| UI 框架          | PyQt6 6.7                                           |
| Word 文件        | python-docx 1.1                                     |
| PDF 萃取         | pdfplumber 0.11                                     |
| AI 翻譯          | Anthropic Claude (claude-sonnet-4-6，串流)         |
| 資料庫           | SQLite（透過 SQLAlchemy 2.0）                       |
| 匯出             | python-docx（DOCX）、fpdf2（PDF）、內建（TXT）      |
| 非同步執行       | QThread + asyncio bridge                            |
| 設定             | python-dotenv + JSON 設定檔                         |

---

## 核心功能

### 1. 批次檔案匯入
- 拖放檔案或資料夾到檔案清單面板
- 支援的輸入格式：.docx、.pdf、.txt、.md
- 檔案清單顯示：檔名、格式圖示、頁數、預估字數、狀態徽章
- 以 Delete 鍵或右鍵選單從佇列移除檔案
- 匯入資料夾：遞迴發現所有支援的檔案（含深度限制）
- 檔案大小限制：若單一檔案超過 100 頁則發出警告（翻譯時間較長）

### 2. 語言選擇
- 來源語言：下拉選單含自動偵測選項（Claude 偵測第一段的語言）
- 目標語言：支援 20 種以上語言，包含 EN、ZH-TW、ZH-CN、JA、KO、FR、DE、ES、PT、AR、RU、IT、NL、PL、SV、TR、VI、TH、ID、UK
- 每個工作階段記憶語言配對並儲存至設定
- 每個檔案可獨立覆蓋語言：右鍵點擊檔案 > 「設定此檔案的語言」

### 3. 串流翻譯
- Claude 逐句翻譯，使用串流 API（逐 token 顯示）
- 右側面板即時預覽：翻譯文字隨 Claude 串流逐漸出現
- 每個檔案的進度條：「第 3 頁，共 12 頁——第 47 句，共 130 句」
- 暫停/繼續按鈕在翻譯進行中停止串流（取消 Claude API 呼叫）
- 狀態列根據當前吞吐量顯示預估剩餘時間

### 4. 並排檢視
- 左側面板：原始文件文字（依段落結構化）
- 右側面板：翻譯文字，隨串流進度即時更新
- 同步捲動：捲動任一面板時另一面板同步移動
- 點擊任何翻譯片段可行內編輯（修正內容儲存至翻譯記憶庫）
- 切換：顯示/隱藏來源文字（全寬翻譯檢視）

### 5. 術語詞彙表
- 詞彙表管理器：新增術語配對（來源術語 → 必要的翻譯）
- 範例：「API」→「API」（保留）、「machine learning」→「機器學習」（強制套用）
- Claude 系統提示在每次翻譯呼叫前包含啟用的詞彙表術語
- 術語在來源及翻譯面板中以工具提示醒目顯示
- 詞彙表可匯入/匯出為 CSV；支援團隊共用詞彙表
- 支援每個專案的詞彙表：不同文件集合使用不同詞彙表

### 6. 翻譯記憶庫
- 每個翻譯句子均快取：（source_lang, target_lang, source_text）→ translated_text
- 呼叫 Claude 前先檢查翻譯記憶庫中的完全符合（100%）或模糊符合（≥ 85%）
- 每個檔案顯示翻譯記憶庫命中率：「42% 的句子來自記憶庫（節省約 $0.03）」
- 手動編輯翻譯記憶庫：修正快取的翻譯，並將修正傳播至所有符合的片段
- 翻譯記憶庫匯入：支援 TMX 格式（標準翻譯記憶庫交換格式）
- 翻譯記憶庫大小限制：可設定最大條目數，超過時以 LRU 淘汰

### 7. 匯出
- **DOCX**：python-docx 保留原始標題樣式、粗體/斜體、清單、表格
- **PDF**：fpdf2 產生含來源語言及目標語言中繼資料的乾淨版面
- **TXT**：純翻譯文字，保留段落換行
- 批次匯出：翻譯所有佇列中的檔案，並以 `_translated` 後綴儲存至輸出資料夾
- 輸出資料夾可在設定中設定；預設為來源檔案所在目錄
- 檔案命名：`original_name_[target_lang].docx`

### 8. 品質審查模式
- 翻譯完成後，Claude 在第二輪對每個句子評分（信心：0.0–1.0）
- 低於可設定閾值（預設 0.75）的句子以橙色醒目顯示
- 品質面板顯示所有標記的片段；點擊可跳至翻譯中的對應位置
- 審查者可以原樣接受、手動編輯，或要求 Claude 附上脈絡提示重新翻譯
- 每份文件的品質分數摘要：「92% 高信心，6% 中等，2% 低信心」

---

## 資料庫 Schema

```sql
CREATE TABLE translation_jobs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    job_name        TEXT,
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    status          TEXT DEFAULT 'pending',  -- 'pending'|'running'|'done'|'error'|'paused'
    created_at      DATETIME NOT NULL,
    started_at      DATETIME,
    finished_at     DATETIME,
    total_files     INTEGER DEFAULT 0,
    completed_files INTEGER DEFAULT 0
);

CREATE TABLE job_files (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    job_id          INTEGER NOT NULL REFERENCES translation_jobs(id),
    original_path   TEXT NOT NULL,
    output_path     TEXT,
    file_format     TEXT NOT NULL,          -- 'docx'|'pdf'|'txt'|'md'
    word_count      INTEGER,
    page_count      INTEGER,
    status          TEXT DEFAULT 'pending', -- 'pending'|'translating'|'done'|'error'
    error_message   TEXT,
    tm_hit_rate     REAL DEFAULT 0.0        -- 來自翻譯記憶庫的句子比例
);

CREATE TABLE translation_memory (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    source_text     TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    source_hash     TEXT NOT NULL,          -- 正規化後 source_text 的 SHA-256
    quality_score   REAL DEFAULT 1.0,
    usage_count     INTEGER DEFAULT 1,
    created_at      DATETIME NOT NULL,
    updated_at      DATETIME NOT NULL,
    UNIQUE(source_hash, source_lang, target_lang)
);

CREATE TABLE glossary_terms (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    glossary_name   TEXT NOT NULL DEFAULT 'default',
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    source_term     TEXT NOT NULL,
    target_term     TEXT NOT NULL,
    case_sensitive  BOOLEAN DEFAULT 0,
    notes           TEXT,
    created_at      DATETIME NOT NULL,
    UNIQUE(glossary_name, source_lang, target_lang, source_term)
);
```

---

## 架構 / UI 版面

```
┌─────────────────────────────────────────────────────────────────────┐
│  選單列：檔案 | 編輯 | 詞彙表 | 翻譯記憶庫 | 說明                   │
├──────────────────────────┬──────────────────────────────────────────┤
│  左側面板                │  右側面板（翻譯工作區）                  │
│                          │  ┌─────────────────┬───────────────────┐ │
│  [+新增檔案] [清除]      │  │  原始文字        │  翻譯文字         │ │
│  ┌──────────────────┐   │  │                 │                   │ │
│  │ 📄 report.docx   │   │  │  段落 1          │  翻譯後的段落 1   │ │
│  │    ● 完成        │   │  │                 │                   │ │
│  │ 📄 manual.pdf    │   │  │  段落 2          │  翻譯中...▌       │ │
│  │    ⏳ 進行中     │   │  │                 │                   │ │
│  │ 📄 notes.txt     │   │  └─────────────────┴───────────────────┘ │
│  │    ○ 佇列中      │   │                                           │
│  └──────────────────┘   │  進度：▓▓▓▓▓▓░░░░ 第 2/3 檔 | 第 4/12 頁  │
│                          │  [▶ 全部翻譯] [⏸ 暫停] [匯出 ▾]          │
│  來源：[自動偵測 ▾]      │                                           │
│  目標：[ZH-TW       ▾]  │  品質標記：3 個片段需要審查              │
│                          │  詞彙表：12 個術語啟用中                  │
│  詞彙表：[預設    ▾]    │  翻譯記憶庫命中：38%（節省約 $0.02）     │
└──────────────────────────┴──────────────────────────────────────────┘
│  狀態列：正在翻譯 report.docx — 第 47/130 句 — 約剩 2 分鐘          │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 主要互動流程

### 流程 1：翻譯單一 DOCX 檔案
1. 使用者將 `report.docx` 拖放到檔案清單；檔案條目出現並附字數
2. 選擇來源：英文，目標：繁體中文（ZH-TW）
3. 點擊「全部翻譯」；開始翻譯 report.docx
4. 每個段落附帶系統提示前置詞彙表術語後送至 Claude
5. 翻譯文字逐段落串流至右側面板
6. 完成後，狀態徽章變為綠色；使用者點擊「匯出 > DOCX」
7. `report_ZH-TW.docx` 以與原始相同的標題樣式儲存

### 流程 2：附翻譯記憶庫的批次翻譯
1. 使用者從產品文件資料夾新增 15 個檔案
2. 翻譯工作開始；對每個句子先檢查翻譯記憶庫
3. 具有完全符合的句子（雜湊符合）直接插入，不呼叫 Claude API
4. 每個檔案顯示翻譯記憶庫命中率；最終報告：「38% 來自記憶庫」
5. 全部 15 個檔案匯出至輸出資料夾；工作記錄至 `translation_jobs` 表

### 流程 3：詞彙表設定與品質審查
1. 使用者開啟詞彙表管理器；匯入含 50 個術語配對的 `terms.csv`
2. 開始翻譯；詞彙表術語在來源面板中以橙色醒目顯示
3. 翻譯完成後，點擊「品質審查」；Claude 對所有句子評分
4. 4 個句子標記為黃色（信心 0.71–0.74）
5. 使用者行內手動編輯 2 個；要求 Claude 附提示重新翻譯剩餘 2 個
6. 修正後的翻譯儲存回翻譯記憶庫並更新 quality_score

---

## 實作步驟

1. **專案骨架** — `pyproject.toml`、`src/doctranslator/`、PyQt6 MainWindow 骨架
2. **檔案解析器** — python-docx 段落萃取器、pdfplumber 文字+頁面萃取器、TXT/MD 讀取器
3. **SQLAlchemy 模型** — 4 張表，Alembic 遷移，翻譯記憶庫雜湊索引
4. **翻譯引擎** — Claude 串流整合、QThread Worker、翻譯記憶庫查詢/寫入
5. **UI 版面** — QSplitter 並排版面、檔案清單 QListWidget、語言下拉選單
6. **詞彙表管理器** — CRUD 對話框、CSV 匯入/匯出、系統提示注入
7. **品質審查模式** — 第二輪 Claude 評分、片段醒目提示、審查面板
8. **匯出模組** — DOCX 樣式保留（python-docx）、PDF（fpdf2）、批次匯出迴圈

---

## 成功標準

### 功能性
- 使用 claude-sonnet-4-6 翻譯英文至中文，10 頁 DOCX 在 90 秒內完成
- 翻譯記憶庫對相同句子（雜湊符合 100%）正確提供快取翻譯
- 詞彙表術語在文件所有段落中以一致的翻譯呈現

### 使用者體驗
- 點擊翻譯後 2 秒內右側面板可見串流翻譯
- 來源與翻譯面板的同步捲動誤差在 1 個段落內
- 在翻譯中途暫停後，從被中斷的確切句子繼續翻譯

### 技術品質
- 匯出的 DOCX 保留原始的 H1/H2 標題、粗體、斜體及表格結構
- 翻譯記憶庫 SHA-256 雜湊索引支援 100k 以上條目的資料庫 O(1) 精確查詢
- Claude 以系統提示傳入詞彙表術語（絕不放在 human turn，以避免 prompt injection）
- 單元測試涵蓋：DOCX 段落萃取、翻譯記憶庫雜湊碰撞處理、語言偵測 fallback
