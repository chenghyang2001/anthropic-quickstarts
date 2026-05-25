# 應用程式規格書：FileSense

## 專案概述

FileSense 是一款隱私優先的本機檔案搜尋與整理工具。背景索引守護程序監控設定的資料夾，從檔案中萃取文字並將語意嵌入向量儲存至 ChromaDB。Tkinter 懸浮視窗（Ctrl+Space）讓使用者以自然語言搜尋；Claude 對結果重新排名，並可建議資料夾重新整理方案。所有處理均在本機完成——任何檔案內容都不會離開使用者的電腦。

**主要受眾：** 開發者、研究人員及知識工作者，擁有大量本機檔案集合，希望在不使用雲端儲存的情況下享有 Google 等級的語意搜尋體驗。

---

## 技術堆疊

| 層級               | 技術                                                |
|--------------------|-----------------------------------------------------|
| UI                 | Tkinter（懸浮視窗）+ ttkbootstrap（主題）           |
| 背景守護程序       | Python watchdog 4.0 + threading                     |
| 嵌入向量模型       | sentence-transformers（all-MiniLM-L6-v2，本機）     |
| 向量資料庫         | ChromaDB 0.5（持久化，本機）                        |
| AI 重新排名        | Anthropic Claude (claude-sonnet-4-6)               |
| 檔案解析           | pdfplumber、python-docx、markdown-it-py、chardet    |
| 中繼資料資料庫     | SQLite（透過 SQLAlchemy 2.0）                       |
| 檔案監控           | watchdog 4.0                                        |

---

## 核心功能

### 1. 背景索引守護程序
- 以系統服務（`filesense-daemon`）或啟動時的背景程序方式執行
- 遞迴監控設定資料夾中的檔案建立/修改/刪除事件
- 從以下格式萃取文字內容：.txt、.md、.py、.js、.ts、.go、.pdf、.docx、.csv
- 跳過二進位檔案、node_modules、.git 目錄、大於 50MB 的檔案
- 使用 sentence-transformers 產生嵌入向量（384 維，適合 CPU 運算）
- 嵌入向量儲存至 ChromaDB，中繼資料儲存至 SQLite
- 限制每秒最多處理 5 個檔案，避免大型初始掃描時 CPU 峰值

### 2. 語意搜尋
- Ctrl+Space 從作業系統任意位置開啟 Spotlight 風格懸浮視窗
- 使用者輸入自然語言查詢：「上個月關於機器學習的筆記」
- 查詢即時嵌入（< 100ms）；ChromaDB 回傳前 50 個候選結果
- 結果以檔案卡片顯示：圖示、名稱、上層資料夾、日期、摘錄
- 鍵盤導覽：方向鍵、Enter 開啟、Esc 關閉

### 3. Claude 重新排名與查詢理解
- 對於模糊查詢，Claude 解讀意圖並精煉 ChromaDB 篩選條件
- Claude 將前 50 個候選結果重新排名為前 10，依據對查詢的語意相關性
- 解釋最佳結果：「此檔案符合，因為它討論了三月份的梯度下降」
- 「詢問檔案」模式：「上週我寫了什麼關於 API 設計的內容？」→ Claude 使用檔案摘錄作為脈絡回答

### 4. 重複檔案偵測
- 內容雜湊（SHA-256）偵測跨監控資料夾的完全重複檔案
- 語意相似度（cosine > 0.95）偵測近似重複（相同內容，不同格式）
- UI 中的重複報告：並排預覽，一鍵移至垃圾桶
- 可設定閾值：嚴格（0.98）/ 寬鬆（0.90）

### 5. 智慧資料夾建議
- Claude 分析目標資料夾中未整理的檔案叢集
- 建議資料夾名稱以及各檔案應歸屬的位置
- 範例輸出：「23 個檔案似乎與『Project Alpha』相關——建立 /ProjectAlpha/？」
- 使用者可逐一或批次核准移動；變更可復原（還原堆疊）

### 6. 檔案標籤
- 索引時 AI 自動標記：每個檔案萃取 3-5 個主題標籤（Claude 或關鍵字萃取）
- UI 中手動管理標籤：新增、移除、重新命名
- 基於標籤的搜尋：在懸浮視窗中依標籤篩選結果
- 標籤儲存在 SQLite `file_tags` 表中，可透過 FTS5 搜尋

### 7. 資料夾監控設定
- GUI 設定面板：新增/移除監控資料夾
- 每個資料夾的規則：包含/排除規則（glob）、最大檔案大小、檔案類型篩選
- 暫停特定資料夾的索引（例如下載資料夾在活躍使用期間）
- 索引統計：每個資料夾的總檔案數、總嵌入數、最後掃描時間

### 8. 隱私保障
- 嵌入向量模型完全在 CPU 上執行（不需要 GPU，嵌入不呼叫雲端 API）
- Claude API 僅用於重新排名及建議（僅傳送摘錄，不傳送完整檔案）
- 可完全停用 Claude（純本機模式——僅使用 ChromaDB 搜尋）
- 記錄檔儲存於本機；無遙測、無分析資料

---

## 資料庫 Schema

```sql
-- SQLite：檔案中繼資料、標籤、歷史記錄
CREATE TABLE indexed_files (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path       TEXT UNIQUE NOT NULL,
    file_name       TEXT NOT NULL,
    extension       TEXT,
    size_bytes      INTEGER,
    content_hash    SHA256 TEXT,        -- 用於完全重複偵測
    chroma_doc_id   TEXT UNIQUE,        -- ChromaDB 文件 ID
    last_modified   DATETIME NOT NULL,
    last_indexed    DATETIME NOT NULL,
    word_count      INTEGER,
    language        TEXT                -- 偵測到的語言
);

CREATE TABLE file_tags (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    file_id     INTEGER NOT NULL REFERENCES indexed_files(id) ON DELETE CASCADE,
    tag         TEXT NOT NULL,
    source      TEXT DEFAULT 'manual',  -- 'auto' | 'manual'
    created_at  DATETIME NOT NULL,
    UNIQUE(file_id, tag)
);

CREATE TABLE watch_folders (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    folder_path     TEXT UNIQUE NOT NULL,
    include_globs   TEXT DEFAULT '*',
    exclude_globs   TEXT DEFAULT 'node_modules/**,.git/**',
    max_file_mb     INTEGER DEFAULT 50,
    is_active       BOOLEAN DEFAULT 1,
    added_at        DATETIME NOT NULL
);

CREATE TABLE search_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    query       TEXT NOT NULL,
    result_count INTEGER,
    top_file_id INTEGER REFERENCES indexed_files(id),
    searched_at DATETIME NOT NULL
);

-- FTS5 用於標籤搜尋
CREATE VIRTUAL TABLE file_tags_fts USING fts5(
    tag, file_id UNINDEXED,
    content='file_tags', content_rowid='id'
);
```

ChromaDB 集合：`filesense_embeddings`
- Document：萃取的文字摘錄（前 512 個 token）
- Metadata：`{ file_path, file_name, extension, last_modified, tags }`
- Embedding：384 維 float32（sentence-transformers all-MiniLM-L6-v2）

---

## 架構 / UI 版面

```
┌─────────────────────────────────────────────────────────────┐
│  系統匣圖示（守護程序狀態指示器）                            │
│  右鍵選單：暫停 / 設定 / 結束                               │
└─────────────────────────────────────────────────────────────┘
          │ Ctrl+Space 觸發
          ▼
┌─────────────────────────────────────────────────────────────┐
│  ┌──────────────────────────────────────────────────────┐   │
│  │  🔍 搜尋您的檔案...                         [×]      │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  📄 design-notes.md          ~/Projects  2 天前     │    │
│  │     "...梯度下降在此較為適合..."                    │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │  📄 ml-references.txt        ~/Documents  1 週前    │    │
│  │     "...反向傳播概述，學習率排程..."               │    │
│  ├─────────────────────────────────────────────────────┤    │
│  │  📂 [開啟資料夾] [顯示重複檔案] [整理...]          │    │
│  └─────────────────────────────────────────────────────┘    │
│  Claude：「最佳結果符合，因為它涵蓋了梯度...」              │
└─────────────────────────────────────────────────────────────┘

背景守護程序（獨立程序）：
  watchdog → FileEventHandler → TextExtractor → Embedder → ChromaDB + SQLite
```

---

## 主要互動流程

### 流程 1：自然語言檔案搜尋
1. 使用者按下 Ctrl+Space；懸浮視窗動畫開啟（< 80ms）
2. 使用者輸入「上季關於 API 設計的會議筆記」
3. 查詢即時嵌入；ChromaDB ANN 搜尋回傳前 50 個結果
4. Claude 接收查詢 + 前 50 個摘錄，回傳帶說明的前 10 名排名
5. 結果以卡片渲染；使用者按 Enter 以預設應用程式開啟檔案

### 流程 2：重複檔案偵測與清理
1. 使用者開啟設定 > 重複檔案面板
2. 守護程序掃描 indexed_files 中符合 content_hash 的值（完全重複）
3. 對相同資料夾中的檔案，透過 ChromaDB 成對相似度尋找近似重複
4. UI 列出重複配對，並提供並排摘錄預覽
5. 使用者對各重複檔案選擇「移至垃圾桶」；60 秒內可復原

### 流程 3：智慧資料夾整理
1. 使用者在 UI 中右鍵點擊雜亂的資料夾，選擇「建議整理方案」
2. Claude 接收檔名清單 + 每個檔案的主要關鍵字（不含完整內容）
3. Claude 回傳 JSON：建議的子資料夾及檔案歸屬
4. UI 呈現預覽樹狀結構；使用者勾選/取消勾選後套用
5. 檔案以原子方式移動；可透過還原堆疊復原（SQLite journal）

---

## 實作步驟

1. **守護程序骨架** — `filesense_daemon.py`、watchdog 設定、PID 檔案管理
2. **文字萃取層** — pdfplumber、python-docx、純文字、chardet 編碼偵測
3. **嵌入管道** — sentence-transformers 載入器、ChromaDB 集合初始化、批次 upsert
4. **SQLite 模型** — `indexed_files`、`file_tags`、`watch_folders`、`search_history`
5. **Tkinter 懸浮視窗** — ttkbootstrap 主題視窗、鍵盤綁定、結果卡片元件
6. **Claude 整合** — 重新排名提示、資料夾建議提示、僅含摘錄的 payload
7. **重複偵測器** — SHA-256 雜湊比對 + ChromaDB cosine 相似度掃描器
8. **設定 UI** — 監控資料夾管理、排除規則、重複閾值滑桿

---

## 成功標準

### 功能性
- 在現代筆記型電腦 CPU 上，10,000 個檔案的初始索引在 20 分鐘內完成
- 語意搜尋對測試查詢集的相關結果（前 3 名含目標檔案）回傳正確
- 重複偵測在測試集中找出 100% 的完全重複及超過 90% 的近似重複

### 使用者體驗
- 懸浮視窗從按下 Ctrl+Space 到開啟在 80ms 內完成
- 每次按鍵後 300ms 內更新搜尋結果
- 守護程序在閒置時 CPU 使用率 < 5%（watchdog + 無主動索引）

### 技術品質
- ChromaDB 與 SQLite 在守護程序非正常關閉後保持一致（WAL 模式）
- 全文標籤搜尋在 100k 個標籤條目中 50ms 內回傳結果
- Claude 僅以摘錄呼叫（最多 2000 個 token），絕不傳送完整檔案內容
- 單元測試涵蓋所有支援檔案類型的文字萃取（含邊界案例輸入）
