# Session 5 Summary — anthropic-quickstarts 訂閱版雙分支

**日期：** 2026-05-23
**專案：** `anthropic-quickstarts`（`chenghyang2001/anthropic-quickstarts`）
**Session 主題：** 從兩個官方 quickstart（financial-data-analyst / autonomous-coding）分支出**訂閱版 sub**，走 `claude` CLI OAuth 用 Pro/Max 訂閱額度取代 API key + 加完整 verbose tool 可見性 + 寫跨 session 接手文件

---

## 完成事項

### 站別 1：financial-data-analyst-sub（Next.js + Claude Agent SDK）

從 `financial-data-analyst/` cp 出新分支，重寫 `app/api/finance/route.ts`（484 行）走 `@anthropic-ai/claude-agent-sdk` 的 `claude` CLI OAuth。**前端 100% 不動**，回傳 JSON 形狀完全相容。

完整走過 **三 agent 鐵律 writer→QA→reviewer→writer-fix 迴圈**：
- Writer 第一版 432 行（SHA 9408...c3）
- QA：V1-V5 + 3 functional test cases 全 PASS（pie chart / bar chart / 多輪對話）
- Reviewer 提出 3 個 MUST_FIX + 4 個 NICE_TO_HAVE + 4 個 ARCHITECTURE_CONCERNS
- Writer 修正版 484 行（SHA 4abc...8b），解決：
  1. `delete process.env.ANTHROPIC_API_KEY` process-wide 污染 → 改用 SDK options.env request-scoped 隔離
  2. 缺 input validation → 加 zod `RequestSchema` 白名單（model + role）
  3. catch leak raw error.message → 分類錯誤碼（CLI_NOT_FOUND / OAUTH_EXPIRED / INTERNAL_ERROR）

最終驗證 5 + 1 全綠：3 functional test + 2 zod validation test + 1 browser E2E（Puppeteer 開 localhost:3001/finance + 送 Q1-Q4 revenue 查詢 + 截圖確認 chart 渲染）。**訂閱模式 OAuth 走通確認**，console.anthropic.com Credits 沒動。

關鍵 SDK 技術點：用 `tool()` + `createSdkMcpServer()` 把原版 `generate_graph_data` tool 的 `input_schema` 平移成 SDK MCP tool；handler 用 closure 變數 `capturedChartData` 擷取 args（不能 hoist 到模組頂層否則 race）；`tools: []` 移除所有 built-in tools；前端 toolUse.name 仍對外用 `generate_graph_data` 維持契約。

### 站別 2：autonomous-coding-sub（Python harness + bash CLI）

從 `autonomous-coding/` cp 出新分支。**核心發現**：本來就有 bash 版 `autonomous_cli_loop.sh`（Session 2 衍生品）已走 OAuth，但 bash 版捨棄 Python harness 的 sandbox / security hook / MCP 配置 → 做完整 Python sub 補完功能。

改 2 個 Python 檔（writer + QA，簡單複雜度不派 reviewer）：
- `autonomous_agent_demo.py:80-85`：移除 `ANTHROPIC_API_KEY` hard-check，改 `os.environ.pop` 主動清掉 env（即使 user shell 有設）強制 SDK 走 OAuth
- `client.py:57-62`：移除 `raise ValueError`，順手清掉 unused `import os`

驗證（max-iter 1 演練 5 features）：`[Subscription mode]` 啟動訊息 + initializer 完整跑完 + feature_list.json + init.sh + Vite scaffold + git commit `2101fbe Initial setup`。**但發現 Windows Python SDK 「Stream closed」議題** — 長任務（max-iter 6）容易卡死，原因是 stdin/stdout protocol 在 Windows 不穩。

### 站別 2 衍生：bash verbose tool 可見性

`autonomous_cli_loop.sh` 預設 `claude -p` 只印最終 message，看不到中間 tool 呼叫。完整加上 verbose 模式：

- 新建 `scripts/parse_claude_stream.py`（107 行）：讀 stdin JSONL → 印 `[Tool: name] {input}` / `[OK/ERR] result` / `> text` / `=== DONE [success] (cost: $X, turns: N) ===`；unicode-safe（`ensure_ascii=False`）+ 非 JSON 行 fallback 原樣印 + `flush=True` stream-friendly
- 改 `autonomous_cli_loop.sh` 兩處 `claude -p` 加 `--output-format stream-json --verbose` + pipe 到 parser
- 加 `*.log` `*_run.log` 到 .gitignore

**踩到 Git Bash 路徑 bug**：`$SCRIPT_DIR = /c/Users/...` 餵 Windows 原生 Python 變成 `C:\c\Users\...`（多餘 `\c\`）。修法用 `cygpath -w "$SCRIPT_DIR/scripts/parse_claude_stream.py"` 轉成 Windows 風格路徑（3 行小修豁免）。

### 5 features full run 實跑（v3 verbose）

`./autonomous_cli_loop.sh five_demo_v3 5` 跑了 1 initializer + 3 coding sessions，stall detection 在第 4 圈正確 abort（連續 3 圈剩餘數沒下降）。總成本 ~$3.69 USD 等價（全走訂閱配額不扣 API Credits）。

**但 0/8 features 通過**。根因（log 結尾）：
```
[Tool: mcp__chrome-devtools__new_page] {"url": "http://localhost:5173"}
   [ERR] Claude requested permissions to use mcp__chrome-devtools__new_page, but you have...
```

bash 腳本的 `.claude/settings.json` permissions.allow **沒包 MCP browser tools** → agent 想驗 UI 被擋 → 改不動 feature_list.json → stall abort。對照 Python `client.py` 的 `PUPPETEER_TOOLS` 清單發現 bash 版完全缺這層配置。

### 父 repo contamination 處理

bash 演練時 agent 在 `generations/five_demo_bash/` 工作，但該目錄沒自己的 `.git`，agent `git add/commit` 往上找命中**父 repo** 的 .git → 留下 `feeb1e3 實作核心聊天功能：完整的前後端整合` commit 把 parser/bash 改動 + 3 個 log 都包進去，但 commit message 是 agent 自以為在 commit 它的 chat App 工作。

處理：`git reset --soft HEAD~1` 收回 → 重新 untrack logs（加 .gitignore 後 `git rm --cached`）→ 重新單一 commit 含正確訊息 `fccbabb`。

### 站別 3：跨 session 接手文件（4 個檔）

為兩個 sub 各寫一對：
- `CLAUDE.md`（給 Claude Code 開該目錄當專案根時的簡報 — 差異對照、技術點、已知議題、必設環境、檔案地圖）
- `doc/session-handoff.md`（5/23 完整工作紀錄 — Phase 分段、已驗證項目、未解問題、下次接手步驟、成本）

讓未來任何 Claude session 開 sub 目錄都能立即上手，不需要往父 repo 翻歷史。每個檔尾都 cross-reference 到姐妹專案。

---

## 關鍵技術筆記

### 訂閱模式 vs API 模式：兩個 sub 的命名 pattern

| 面向 | financial-data-analyst-sub | autonomous-coding-sub |
|---|---|---|
| 語言層 | TypeScript（Next.js 14）| Python + bash |
| SDK | `@anthropic-ai/claude-agent-sdk@^0.3` | `claude-code-sdk@^0.0.25`（Python）/ 直接呼 `claude` CLI（bash）|
| Runtime | Node.js（非 Edge）| Python / Git Bash |
| Port | 3001 | N/A |
| 啟動延遲 | 25-30s warm-up | 每 session 25-30s |
| 部署 | Self-host only（無 Vercel）| Self-host only |
| 驗證範圍 | 5 + 1 PASS（完整通過）| 1 PASS / 0-of-N coding（MCP 缺）|

### Reviewer 3 個 MUST_FIX 通用價值

financial-data-analyst-sub 走的 Reviewer 提出的修法都是 **訂閱版的通用 pattern**：

1. **`env` request-scoped 隔離**（不是 `delete process.env`）—— 並發 / 多 route 安全
2. **zod input validation 白名單**（不只防錯，防 prompt injection 攻擊面 — `role: "system"`）
3. **錯誤分類碼**（CLI_NOT_FOUND / OAUTH_EXPIRED / INTERNAL_ERROR）—— 前端可讀且不洩漏 CLI 路徑

未來任何「訂閱版包裝既有 API 程式」都該照這 3 個 pattern 做。

### bash 版的兩個結構性缺陷

1. **缺 MCP server allow list**（最高優先未解問題）：Python `client.py` 預配了 `PUPPETEER_TOOLS` + `mcp_servers: {puppeteer: ...}`，bash 版完全沒有。導致 agent 無法用 browser MCP 做 UI 驗證
2. **agent git 越界**：bash 版沒有限制 agent 的 git 操作邊界，agent 在 `generations/<project>/` 沒 .git 的環境下 `git commit` 會命中父 repo

### Git Bash 路徑跨 Windows Python 必踩坑

`$SCRIPT_DIR = /c/Users/...`（MSYS2 風格）餵 Windows 原生 Python 變 `C:\c\Users\...`。**修法**：`cygpath -w` 轉成 Windows 風格。CLAUDE.md `tool-commands.md` 提過 schtasks / rclone 也是同類議題。

### 父 repo contamination 防禦

agent 在 sub 專案內工作但若 sub 沒 `.git`，git 操作會冒泡命中外層 repo。**防禦**：sub 腳本應該確保 `git init` 比 agent 啟動更早。Python harness 沒做這層；bash 版也沒做。可以在 `autonomous_cli_loop.sh` 加 `cd "$PROJECT_DIR" && [ ! -d .git ] && git init` 在啟動 claude 之前。

---

## 產出檔案

| 檔案 | 類型 | 說明 |
|---|---|---|
| `financial-data-analyst-sub/` | 新目錄 | Next.js 訂閱版 sub（完整功能，已驗證）|
| `financial-data-analyst-sub/app/api/finance/route.ts` | 重寫 | 484 行 SDK + zod + error 分類 |
| `financial-data-analyst-sub/package.json` | 改 | name -sub / port 3001 / SDK 換 / zod v4 |
| `financial-data-analyst-sub/.env.local.example` | 新增 | 訂閱版說明（不需 API key）|
| `financial-data-analyst-sub/CLAUDE.md` | 新增 | 給 Claude Code 開目錄的簡報 |
| `financial-data-analyst-sub/doc/subscription-version-notes.md` | 新增 | 完整架構筆記 |
| `financial-data-analyst-sub/doc/session-handoff.md` | 新增 | 5/23 完整工作紀錄 |
| `financial-data-analyst-sub/doc/smoke-test-screenshot.png` | 新增 | Browser E2E 截圖證據 |
| `autonomous-coding-sub/` | 新目錄 | Python harness 訂閱版 sub |
| `autonomous-coding-sub/autonomous_agent_demo.py` | 改 | 移 API key check 改 `os.environ.pop` |
| `autonomous-coding-sub/client.py` | 改 | 移 ValueError + 清 unused import |
| `autonomous-coding-sub/autonomous_cli_loop.sh` | 改 | 加 stream-json verbose + cygpath fix |
| `autonomous-coding-sub/scripts/parse_claude_stream.py` | 新增 | 107 行 stream-json parser |
| `autonomous-coding-sub/.gitignore` | 改 | 加 `*.log` `*_run.log` |
| `autonomous-coding-sub/CLAUDE.md` | 新增 | 給 Claude Code 開目錄的簡報 |
| `autonomous-coding-sub/doc/subscription-version-notes.md` | 新增 | 完整架構筆記 |
| `autonomous-coding-sub/doc/session-handoff.md` | 新增 | 5/23 完整工作紀錄 |

**本 Session commit：** 4 個 push 到 main —
- `151d0ff` 新增 financial-data-analyst-sub：訂閱版分支
- `a8133f3` 新增 autonomous-coding-sub：訂閱版分支
- `fccbabb` 新增 autonomous-coding-sub verbose 模式 + parser
- `c95983e` 新增 sub 專案 CLAUDE.md + session-handoff 給未來接手

額外 amend：收回 agent 誤 commit 的 `feeb1e3`（soft reset HEAD~1，重整成 `fccbabb`）

---

## HANDOFF（下次 session 優先處理）

### 立即行動

- [ ] **修 `autonomous-coding-sub/autonomous_cli_loop.sh` 的 MCP allowlist**：把 Python `client.py:19-27` 的 `PUPPETEER_TOOLS` 7 個 `mcp__puppeteer__*` 工具加進 bash 寫的 `.claude/settings.json` permissions.allow，並考慮在 bash 啟動前 spawn `npx puppeteer-mcp-server`。預計可解 0/N features 通過率問題
- [ ] **撤銷重發 Anthropic API key**：跨 Session 3、4、5 演練紀錄都有 API key 出現，務必到 console.anthropic.com 撤銷重發
- [ ] 跑修復後的 bash 版 5-features full run 驗證 features 通過率有沒有突破

### 進行中（需接續）

- 兩個 sub 都已可 production-use（訂閱 OAuth 確認走通），但都有 POC 限制：
  - `financial-data-analyst-sub/` 圖片上傳關閉 + 多輪對話結構降級
  - `autonomous-coding-sub/` Python 版長任務 Windows SDK 不穩 / bash 版 MCP allowlist 缺
- 6 站演練計畫：1-2-3-4 完成（agents / financial / customer-support / autonomous-coding），加上 5/23 兩個訂閱版 sub
- 剩 computer-use-demo / browser-use-demo 兩站需 Docker；computer-use-best-practices 是 macOS 專屬無法演練

### 注意事項

- **訂閱版鐵律**：跑 sub 任何腳本前確認 `ANTHROPIC_API_KEY` 不在 shell 環境（Python 版會 pop 但 shell 殘留會混淆其他工具）；Python sub 必設 `DISABLE_WRITER_QA_HOOK=1`
- **父 repo contamination 風險**：agent 在 sub 內跑長任務時若 sub 沒先 `git init`，agent 的 `git commit` 會冒泡到父 repo。Session 5 已踩過一次（`feeb1e3`），下次跑長任務前先確認 sub 有自己的 .git
- **Git Bash + Windows Python 路徑**：任何要在 bash 腳本內把路徑餵給 Windows native Python 都要用 `cygpath -w` 轉，否則 `/c/Users/...` 會變 `C:\c\Users\...`
- **訂閱用量提醒**：autonomous-coding-sub 跑 5-features full 約 USD $3.69 等價（單次）。Pro 5h/週、Max 25h/週用量上限要留意，不要連續猛測試
- **agent 自由發揮 feature 數量**：initializer prompt 寫「Minimum 5」agent 看 Claude.ai clone 大 spec 會自己生 8 或 12 個。要 hard limit 需改 prompt 為「Exactly N」
- **未 commit 的 `five_demo_*_run.log`**：留在 working tree 已 gitignored 不影響 repo；要清磁碟空間可 `rm -rf generations/*` 連帶清掉
