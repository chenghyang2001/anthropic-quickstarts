# 應用程式規格書：MeetingMind

## 專案概述

MeetingMind 是一款完全在本機運作的桌面應用程式，負責錄製、轉錄及摘要會議內容。透過麥克風擷取（或從檔案匯入）的音訊，使用在本機運行的 OpenAI Whisper 進行轉錄，再由 Claude 產生結構化摘要：議程項目、會議決議，以及附有負責人的行動項目。音訊及逐字稿均不會離開使用者的電腦。

**主要受眾：** 知識工作者、專案經理及遠端團隊，需要可搜尋、可行動的會議記錄，同時不依賴雲端服務或訂閱費用。

---

## 技術堆疊

| 層級           | 技術                                          |
|----------------|-----------------------------------------------|
| UI 框架        | PyQt6 6.7                                     |
| 音訊擷取       | PyAudio 0.2.14                                |
| 音訊/影片 I/O  | ffmpeg-python（subprocess 封裝）              |
| 轉錄           | openai-whisper（本機，CPU/GPU）               |
| AI 摘要        | Anthropic Claude (claude-sonnet-4-6)         |
| 資料庫         | SQLite（透過 SQLAlchemy 2.0）                 |
| 匯出           | python-docx、fpdf2、Markdown（內建）          |
| 搜尋           | SQLite FTS5 全文搜尋                          |

---

## 核心功能

### 1. 音訊錄製
- UI 工具列提供開始/停止/暫停錄製控制項
- 即時音量表（VU meter 元件，PyQt6 畫布）
- 可從所有可用麥克風中設定輸入裝置
- 錄製儲存為 16kHz 單聲道 WAV，以獲得最佳 Whisper 效能
- 每 5 分鐘自動儲存以防資料遺失

### 2. 檔案匯入
- 拖放或檔案選擇器：接受 WAV、MP3、M4A、MP4、MKV、WebM
- ffmpeg 自動從影片檔案中萃取音訊軌
- 萃取過程中顯示含取消選項的進度對話框
- 驗證音訊長度：若超過 3 小時則發出警告（Whisper 記憶體限制）

### 3. 透過 Whisper 進行本機轉錄
- 模型選擇：tiny / base / small / medium（使用者自選速度與準確度的平衡）
- 轉錄在背景 QThread 中執行（UI 保持回應）
- 進度條顯示轉錄完成百分比
- Whisper 回傳詞級時間戳記——用於可點擊的逐字稿導覽
- 語言自動偵測，並提供手動覆蓋選項

### 4. AI 驅動的摘要
- Claude 接收完整逐字稿文字 + 會議中繼資料（標題、與會者）
- 結構化輸出：會議目的、議程項目、關鍵決策、行動項目
- 行動項目格式：`[ ] 任務描述 — 負責人：@姓名 — 截止日：日期`
- 摘要以可折疊區塊渲染於右側面板
- 「重新摘要」按鈕可依自訂重點指示重新產生摘要

### 5. 說話者分離
- 基本說話者區隔：使用音訊能量 + 停頓分析偵測說話者切換
- 自動標記：Speaker 1、Speaker 2、Speaker 3
- 使用者可在逐字稿中雙擊標籤重新命名（持久化至資料庫）
- 分離結果以彩色區塊顯示於逐字稿時間軸滑桿

### 6. 匯出選項
- **DOCX**：會議標頭、議程表格、逐字稿本文、行動項目核取清單
- **PDF**：透過 fpdf2 格式化，含公司商標占位符及頁碼
- **Markdown**：與 Notion 相容，行動項目使用核取方塊語法
- **CSV**：僅行動項目（供匯入專案管理工具）
- 批次匯出：從清單中選取多個會議並全部匯出

### 7. 全文搜尋
- 對所有逐字稿文字建立 SQLite FTS5 索引
- 側邊欄搜尋框：使用者輸入時即時顯示結果
- 結果顯示會議標題、日期，以及含關鍵字醒目提示的符合摘錄
- 依日期範圍、與會者姓名或「含行動項目」旗標篩選

### 8. 行事曆整合
- 匯入 `.ics` 檔案以預先填入會議中繼資料（標題、與會者、時間）
- 即將召開的會議面板顯示匯入行事曆的未來 7 天行程
- 從行事曆條目一鍵「開始錄製此會議」
- 不需要 OAuth——僅支援檔案式 ICS 匯入

---

## 資料庫 Schema

```sql
CREATE TABLE meetings (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT NOT NULL,
    recorded_at     DATETIME NOT NULL,
    duration_secs   INTEGER,
    audio_path      TEXT,               -- WAV 檔案的絕對路徑
    whisper_model   TEXT,               -- 'tiny' | 'base' | 'small' | 'medium'
    language        TEXT DEFAULT 'en',
    status          TEXT DEFAULT 'pending', -- 'pending'|'transcribing'|'done'|'error'
    notes           TEXT                -- 會議前的自由格式筆記
);

CREATE TABLE transcripts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    speaker     TEXT,                   -- 'Speaker 1'，可由使用者重新命名
    start_secs  REAL NOT NULL,
    end_secs    REAL NOT NULL,
    text        TEXT NOT NULL
);

CREATE TABLE action_items (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    owner       TEXT,
    due_date    DATE,
    completed   BOOLEAN DEFAULT 0,
    created_at  DATETIME NOT NULL
);

CREATE TABLE participants (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    email       TEXT,
    speaker_label TEXT              -- 對應至 transcript.speaker
);

-- FTS5 虛擬表，用於逐字稿搜尋
CREATE VIRTUAL TABLE transcripts_fts USING fts5(
    text, meeting_id UNINDEXED,
    content='transcripts', content_rowid='id'
);
```

---

## 架構 / UI 版面

```
┌─────────────────────────────────────────────────────────────────────┐
│  選單列：檔案 | 編輯 | 檢視 | 匯出 | 說明                           │
├───────────────────┬─────────────────────────────────────────────────┤
│  左側面板         │  右側面板                                        │
│  ┌─────────────┐  │  ┌──────────────────┬────────────────────────┐  │
│  │ 錄製        │  │  │  逐字稿面板      │  摘要面板              │  │
│  │ 控制項      │  │  │                  │                        │  │
│  │ [●錄製][■]  │  │  │  [Speaker 1]     │  ## 會議摘要           │  │
│  │ [▶匯入]     │  │  │  0:00 內容...    │  **目的：** ...        │  │
│  │             │  │  │  [Speaker 2]     │  **決議：**            │  │
│  │ 音量表 ▓▓   │  │  │  0:43 內容...    │  - 決議 1              │  │
│  ├─────────────┤  │  │                  │                        │  │
│  │ 會議        │  │  │  時間軸 ━━━━━━━  │  **行動項目：**        │  │
│  │ 清單        │  │  │  ▲ 滑桿          │  [ ] 任務 — @負責人   │  │
│  │ > 會議 1    │  │  └──────────────────┴────────────────────────┘  │
│  │   會議 2    │  │  狀態列：轉錄中... 67%                          │  │
│  │   會議 3    │  └─────────────────────────────────────────────────┤
│  ├─────────────┤                                                      │
│  │ 搜尋...     │                                                      │
│  └─────────────┘                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 主要互動流程

### 流程 1：錄製並摘要新會議
1. 使用者點擊錄製按鈕；音訊擷取開始，音量表動畫啟動
2. 使用者點擊停止；WAV 檔案儲存至 `~/MeetingMind/recordings/`
3. 轉錄 QThread 啟動（使用設定中選擇的 Whisper 模型）
4. 隨著 Whisper 處理進度，逐字稿片段即時出現在逐字稿面板
5. 完成後，呼叫 Claude 處理完整逐字稿；摘要出現在右側面板
6. 行動項目自動填入摘要下方的核取清單

### 流程 2：匯入並處理現有錄音
1. 使用者將 MP4 檔案拖放到應用程式視窗
2. 對話框提示輸入會議標題及與會者姓名
3. ffmpeg 將音訊萃取至暫存 WAV；略過現有錄音
4. 執行與流程 1 相同的轉錄 + 摘要管道

### 流程 3：搜尋並匯出過去會議
1. 使用者在側邊欄搜尋框中輸入關鍵字（例如「部署截止日期」）
2. FTS5 回傳排名結果；點擊後開啟該會議
3. 使用者選擇「匯出 > DOCX」；出現檔案儲存對話框
4. 使用 python-docx 產生 DOCX；行動項目顯示為核取方塊清單

---

## 實作步驟

1. **專案骨架** — `src/meetingmind/`、PyQt6 MainWindow 骨架、SQLAlchemy 設定
2. **音訊錄製模組** — PyAudio 串流、WAV 寫入器、音量表元件（QThread）
3. **檔案匯入管道** — ffmpeg-python 封裝、拖放事件處理器
4. **Whisper 轉錄 Worker** — QThread 子類別、進度訊號、片段回呼
5. **Claude 摘要** — 提示範本、結構化輸出解析器、行動項目萃取器
6. **UI 版面** — 分割 QSplitter 版面、逐字稿清單元件、摘要 QTextBrowser
7. **搜尋 & 行事曆** — 逐字稿儲存時的 FTS5 索引建立、ICS 解析器（icalendar 函式庫）
8. **匯出模組** — DOCX（python-docx）、PDF（fpdf2）、Markdown 格式化器

---

## 成功標準

### 功能性
- 使用 Whisper base 模型對清晰英語語音的轉錄準確率 WER ≥ 85%
- Claude 摘要一定包含決策及行動項目各至少一個區塊
- FTS5 搜尋在 500 個會議的資料庫中 200ms 內回傳結果

### 使用者體驗
- 轉錄期間 UI 不凍結（所有繁重工作在 QThread 中執行）
- 從按下錄製按鈕到開始擷取音訊的延遲低於 300ms
- 匯出至 DOCX 時，行動項目核取方塊保留為實際的 Word 核取方塊

### 技術品質
- 音訊檔案以相對路徑儲存至資料庫（可在機器間攜帶）
- Whisper 模型在首次下載後快取至 `~/.cache/meetingmind/`
- 所有逐字稿文字與逐字稿資料列插入時一起原子性地寫入 FTS5 索引
- 單元測試涵蓋 Whisper 片段解析器及 Claude 回應解析器
