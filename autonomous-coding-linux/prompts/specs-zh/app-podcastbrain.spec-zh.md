# 應用程式規格：PodcastBrain — Podcast 轉錄與知識萃取工具

## 專案概述

PodcastBrain 是一款 Streamlit 網頁應用程式，將 Podcast 節目和 YouTube 影片轉換為結構化知識資產。使用者提供 URL 或上傳音訊檔案；yt-dlp 負責下載音訊，OpenAI Whisper 在本地端進行轉錄，不會將音訊傳送至任何外部 API。Claude 接著分析逐字稿，產生章節時間戳記、精簡摘要、重要引句及行動項目。互動式問答模式讓使用者就逐字稿內容直接提問並取得答案。最終形成可永久搜尋的節目知識庫。

---

## 技術堆疊

| 層級             | 技術                                             |
|------------------|--------------------------------------------------|
| 語言             | Python 3.11+                                     |
| Web 框架         | Streamlit                                        |
| 音訊下載         | yt-dlp                                           |
| 轉錄             | openai-whisper（本地端，不需 API Key）           |
| AI 分析          | Anthropic Claude API (`claude-sonnet-4-6`)       |
| 資料庫           | SQLite（透過 SQLAlchemy 2.x ORM）                |
| 音訊處理         | pydub（格式轉換、時長）                          |
| 文字搜尋         | SQLite FTS5（全文搜尋所有逐字稿）                |
| 匯出             | markdown、reportlab（PDF）、srt（字幕匯出）      |
| 依賴套件         | streamlit, yt-dlp, openai-whisper, anthropic,    |
|                  | sqlalchemy, pydub, reportlab                     |

---

## 核心功能

### 1. 音訊輸入 — URL 與檔案上傳
- URL 輸入欄位：接受 YouTube、Spotify（公開）、直接 MP3/M4A URL
- yt-dlp 下載最高品質的純音訊串流至暫存資料夾
- 檔案上傳元件：接受 mp3、m4a、wav、ogg（最大 500MB）
- 輸入驗證：開始下載前先確認 URL 可連線
- 開始處理前顯示預估檔案大小和時長
- 取消按鈕：下載超過 60 秒時終止 yt-dlp 子程序

### 2. 本地端 Whisper 轉錄
- 模型選擇：tiny / base / small / medium / large（使用者依速度與品質取捨選擇）
- 轉錄在子程序中執行，避免阻塞 Streamlit 主執行緒
- 進度條：依音訊時長 / 預期處理時間估算進度
- Whisper 回傳：完整文字 + 含開始 / 結束時間戳記的片段
- 片段以 JSON 儲存至資料庫，供問答和章節偵測使用
- 模型為 medium 或 large 時啟用詞級時間戳記（供標記功能使用）
- 語言自動偵測（Whisper 內建）；使用者可覆蓋強制指定語言

### 3. Claude AI 分析 — 章節偵測
- 將完整逐字稿（若超過 100k 字元則分段）送至 Claude
- Claude 依主題轉換識別章節邊界
- 回傳 JSON：`[{title, start_seconds, end_seconds, summary_2_sentences}]`
- 章節在 Streamlit 中以可點擊的時間軸列顯示
- 後備方案：節目不足 10 分鐘時跳過章節偵測（單一章節）
- 章節編輯模式：使用者可在儲存前重新命名或合併章節

### 4. Claude AI 分析 — 摘要與洞察
- 摘要（3–5 段）：主要主題、論點、結論
- 重要引句：5–7 個原文引述含時間戳記
- 行動項目：講者提及的具體下一步條列清單
- 來賓 / 講者識別：Claude 從逐字稿上下文推斷姓名
- 情感分析：整體節目調性（教育 / 辯論 / 訪談 / 故事敘述）
- 所有分析以結構化 JSON 儲存於 episodes.claude_analysis

### 5. 「詢問本集」問答模式
- 文字輸入：使用者輸入任何關於節目內容的問題
- 透過關鍵字 + Claude 上下文窗口檢索相關逐字稿片段
- Claude 僅依逐字稿內容作答（不在來源之外產生幻覺）
- 答案包含：回應文字 + 支持引句 + 時間戳記參照
- 每集問答歷史儲存於 qa_history 資料表
- 「引用逐字稿」切換：強制 Claude 在回答前引用確切來源
- 批次問答：執行問題清單並一次取得所有答案

### 6. 匯出選項
- Markdown 筆記：標題、摘要、章節、重要引句、行動項目
- 含時間戳記的 PDF：相同內容，A4 格式（reportlab）
- SRT 字幕檔案：Whisper 片段轉換為 SRT 時間戳記格式
- 純文字逐字稿 TXT：僅原始文字
- 匯出所有節目為 ZIP 壓縮檔
- 剪貼簿複製：一鍵複製摘要或特定段落

### 7. 節目庫與搜尋
- 所有已處理節目儲存至 SQLite 含中繼資料
- 全文搜尋：SQLite FTS5 同時搜尋所有逐字稿
- 搜尋結果：節目標題 + 符合摘錄 + 時間戳記連結
- 篩選條件：日期範圍、時長、來源 URL 網域
- 節目詳細檢視：顯示所有分頁（逐字稿 / 章節 / 分析 / 問答）
- 排序方式：加入日期、時長、節目標題

### 8. 批次處理佇列
- 佇列管理員：在開始處理前新增多個 URL 或檔案
- 佇列表格：顯示狀態（待處理 / 下載中 / 轉錄中 / 分析中 / 完成）
- 循序處理：每次一個，以配合硬體限制
- 依音訊時長 * 處理係數顯示預估總時間
- 佇列完成時發送電子郵件通知（可選 SMTP 設定）
- 暫停 / 繼續佇列而不遺失進度

---

## 資料庫 Schema

```sql
CREATE TABLE episodes (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    title           TEXT,                             -- 節目標題
    source_url      TEXT,                             -- 來源 URL
    source_type     TEXT NOT NULL DEFAULT 'youtube',  -- youtube | upload | url
    audio_path      TEXT,                             -- 本地暫存檔案路徑
    duration_secs   INTEGER,                          -- 音訊時長（秒）
    whisper_model   TEXT DEFAULT 'base',              -- 使用的 Whisper 模型
    language        TEXT DEFAULT 'en',                -- 語言
    status          TEXT DEFAULT 'pending',           -- pending|downloading|transcribing|analyzing|done|error
    error_message   TEXT,                             -- 錯誤訊息
    claude_analysis TEXT,                             -- JSON：摘要、引句、行動、章節
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    processed_at    DATETIME                          -- 處理完成時間
);

CREATE TABLE transcripts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    episode_id  INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    full_text   TEXT NOT NULL,                       -- 完整逐字稿文字
    segments    TEXT NOT NULL,                       -- JSON：[{start, end, text}]
    word_count  INTEGER,                             -- 字數
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE chapters (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    episode_id      INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    title           TEXT NOT NULL,                   -- 章節標題
    start_seconds   INTEGER NOT NULL,                -- 章節開始秒數
    end_seconds     INTEGER,                         -- 章節結束秒數
    summary         TEXT,                            -- 章節摘要
    sort_order      INTEGER DEFAULT 0                -- 排序順序
);

CREATE TABLE qa_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    episode_id  INTEGER NOT NULL REFERENCES episodes(id) ON DELETE CASCADE,
    question    TEXT NOT NULL,                       -- 使用者問題
    answer      TEXT NOT NULL,                       -- Claude 答案
    source_ts   INTEGER,                             -- 支持引句的時間戳記（秒）
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- FTS5 虛擬資料表，供全文搜尋使用
CREATE VIRTUAL TABLE transcripts_fts USING fts5(
    episode_id UNINDEXED,
    full_text,
    content='transcripts',
    content_rowid='id'
);
```

---

## 架構 / UI 版面

```
┌──────────────────────────────────────────────────────────────────┐
│  PodcastBrain                                                    │
├───────────────────────┬──────────────────────────────────────────┤
│  側邊欄               │  主要區域                                │
│                       │                                          │
│  🎙 PodcastBrain      │  ┌────────────────────────────────────┐  │
│                       │  │  🔗 貼上 URL 或上傳音訊            │  │
│  [+ 新增節目]         │  │  ──────────────────────────────    │  │
│                       │  │  URL: [________________________]   │  │
│  📚 節目庫            │  │       [處理節目]                   │  │
│  ─────────────        │  └────────────────────────────────────┘  │
│  Lex Fridman #401     │                                          │
│  ✅ 2 小時 34 分      │  ── 處理狀態 ──                          │
│                       │  ✅ 下載完成（124 MB）                   │
│  How I Built This     │  ✅ 轉錄：100%（whisper/base）           │
│  ✅ 45 分鐘           │  ⏳ Claude 分析進行中...                │
│                       │                                          │
│  My First Million     │  ── 節目：Lex Fridman #401 ──           │
│  🔄 處理中...         │  [摘要][章節][逐字稿][問答]             │
│                       │                                          │
│  [🔍 搜尋全部]        │  章節分頁：                             │
│                       │  ──────────────────────────────────     │
│  佇列（1 個待處理）   │  0:00 ── 開場與來賓介紹                 │
│  ─────────────        │  12:34 ── 主要主題：AGI 時間線          │
│  Guy Raz Ep 302       │  45:20 ── 辯論：安全 vs 進步            │
│  [暫停佇列]           │  1:22:10 ── 個人故事                    │
│                       │  1:55:44 ── 快問快答                    │
└───────────────────────┴──────────────────────────────────────────┘

問答分頁：
┌──────────────────────────────────────────────────────────────────┐
│  詢問本集：                                                      │
│  [來賓對開源 AI 模型有什麼看法？                              ]  │
│                           [提問]  [☑ 引用逐字稿]               │
│  ────────────────────────────────────────────────────────────    │
│  答案：來賓認為開源 AI 對安全研究至關重要，                     │
│  指出需要獨立驗證。                                             │
│  來源：「開放模型讓任何人都能檢視權重...」                      │
│  📍 時間戳記：48:22 — [跳至該段]                               │
└──────────────────────────────────────────────────────────────────┘
```

---

## 關鍵互動

### 互動 1：從 URL 到已處理節目
```
使用者貼上 YouTube URL 並點擊「處理節目」
  → URL 驗證：httpx HEAD 請求確認可連線
  → 插入 Episode 列，status='downloading'
  → 啟動 yt-dlp 子程序：
      yt-dlp -x --audio-format mp3 -o /tmp/pb/{episode_id}.mp3 {url}
  → Streamlit 每 3 秒輪詢節目狀態（st.rerun + DB 讀取）
  → 下載完成 → status='transcribing'
  → 啟動 Whisper 子程序：
      whisper /tmp/pb/{id}.mp3 --model base --output_format json
  → 解析 Whisper JSON：full_text + segments 儲存至 transcripts 資料表
  → Status='analyzing'
  → 呼叫 Claude：章節偵測 + 摘要 + 引句 + 行動項目
  → claude_analysis JSON 儲存至 episodes 資料表
  → Status='done'
  → 節目出現在側邊欄節目庫，主區域顯示分析分頁
```

### 互動 2：針對逐字稿問答
```
使用者輸入：「來賓對意識有什麼看法？」
  → 提交問題
  → 檢索含關鍵字的逐字稿片段：意識、意識到、有感知
  → 依關鍵字密度選取前 10 個片段（簡單 TF 比對）
  → 建構 Claude 提示詞：
      「僅使用以下逐字稿摘錄回答問題。
       若答案不在逐字稿中，請說：『本集未討論此主題。』
       問題：{question}
       逐字稿摘錄：{segments_text}」
  → Claude 回傳：answer_text + supporting_quote + timestamp
  → 插入 qa_history 列
  → 顯示含引文區塊和時間戳記連結的答案
  → 「這個答案有幫助嗎？」讚 / 噓（儲存至 qa_history.helpful）
```

### 互動 3：批次佇列處理
```
使用者透過 URL 輸入的「加入佇列」按鈕新增 5 個 URL
  → 5 個節目以 status='pending' 插入
  → 佇列處理器啟動（背景執行緒）：
      while pending_episodes:
          ep = get_next_pending()
          process_episode(ep)  -- 下載 → 轉錄 → 分析
          mark_done(ep)
  → 側邊欄佇列表格每 5 秒透過 Streamlit rerun 更新
  → 全部完成後：
      若已設定 SMTP：發送電子郵件「PodcastBrain：5 個節目已處理」
  → 使用者在節目庫中看到所有 5 個節目含完整分析
```

---

## 實作步驟

1. **專案鷹架**：Streamlit 多頁面版面，SQLAlchemy 模型含 FTS5 虛擬資料表觸發器設定，音訊檔案的暫存資料夾管理。

2. **yt-dlp 下載模組**：`downloader.py` — yt-dlp 的子程序包裝器，含進度列解析、透過 `subprocess.terminate()` 取消支援、中繼資料萃取。

3. **Whisper 轉錄模組**：`transcriber.py` — 呼叫 whisper CLI 的子程序，JSON 輸出解析為片段清單，依音訊時長估算進度。

4. **Claude 分析模組**：`analyzer.py` — 三次獨立 Claude 呼叫：
   （1）章節 JSON，（2）摘要 + 引句 + 行動項目，（3）講者識別。
   每次呼叫含重試邏輯和回應 schema 驗證。

5. **Streamlit UI — 輸入與處理**：URL 輸入表單、檔案上傳、使用 `st.status()` 容器含即時步驟更新的處理狀態顯示。

6. **Streamlit UI — 節目檢視器**：四分頁版面（摘要 / 章節 / 逐字稿 / 問答），使用 `st.progress` 片段的章節時間軸，含時間戳記錨點的逐字稿。

7. **問答引擎**：`qa_engine.py` — 關鍵字為基礎的片段檢索，含「僅引用逐字稿」限制的 Claude 提示詞建構器，答案 + 引句 + 時間戳記的回應解析器。

8. **節目庫、搜尋、匯出**：含 `st.text_input` 的 FTS5 搜尋，節目卡片格狀圖，MD / PDF / SRT / TXT 匯出函式，含狀態表格的批次佇列管理員。

---

## 成功標準

### 功能性
- 1 小時音訊由 Whisper base 模型在 CPU 上 < 8 分鐘轉錄完成
- Claude 為超過 30 分鐘的節目產生 5 個以上章節，時間戳記準確
- 問答模式在 > 80% 的測試案例中從逐字稿正確回答問題
- FTS5 搜尋在 100 個節目中 < 500ms 回傳相關結果
- 匯出產生可在 VLC 播放的有效 SRT 檔案

### 使用者體驗
- 每個階段完成後 3 秒內可見處理狀態更新
- 章節時間軸列可點擊，懸停時顯示章節摘要
- 問答答案在提交問題後 10 秒內出現
- 節目庫側邊欄顯示 200 個以上節目清單，無捲動延遲

### 技術品質
- 音訊檔案在成功儲存資料庫參照後從暫存資料夾清除
- Whisper 和 Claude 呼叫在執行緒中執行，搭配 Streamlit 安全的狀態更新
- FTS5 索引透過 SQLite 觸發器在逐字稿插入 / 更新 / 刪除時保持同步
- 所有 Claude API 呼叫設定 45 秒逾時，以指數退避重試 2 次
- `ANTHROPIC_API_KEY` 從環境變數讀取，絕不硬編碼
- 單元測試：片段時間戳記解析、章節 JSON 驗證、FTS5 查詢建構器
