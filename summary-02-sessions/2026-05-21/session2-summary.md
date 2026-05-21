# Session 2 Summary — anthropic-quickstarts 四站演練 + CLI 自主編碼腳本

**日期：** 2026-05-21
**專案：** `anthropic-quickstarts`（`chenghyang2001/anthropic-quickstarts`）
**Session 主題：** 接續 Session 1 的演練計畫，實跑 4 個 quickstart 站別，並衍生出 CLI 版自主編碼迴圈腳本

---

## 完成事項

### 站別 1：agents（演練 + 框架修復）

- 把 Session 1 規劃的三關演練程式碼存成獨立檔：`doc/practice_01_think.py`（ThinkTool）、`practice_02_files.py`（FileRead/Write）、`practice_03_server_tools.py`（WebSearch + CodeExecution Server 工具）
- 三檔走完整 code-writer → code-qa → code-reviewer 三 agent 鐵律流程，APPROVED
- **修復 `agents` 框架真實 circular import bug**：`agents/utils/connections.py` 與 `agents/tools/mcp_tool.py` 互相 import 導致 `import agents.agent` 直接 `ImportError`。修法：把 `mcp_tool.py` 的 `from ..utils.connections import MCPConnection` 移進 `if TYPE_CHECKING:` 區塊（該名稱僅用於字串型別標註，執行期不需要）
- 三關演練全部實跑成功：關 1 模型判斷不需工具直接答、關 2 跑 3 圈 agent loop（file_read→file_write→回答）、關 3 用 Server 工具（網路搜尋對本地 verbose loop 隱形）

### 站別 2：financial-data-analyst（停用模型修復）

- `npm install`（472 套件）後啟動 dev server，發現查詢回錯誤
- dev server log 確認根因：預設模型 `claude-3-5-sonnet-20240620` 已被 Anthropic 停用，API 回 `404 not_found_error`
- 修 `app/finance/page.tsx`：`models` 清單兩個停用模型（`claude-3-haiku-20240307`、`claude-3-5-sonnet-20240620`）換成 `claude-haiku-4-5-20251001` + `claude-sonnet-4-6`，預設改 Haiku 4.5。走 writer→QA 二 agent 流程
- 修復後使用者瀏覽器驗證：長條圖正常生成（route.ts 用 tool use 的 input_schema 鎖死圖表 JSON）

### 站別 3：autonomous-coding（架構演練 + 最小實跑）

- 深度拆解架構：雙角色 pattern（initializer/coding）、跨 session 狀態外部化（feature_list.json + git）、3 層防禦縱深安全模型
- 調整 `prompts/initializer_prompt.md`：feature 數 200→5、「10+ 步驟測試」要求 25→1，供最小成本演練
- `pip install claude-code-sdk`（0.0.25 安裝成功）
- 第 1 次跑：初始化 agent 寫 `init.sh` 時被「主機全域 `~/.claude/` 的程式碼三 agent 鐵律 hook」攔截而卡死（agent 進入互動式歧路問「你同意嗎？」）
- 第 2 次跑（`DISABLE_WRITER_QA_HOOK=1`）：初始化完整成功，agent 還超出範圍裝完 611 npm 套件、把 `better-sqlite3` 原生編譯失敗自主換成 `sql.js`、跑起後端 server、6 次 git commit

### 站別 4：customer-support-agent（純 Claude 模式演練）

- 評估確認 Bedrock RAG 非硬性需求（`route.ts` 的 `retrieveContext()` 包 try/catch，無 AWS 憑證即優雅降級），可跳過整套 AWS
- `npm install`（package-lock 正規化少 31 行）後用 bash 直接跑 `next dev`（繞過 npm script 的 Unix 環境變數語法在 Windows cmd 掛掉的問題），dev server 落在 port 3002
- Puppeteer 驗證：送帶情緒的客服查詢，`prefill-{` 結構化輸出每個欄位都到位（response/thinking/user_mood=Frustrated/matched_categories=Technical+Account/suggested_questions/context_used=false）

### 衍生產出：autonomous_cli_loop.sh

- 應使用者要求，把 `autonomous_agent_demo.py`（Python+SDK）改寫成「bash 迴圈 + `claude` CLI」版本：`autonomous-coding/autonomous_cli_loop.sh`
- 兩輪三 agent 流程：初版 → reviewer 提 3 個 must-fix（prompt 走 stdin 避開 Git Bash 32KB 參數上限、`claude` 非零退出要有診斷訊息、`Bash(git:*)` 白名單收窄）→ 修正 → APPROVED
- 再補 3 個 nice-to-have（writer→QA）：stall detection（連續無進度提前止血）、`SLEEP_INTERVAL` 環境變數、DRY-RUN 訊息修飾

### 衍生產出 2：project-演練 skill（首次收工後追加）

- 應使用者要求，把本 session「演練專案」的可重複流程沉澱成新 skill `project-演練`
- 8 步驟工作流：探索 → 評估環境 → 裝依賴 → 設定 .env → 啟動 → Puppeteer/測試驗證 → 偵測並修常見 bug → 回報
- `references/common-bugs.md` 萃取本 session 4 站演練踩到的 rot bug（停用模型、跨平台 npm script、circular import、stale lockfile、硬編碼路徑）
- `references/project-types.md` 收錄 Next.js / Python CLI / Docker / Agent SDK 四類型的偵測+安裝+執行+驗證做法
- 全 `.md` 檔，已 commit 至 `~/.claude` repo（`0f2a2fd`）

---

## 關鍵技術筆記

### 結構化輸出三技法（跨三站對照）

| 站 | 技法 |
|---|------|
| agents | tool use 在迴圈中（通用工具呼叫） |
| financial-data-analyst | tool use + 嚴格 `input_schema`（用工具 schema 鎖死輸出 JSON） |
| customer-support-agent | assistant 訊息預填 `{` 強迫 JSON 開頭 + Zod 驗證 |

### 巢狀 Claude Code 繼承父環境 hook

SDK / CLI spawn 出的 Claude Code 子行程**會繼承使用者全域 `~/.claude/` 設定**（含 hook、含 `.env` 權限 deny 規則）。為「互動式」設計的 hook（如三 agent 鐵律，預期人類確認）放到「自主 agent」環境會讓它癱瘓。對策：spawn 前置 `DISABLE_WRITER_QA_HOOK=1`。延伸規律：擋自主 agent 的錯誤訊息應給「替代路徑」而非「找人類」。

### Windows 跨平台坑

- npm script 用 Unix 風格 `VAR=value cmd` 前綴在 Windows cmd.exe 掛掉 → 改用 bash 直接跑底層指令（正規修法 `cross-env`）
- Git Bash（MSYS2）命令列長度上限約 32KB，遠低於 Linux → 長 prompt 改走 stdin
- OS 沙箱（autonomous-coding 安全模型第 1 層）在 Windows 自動停用，僅 macOS/Linux/WSL2 支援

### 成本：CLI vs SDK

`autonomous_agent_demo.py`（SDK）強制要 `ANTHROPIC_API_KEY` → 扣 API Credits。`claude` CLI 不設此環境變數時走 OAuth/Max 訂閱 → 零 API 費用。`autonomous_cli_loop.sh` 即此 cost-rules 合規版。

---

## 產出檔案

| 檔案 | 類型 | 說明 |
|---|---|---|
| `doc/practice_01_think.py` | 新增 | 第一關演練（ThinkTool） |
| `doc/practice_02_files.py` | 新增 | 第二關演練（FileRead/Write） |
| `doc/practice_03_server_tools.py` | 新增 | 第三關演練（Server 工具） |
| `agents/tools/mcp_tool.py` | 修改 | 修 circular import（TYPE_CHECKING guard） |
| `.gitignore` | 新增 | root 層級，補 `__pycache__/` 等排除 |
| `financial-data-analyst/app/finance/page.tsx` | 修改 | 換掉停用模型 |
| `customer-support-agent/package-lock.json` | 修改 | npm install 正規化 |
| `autonomous-coding/prompts/initializer_prompt.md` | 修改 | feature 數 200→5（演練設定） |
| `autonomous-coding/autonomous_cli_loop.sh` | 新增 | CLI 版自主編碼迴圈（取代 SDK） |
| `~/.claude/skills/project-演練/SKILL.md` | 新增 | 專案演練自動化 skill 主流程 |
| `~/.claude/skills/project-演練/references/common-bugs.md` | 新增 | 常見 rot bug 偵測+修復目錄 |
| `~/.claude/skills/project-演練/references/project-types.md` | 新增 | 各專案類型執行+驗證做法 |

**本 Session commit：** 專案 repo 7 個 — `d7b1929`（agents 演練+框架修復）、`0b9dc91`（financial 模型修復）、`9ebbd0b`（initializer prompt 演練設定）、`4f9a2b6`（package-lock 正規化）、`46f2501`（autonomous_cli_loop.sh 新增）、`a1fd1f9`（cli_loop 3 項改進）、`22616f6`（Session 2 summary）；`~/.claude` repo — `4d19688`（收工同步）、`0f2a2fd`（project-演練 skill）

---

## HANDOFF（下次 session 優先處理）

### 立即行動

- [ ] **撤銷重發 Anthropic API key** —— 本 session 演練時 API key 完整出現在對話紀錄中，務必到 console.anthropic.com 撤銷該把 key 並重新發行
- [ ] 若要演練剩餘 3 站（computer-use-demo / browser-use-demo），需先安裝 Docker Desktop（WSL2 backend）；computer-use-best-practices 為 macOS 專屬，此 Windows 機無法演練
- [ ] 殘留行程清理：本 session 收工時已關閉 port 3000/3001/3002 的 3 個 dev server（若仍有殘留 node 行程可再檢查）

### 進行中（需接續）

- 7 站演練計畫已完成 4 站（agents / financial-data-analyst / autonomous-coding / customer-support-agent）。剩 computer-use-demo、browser-use-demo、computer-use-best-practices 三站，全部需 Docker 或 macOS，尚未演練
- 演練計畫總表在 `doc/quickstarts-演練計畫.md`（Session 1 建立）

### 注意事項

- 演練產物 `autonomous-coding/generations/demo`、`demo2`、`cli_demo`、`qatest*` 等已被 gitignore，不影響 repo；要清磁碟空間可 `rm -rf autonomous-coding/generations/`（注意：`generations/demo` 曾因 log handle 占用刪不掉，需先確認無殘留行程）
- `autonomous-coding/prompts/initializer_prompt.md` 目前是「5 features」演練設定，非原始的 200 —— 若要正式跑需自行改回
- 各站 `.env.local`（含 API key）由使用者手動建立、已被 gitignore；助理因 `.env` 權限保護無法直接寫
- `customer-support-agent` 與 `financial-data-analyst` 的 dev server npm script 在 Windows 需注意跨平台問題（見關鍵技術筆記）
