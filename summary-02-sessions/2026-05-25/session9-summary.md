# Session 9 Summary
日期：2026-05-25

## 主題
Eden Marco《Agentic Coding with Claude Code》(Packt) — 書籍深度解析 + NLM 全章節音頻 Pipeline

---

## 完成事項

### 1. 書籍深度解析文件撰寫
- 深度讀取 8 個章節（Ch01/02/03/04/07/08/09/10）所有範例程式碼
- 撰寫 `agentic-coding-book-深度解析.md`（約 27,000 字，涵蓋 8 章的核心概念、程式碼解析、設計原則）
- 內容涵蓋：MCP 情境工程、FastMCP、Infinite Agentic Loop、Sub-agents、Hooks、Output Styles、Skills、memory/ 系統

### 2. NotebookLM 新 Notebook 建立
- 建立 NLM notebook：「Agentic Coding with Claude Code - Eden Marco 深度解析」
- Notebook ID：`6383a66a-b2c5-4326-becc-4c7f47a72f64`
- 加入整體文件 source（ID: `488d4834-77fe-4659-a425-c1d6f5364cdb`）
- 拆分 8 個章節獨立 source 並全部加入（`nlm-chapters/` 目錄）

### 3. 8 章語音摘要（Audio）生成
- 分章觸發 8 個 audio artifact（每章間隔 60 秒）
- 全部使用 `--language zh_Hant` 繁體中文
- 8/8 全部生成成功，NLM 自動命名極具巧思：
  - Ch01：「別讓冗長 MCP 說明拖垮 AI」
  - Ch02：「指揮 Claude 無限代理軍團」
  - Ch03：「Claude Code 代理指令與安全 Hook」
  - Ch04：「給得越少讓 AI 越聰明」
  - Ch07：「打造AI子代理專家團隊」
  - Ch08：「打造 Claude Code 狀態列與樣式」
  - Ch09：「Claude Code 自主代理技能實戰」
  - Ch10：「用情境工程治好 AI 失憶症」

### 4. 簡報摘要（Slide Deck）+ 影片摘要（Video）觸發
- Slide Deck：「Engineering Claude Code」— ✅ 完成
- Video：「用 Claude Code 進行代理式開發」— ⏳ pending（已觸發，持續生成中）

### 5. 音頻下載（.m4a 格式）
- 下載目錄：`C:/Users/user/Downloads/nlm-agentic-coding/`
- 8 個 .m4a 全部下載完成，總計 290 MB
- 確認是 .m4a 格式（非 .mp3）

### 6. VPS 上傳與播放清單建立
- 上傳至：`/var/www/kindle-audio/agentic-coding/`
- nginx 設定：新增 `/agentic-coding/` 和 `/agentic-coding.m3u` 路由
- 播放清單：`http://187.127.109.145/agentic-coding.m3u`（.m3u 格式，中文檔名 URL encode 正確）
- 所有音頻 HTTP 200 OK，Content-Type: audio/mp4

### 7. Gmail 通知
- 寄送 HTML 格式郵件至 chenghyang2001@gmail.com
- 含播放清單 URL、8 章清單表格、NLM notebook 資訊
- Gmail message ID: `19e5bcbd28361904`

---

## 關鍵技術筆記

### notebooklm CLI 章節音頻生成 SOP
1. 建立章節獨立 markdown source 檔案
2. `notebooklm source add <file> --notebook <id> --json` 取得 source_id
3. `notebooklm generate audio "<title>" --notebook <id> -s <source_id> --language zh_Hant --json` 觸發
4. 每章間隔 60 秒（可行，非必要等 5 分鐘）
5. `notebooklm artifact list --notebook <id> --json` 輪詢狀態
6. `notebooklm download audio --notebook <id> --artifact <id> <OUTPUT_PATH.m4a>` 下載

### NLM Audio 標題行為
- `generate audio` 的 title 參數為觸發用，NLM 會根據內容自動生成更吸引人的標題
- 例：傳入「第一章 MCP情境工程」→ 輸出「別讓冗長 MCP 說明拖垮 AI」

### notebooklm create 指令
```bash
notebooklm create "Notebook Title" --json
```
回傳 `{"notebook": {"id": "...", "title": "..."}}`

### VPS nginx 路由設定（小雲執行）
在 `/etc/nginx/sites-enabled/demo17.conf` 新增：
- `location /agentic-coding.m3u { ... }` — 服務 .m3u 播放清單
- `location /agentic-coding/ { ... }` — 服務 .m4a 目錄

---

## 產出檔案

| 路徑 | 說明 |
|------|------|
| `C:/Users/user/workspace/Agentic-Coding-with-Claude-Code/agentic-coding-book-深度解析.md` | 8章深度解析文件（27,000字）|
| `C:/Users/user/workspace/Agentic-Coding-with-Claude-Code/nlm-chapters/Ch01~Ch10 *.md` | 8個章節獨立 source 檔案 |
| `C:/Users/user/Downloads/nlm-agentic-coding/Ch01~Ch10 *.m4a` | 8個音頻（290 MB）|
| `http://187.127.109.145/agentic-coding.m3u` | VPS 播放清單 |
| `/var/www/kindle-audio/agentic-coding/` | VPS 音頻目錄 |

### NLM Artifacts（Notebook: 6383a66a）
| Artifact ID | 類型 | 標題 | 狀態 |
|-------------|------|------|------|
| 3d2913ca | Audio | 別讓冗長 MCP 說明拖垮 AI | ✅ completed |
| 9867c0df | Audio | 指揮 Claude 無限代理軍團 | ✅ completed |
| 743a43d4 | Audio | Claude Code 代理指令與安全 Hook | ✅ completed |
| 104195c9 | Audio | 給得越少讓 AI 越聰明 | ✅ completed |
| 48d86a77 | Audio | 打造AI子代理專家團隊 | ✅ completed |
| d5408adc | Audio | 打造 Claude Code 狀態列與樣式 | ✅ completed |
| 7778affb | Audio | Claude Code 自主代理技能實戰 | ✅ completed |
| 7b7fcbdc | Audio | 用情境工程治好 AI 失憶症 | ✅ completed |
| 5f303720 | Slide Deck | Engineering Claude Code | ✅ completed |
| a83ddba1 | Video | 用 Claude Code 進行代理式開發 | ⏳ pending |

---

## HANDOFF（下次 session 優先處理）

### 立即行動
- [ ] 確認 Video artifact `a83ddba1` 是否已完成（`notebooklm artifact list --notebook 6383a66a-b2c5-4326-becc-4c7f47a72f64 --json`）
- [ ] **撤銷重發 Anthropic API key** — `sk-ant-api03-enO3cUTonXnigSso_...` 曾出現在 Session 7 log，務必到 console.anthropic.com 撤銷並重新生成；刪除 `~/Downloads/anthropic-api-key.txt`
- [ ] autonomous-coding-sub（Windows 版）0/7 features 問題：考慮換簡單純前端 spec（不需真實 Claude API streaming）驗證 features

### 進行中（需接續）
- NLM Video artifact（a83ddba1）觸發但仍 pending，預計數分鐘後完成
- Agentic-Coding-with-Claude-Code 書籍 GitHub repo（chenghyang2001/Agentic-Coding-with-Claude-Code）有新增 `agentic-coding-book-深度解析.md` 和 `nlm-chapters/` 尚未 commit push

### 注意事項
- 音頻格式是 .m4a（非 .mp3）— 使用者強調多次，務必記住
- VPS 播放清單路徑：`/agentic-coding.m3u`（和 kindle-07.m3u 同層，但目錄是 `/agentic-coding/`）
- NLM notebook `6383a66a` 有 9 個 source（1 整體 + 8 章節）+ 10 個 artifacts
- `notebooklm generate audio` 的 title 參數只是觸發用，NLM 會自己命名更吸引人的標題
