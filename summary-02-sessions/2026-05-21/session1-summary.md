# Session 1 Summary — anthropic-quickstarts 演練啟動

**日期：** 2026-05-21
**專案：** `C:/Users/user/workspace/anthropic-quickstarts`
**Session 主題：** 盤點所有 quickstart 專案、規劃演練順序、安裝 agents 環境

---

## 完成事項

- **盤點 7 個 quickstart 專案**：`agents` / `financial-data-analyst` / `customer-support-agent` / `autonomous-coding` / `computer-use-demo` / `browser-use-demo` / `computer-use-best-practices`，依難度排序並以繁體中文表格呈現
- **深度分析 `agents` 專案原始碼**：讀完 `agent.py`、所有 `tools/`（ThinkTool / FileReadTool / FileWriteTool / WebSearchServerTool / CodeExecutionServerTool）、`utils/`（MessageHistory / tool_util / connections），掌握 while 迴圈核心架構
- **安裝 agents 環境**：在 Python 3.14.3 環境下成功安裝 `anthropic==0.103.1` 與 `mcp`
- **建立演練參考文件**：`doc/quickstarts-演練計畫.md`，含難度表格、架構圖解、三關演練程式碼（practice_01 / 02 / 03）、關鍵程式碼理解清單

---

## 關鍵技術筆記

### agents 核心架構

```
Agent._agent_loop() while 迴圈：
  1. 加訊息進 MessageHistory
  2. 呼叫 Claude API（帶 tools 定義）
  3. 有 tool_use？ YES → execute_tools()（asyncio.gather 平行）→ 加結果回 history → 繼續
                   NO  → 回傳最終答案，結束
  4. MessageHistory.truncate() 自動截斷超出 context window 的舊訊息
```

### 工具兩大類

| 類型 | 工具 |
|---|---|
| 本地（Python 直接執行）| ThinkTool / FileReadTool / FileWriteTool |
| Anthropic Server 工具 | WebSearchServerTool（`web_search_20250305`）/ CodeExecutionServerTool（`code_execution_20250522`）|
| MCP 工具（外部 Process）| calculator_mcp.py |

### MessageHistory 重點

- `truncate()`：超出 `context_window_tokens`（預設 180,000）時從最舊訊息對刪
- `format_for_api()`：最後一條訊息加 `cache_control: ephemeral`，實現 prompt caching
- token 計數：用 `client.messages.count_tokens()` 算 system prompt 的 token

### 關鍵 API header

`anthropic-beta: code-execution-2025-05-22` — 每次 API 呼叫都加，啟用 code execution beta

---

## 產出檔案

| 檔案 | 類型 | 說明 |
|---|---|---|
| `doc/quickstarts-演練計畫.md` | 新增 | 完整演練計畫：難度表格 + agents 架構圖 + 三關程式碼 |

---

## HANDOFF（下次 session 優先處理）

### 立即行動
- [ ] 設定 `ANTHROPIC_API_KEY`（臨時 `$env:ANTHROPIC_API_KEY=...`，不用 setx），然後執行第一關演練：`PYTHONUTF8=1 python doc/practice_01_think.py`
- [ ] 依序完成三關演練（ThinkTool → FileTools → Server Tools），記錄每關 verbose 輸出的理解
- [ ] 演練完後接續下一站：`financial-data-analyst`（需 Node.js 18+ + `npm install`）

### 進行中（需接續）
- `agents` 演練計畫已完整規劃，三關程式碼都寫在 `doc/quickstarts-演練計畫.md`；**尚未實際執行**，等下次 session 設好 API key 後開始跑
- 三關演練程式碼也需存成獨立 `.py` 檔（`doc/practice_01_think.py` / `practice_02_files.py` / `practice_03_server_tools.py`）

### 注意事項
- `agents` 專案直接呼叫 Anthropic API → 消耗 API Credits（非 Max 訂閱），建議第一、二關用 `claude-haiku-4-5-20251001` 降低費用
- `ANTHROPIC_API_KEY` 只能臨時設定（PowerShell: `$env:...`），**不要用 `setx` 永久設定**（會讓所有 `claude -p` 也走 API key）
- Python 版本是 3.14.3，套件已安裝：`anthropic==0.103.1` + `mcp`
- 演練參考文件路徑：`C:/Users/user/workspace/anthropic-quickstarts/doc/quickstarts-演練計畫.md`
