# Autonomous Coding Agent — Codebase 深度技術報告

> 文件版本：2026-05-22
> 對象專案：`anthropic-quickstarts/autonomous-coding`
> 適用讀者：熟悉 Python 與一般軟體工程、但**第一次接觸這個 codebase**、需要在最短時間內建立完整心智模型的資深工程師。
> 用途：本文件設計為自我完備（self-contained）的技術簡報，可直接作為知識來源餵給 NotebookLM 生成語音 / 影片 / 簡報摘要。

---

## 0. 一分鐘速覽（TL;DR）

`autonomous-coding` 是 Anthropic 官方 quickstarts 之一，示範如何用 **Claude Agent SDK** 打造一個「**長時程自主編碼**」的驅動框架（harness）。

它本身**不是**一個會寫程式的 AI——真正會寫程式的是 Claude Agent SDK。這個 repo 是**包在 SDK 外面的那層外殼**：負責開 session、餵 prompt、跑無限迴圈、保存進度、控管安全邊界。可以把它想成「套在馬身上、讓你能駕馭牠長跑數小時的挽具（harness）」。

核心問題與解法：

- **問題**：一個 LLM 的 context window 塞不下「從零打造一個完整應用程式」的全部工作量。
- **解法**：把工作拆成多個獨立 session 接力完成。每個 session 都是**全新的 context window**，彼此之間靠**檔案系統與 git** 交接進度，而不是靠對話記憶。

整個程式只有 6 個 Python 檔、約 600 行，但完整體現了 long-running agent 的三大支柱：**雙 Agent 模式**、**無狀態 session 接力**、**縱深防禦安全模型**。

---

## 1. 它要解決什麼問題

傳統「一次性」呼叫 LLM 寫程式的天花板很明顯：

1. **Context window 有限**：一個大型應用（前端、後端、資料庫、數十個 API endpoint）的規格 + 程式碼 + 測試，遠超單一 context 能承載的量。
2. **單次對話會「失憶」**：對話一旦結束，所有上下文就消失。
3. **長對話會劣化**：context 愈長，模型注意力愈分散，品質下降。

這個 harness 的回答是：**不要試圖在一個 context 裡做完所有事**。改成——

- 把「要做什麼」固化成**外部檔案**（`feature_list.json`），成為唯一事實來源（single source of truth）。
- 每個 session 只做「一件事」（初始化，或實作一個功能），做完就把進度寫回檔案 + git commit。
- 下一個 session 用**全新 context** 啟動，先讀檔案「搞清楚現在在哪」，再繼續。

結論：**狀態不存在於模型的記憶裡，而存在於檔案系統與 git 裡。** 這是整個設計的靈魂。

---

## 2. 核心概念：雙 Agent 模式（Two-Agent Pattern）

系統用**同一支程式**、依專案狀態扮演兩種不同角色的 agent。判斷依據只有一個：專案目錄裡 `feature_list.json` 是否存在。

### 2.1 初始化 Agent（Initializer Agent）— 只在第一個 session 出現

**任務**（定義於 `prompts/initializer_prompt.md`）：

1. 讀取 `app_spec.txt`（應用程式完整規格）。
2. **建立 `feature_list.json`**：把規格拆解成一條條可端對端測試的「功能項」，每項含 `category`（functional / style）、`description`、`steps`、`passes: false`。這個檔案是後續所有 session 的唯一事實來源。
3. 建立 `init.sh`（環境設定腳本，供後續 session 快速把開發環境跑起來）。
4. `git init` 並做第一個 commit。
5. 搭建基本專案結構（前端 / 後端目錄等）。
6. 若還有餘裕，可開始實作最高優先的功能。

> **重要實況校正**：`initializer_prompt.md` 目前實際要求的是「**5 個** detailed end-to-end test cases」（最少 5 項）。但 `README.md` 與 `autonomous_agent_demo.py` 的註解、以及 `coding_prompt.md` 仍寫「**200** features」。這代表 prompt 已被人為調小（README 的「Adjusting Feature Count」章節正是教你怎麼調）。閱讀此 codebase 時要意識到這個**文件與 prompt 不一致**的現況——以 `initializer_prompt.md` 的實際內容為準。

### 2.2 編碼 Agent（Coding Agent）— 第二個 session 起，不斷重複

**任務**（定義於 `prompts/coding_prompt.md`，共 10 個步驟）：

1. **搞清楚現況**（強制）：`pwd`、`ls`、讀 `app_spec.txt`、讀 `feature_list.json`、讀 `claude-progress.txt`、看 `git log`、數還有幾項 `passes: false`。
2. 啟動伺服器（若 `init.sh` 存在就跑它）。
3. **回歸驗證**（關鍵）：上一個 session 可能引入 bug，所以動新工作前，必須先測 1～2 個已標 `passes: true` 的核心功能還能不能動。若壞了，先把它改回 `passes: false` 並修好。
4. 挑一個優先度最高、`passes: false` 的功能。
5. 實作該功能。
6. 用瀏覽器自動化（Puppeteer）真實驗證 UI（不准只用 curl，不准用 JS evaluate 抄捷徑）。
7. **只能把 `passes: false` 改成 `true`**——絕不可刪除、編輯、合併、重排測試項。
8. `git commit`（描述性訊息）。
9. 更新 `claude-progress.txt`。
10. 乾淨收尾，留下可運作的狀態。

**雙 Agent 模式的鐵律**（寫在 `initializer_prompt.md`）：

> 「在未來的 session 移除或編輯功能項是災難性的。功能項**只能**被標記為通過（`false` → `true`）。永遠不要移除功能、不要改描述、不要改測試步驟。」

這條鐵律確保了：不論跑幾百個 session、context 重置幾百次，**沒有任何功能會被悄悄遺漏**。`feature_list.json` 像一份不可竄改的合約。

---

## 3. 檔案逐一深入（Module-by-Module）

整個 codebase 的 Python 程式碼：

| 檔案 | 行數量級 | 角色 |
|------|---------|------|
| `autonomous_agent_demo.py` | ~120 | 進入點：參數解析、前置檢查、啟動 |
| `agent.py` | ~210 | 核心：主迴圈 + 單一 session 執行 |
| `client.py` | ~125 | Claude Agent SDK 客戶端的建構與安全設定 |
| `security.py` | ~360 | Bash 指令白名單驗證 hook |
| `progress.py` | ~60 | 進度計算與顯示 |
| `prompts.py` | ~40 | 提示詞模板載入 |

外加非程式碼資產：`prompts/app_spec.txt`（要打造的應用規格）、`prompts/initializer_prompt.md`、`prompts/coding_prompt.md`、`requirements.txt`（唯一相依：`claude-code-sdk>=0.0.25`）。

### 3.1 `autonomous_agent_demo.py` — 進入點

職責：

- `parse_args()`：解析三個命令列參數——`--project-dir`（專案目錄，預設 `./autonomous_demo_project`）、`--max-iterations`（最大迭代數，預設 None＝無限）、`--model`（預設常數 `DEFAULT_MODEL = "claude-sonnet-4-5-20250929"`）。
- `main()`：
  1. 檢查環境變數 `ANTHROPIC_API_KEY`，沒設就印錯誤並結束。
  2. **路徑正規化**：若 `--project-dir` 是相對路徑，自動在前面加上 `generations/`，把所有產出的專案統一收納在 `generations/` 底下（沙箱化的延伸——產物與 harness 程式碼分離）。
  3. 用 `asyncio.run()` 啟動 `agent.run_autonomous_agent()`。
  4. 攔截 `KeyboardInterrupt`（Ctrl+C）→ 提示「重跑同指令即可續做」；攔截其他例外 → 印出後重新拋出。

設計重點：進入點很薄，只做「檢查 + 正規化 + 委派」，真正的邏輯在 `agent.py`。

### 3.2 `agent.py` — 核心迴圈

這是整個系統的心臟，含兩個函式與一個常數 `AUTO_CONTINUE_DELAY_SECONDS = 3`。

#### `run_autonomous_agent(project_dir, model, max_iterations)`

1. 建立專案目錄。
2. **判斷首次 vs 續做**：`tests_file = project_dir / "feature_list.json"`；`is_first_run = not tests_file.exists()`。這一行就是雙 Agent 模式的分流開關。
3. 首次 → 印出「第一個 session 要 10–20 分鐘」的警告，並把 `app_spec.txt` 複製進專案目錄。續做 → 印出目前進度。
4. **進入 `while True` 主迴圈**：
   - `iteration += 1`；若超過 `max_iterations` 就 `break`。
   - 印 session 標題。
   - `create_client(project_dir, model)`：**每一輪都建立全新的 client**——這就是「全新 context window」的實作方式。
   - 選 prompt：`is_first_run` → initializer prompt（用完立刻把旗標設 False，確保 initializer 只跑一次）；否則 → coding prompt。
   - 用 `async with client:` 包住，呼叫 `run_agent_session()`。
   - 依回傳狀態處理：`continue` → 印進度、睡 3 秒；`error` → 印錯誤、睡 3 秒後用新 session 重試。
5. 迴圈結束 → 印最終總結與「如何執行產出的應用程式」指引。

#### `run_agent_session(client, message, project_dir) -> (status, response_text)`

執行單一 session：

1. `await client.query(message)`：把 prompt 送進 SDK。
2. `async for msg in client.receive_response()`：**串流接收**回應。用 `type(msg).__name__` 字串比對訊息型別（刻意不 import 具體型別類別——降低與 SDK 內部型別的耦合）：
   - `AssistantMessage`：逐塊處理 `content`。`TextBlock` → 累加並即時印出；`ToolUseBlock` → 印出工具名稱與輸入（輸入超過 200 字截斷）。
   - `UserMessage` → `ToolResultBlock`：工具執行結果。內容含 `blocked` → 印 `[BLOCKED]`（被安全 hook 攔下）；`is_error` → 印 `[Error]`（截斷 500 字）；否則 → 印 `[Done]`。
3. 正常結束回傳 `("continue", response_text)`；丟例外則回傳 `("error", str(e))`。

設計重點：這個函式是 harness 與 SDK 之間的**翻譯層**——把 SDK 的串流事件轉成人類可讀的終端輸出，並把「成功 / 失敗」濃縮成一個 status 字串給主迴圈決策。

### 3.3 `client.py` — SDK 客戶端與安全設定

唯一的公開函式 `create_client(project_dir, model)`，回傳一個設定完整的 `ClaudeSDKClient`。

關鍵內容：

- **兩組工具清單**：
  - `BUILTIN_TOOLS`：`Read`、`Write`、`Edit`、`Glob`、`Grep`、`Bash`。
  - `PUPPETEER_TOOLS`：7 個 `mcp__puppeteer__*` 瀏覽器自動化工具（navigate / screenshot / click / fill / select / hover / evaluate）。
- **寫出 `.claude_settings.json`** 到專案目錄，內容包含：
  - `sandbox`：`{enabled: true, autoAllowBashIfSandboxed: true}`——啟用 OS 層級沙箱。
  - `permissions`：`defaultMode: "acceptEdits"`（在允許目錄內自動核准編輯），`allow` 清單只開放**相對路徑** `./**` 的檔案操作（因 `cwd` 已設為專案目錄，相對路徑等於把檔案存取鎖在專案內）、`Bash(*)`、以及 Puppeteer 工具。
- **回傳 `ClaudeSDKClient`**，其 `ClaudeCodeOptions` 設定：
  - `model`、`system_prompt`（"You are an expert full-stack developer..."）。
  - `allowed_tools`：內建工具 + Puppeteer。
  - `mcp_servers`：註冊 `puppeteer` MCP server（`npx puppeteer-mcp-server`）。
  - `hooks`：`PreToolUse` 對 `Bash` 掛上 `bash_security_hook`（見 3.4）。
  - `max_turns=1000`：單一 session 最多 1000 個對話回合。
  - `cwd`：專案目錄絕對路徑。

設計重點：`client.py` 是**安全策略的組裝點**。它把沙箱、檔案權限、Bash hook 三者一次裝配到 SDK 上。

### 3.4 `security.py` — Bash 指令白名單 hook

最長的一個檔（~360 行），體現「**白名單優於黑名單**」的安全哲學——只放行明確允許的，其餘一律封鎖。

- `ALLOWED_COMMANDS`：允許的指令集合。檔案檢視（`ls`/`cat`/`head`/`tail`/`wc`/`grep`）、檔案操作（`cp`/`mkdir`/`chmod`）、`pwd`、Node.js（`npm`/`node`）、`git`、程序管理（`ps`/`lsof`/`sleep`/`pkill`）、`init.sh`。
- `COMMANDS_NEEDING_EXTRA_VALIDATION = {"pkill", "chmod", "init.sh"}`：即使在白名單內，仍需額外驗證的高風險指令。
- **核心 hook**：`async def bash_security_hook(input_data, ...)`——掛在 SDK 的 `PreToolUse` 階段，在每一次 Bash 工具實際執行**之前**攔截：
  1. 非 Bash 工具 → 直接放行（回傳 `{}`）。
  2. `extract_commands()` 從指令字串拆出所有指令名稱（處理管線 `|`、串接 `&&`/`||`/`;`、shell 關鍵字、旗標、變數賦值等）。
  3. 解析失敗 → **fail-safe 封鎖**（回傳 `{"decision": "block", ...}`）。
  4. 逐一檢查每個指令是否在 `ALLOWED_COMMANDS`；不在 → 封鎖。
  5. 高風險指令再做額外驗證。
- **額外驗證函式**：
  - `validate_pkill_command()`：`pkill` 只准殺開發相關程序（`node`/`npm`/`npx`/`vite`/`next`）——防止濫殺系統程序。
  - `validate_chmod_command()`：`chmod` 只准 `+x`（讓腳本可執行），不准遞迴、不准其他模式。
  - `validate_init_script()`：只准執行 `./init.sh` 或結尾為 `/init.sh` 的腳本。
- 輔助函式 `split_command_segments()`、`get_command_for_validation()` 負責把複合指令切段，讓額外驗證能精準對應到含該指令的那一段。

設計重點：用 `shlex` 做 tokenize（而非脆弱的正規表達式比對），並在所有解析失敗的路徑都選擇「封鎖」而非「放行」——這是 fail-safe / fail-closed 的安全姿態。

### 3.5 `progress.py` — 進度追蹤

三個小函式：

- `count_passing_tests(project_dir) -> (passing, total)`：讀 `feature_list.json`，數 `passes == true` 的數量與總數。檔案不存在或 JSON 解析失敗 → 回傳 `(0, 0)`（不拋例外）。
- `print_session_header(session_num, is_initializer)`：印格式化的 session 標題。
- `print_progress_summary(project_dir)`：印「passing / total（百分比）」。

設計重點：進度不是某個記憶體變數，而是**每次重新從 `feature_list.json` 算出來的**。這呼應了第 1 節的靈魂——狀態在檔案裡。

### 3.6 `prompts.py` — 提示詞載入

- `load_prompt(name)`：從 `prompts/` 目錄讀 `{name}.md`。
- `get_initializer_prompt()` / `get_coding_prompt()`：分別載入兩份提示詞。
- `copy_spec_to_project(project_dir)`：把 `app_spec.txt` 複製進專案目錄（讓 agent 在自己的工作目錄裡就能讀到規格）。

設計重點：提示詞是**外部 Markdown 檔**，不寫死在 Python 裡——要改 agent 行為（例如把 200 改成 5、調整測試流程），改 `.md` 即可，不必動程式碼。

---

## 4. 端對端執行流程（Execution Flow）

完整跑一次的流程如下（對應圖表 `02-流程圖`）：

1. 使用者執行 `python autonomous_agent_demo.py --project-dir ./my_project`。
2. 檢查 `ANTHROPIC_API_KEY`——未設定 → 印錯誤、結束。
3. 解析 `project_dir`，相對路徑自動放入 `generations/`。
4. 建立專案目錄。
5. 判斷 `feature_list.json` 是否存在：
   - **不存在**（首次執行）：標記 `is_first_run = True`，複製 `app_spec.txt` 進專案。
   - **存在**（續做）：印出目前進度。
6. **進入主迴圈 `while True`**：
   1. `iteration += 1`。
   2. 若超過 `max_iterations` → 跳出迴圈。
   3. 印 session 標題。
   4. `create_client()`——建立全新 context、寫出 `.claude_settings.json`。
   5. 選 prompt：首次 → initializer；否則 → coding。
   6. `run_agent_session()`——送出 prompt、串流接收回應、即時印出工具呼叫；過程中每個 Bash 指令都先過 `bash_security_hook`。
   7. 狀態 `continue` → 睡 3 秒、印進度；狀態 `error` → 睡 3 秒、下一輪用新 session 重試。
7. 迴圈結束 → 印最終總結 + 「如何執行產出的應用程式」指引（`cd` 進去、跑 `init.sh` 或 `npm install && npm run dev`）。

**暫停與續做**：按 `Ctrl+C` 隨時可中斷；因為進度全在 `feature_list.json` + git，重跑同一條指令就會從上次的地方接續——不需要任何「恢復」邏輯，續做是自然發生的。

---

## 5. Session 生命週期與狀態（State Model）

對應圖表 `06-狀態圖`。系統有兩種 session，各有內部狀態：

**初始化 Session 的內部狀態流**：
讀取規格 → 產生功能清單 → 建立專案結構 → 初始化 git → 結束。

**編碼 Session 的內部狀態流**：
讀取功能清單 → 實作功能 → 標記通過 → 提交 git → 結束。

**Session 之間的轉移**：

- 初始化 Session 完成 → 自動接續（間隔 3 秒）進入第一個編碼 Session。
- 編碼 Session 完成 → 續做下一個編碼 Session（若發生錯誤，下一輪用全新 session 重試）。
- 達到 `max_iterations` 上限 → 結束。

關鍵心智模型：**每個 session 之間沒有記憶體狀態的延續**。新 session 唯一知道「現在在哪」的方式，是 coding prompt 的 Step 1「搞清楚現況」——它強制 agent 開場就讀檔案、看 git log。狀態的「接力棒」是檔案，不是變數。

---

## 6. 三層縱深防禦安全模型（Defense in Depth）

因為 agent 會自主執行 shell 指令、讀寫檔案，安全是這個 harness 的一級考量。對應圖表 `03-系統架構圖` 的安全區塊。

| 層級 | 機制 | 防什麼 | 實作位置 |
|------|------|--------|---------|
| 第 1 層 | **OS 沙箱** | Bash 指令在隔離環境執行，無法逃逸到主機檔案系統 | `client.py` 的 `sandbox` 設定 |
| 第 2 層 | **檔案系統限制** | 檔案操作只能在專案目錄內（`./**` 相對路徑 + `cwd` 鎖定） | `client.py` 的 `permissions.allow` |
| 第 3 層 | **Bash 白名單 hook** | 只放行白名單指令；高風險指令再做參數級驗證 | `security.py` 的 `bash_security_hook` |

「縱深防禦」的意義：任一層被突破，還有其他層守著。例如就算白名單漏放了某個危險指令（第 3 層失效），它造成的破壞範圍仍被沙箱（第 1 層）與檔案系統限制（第 2 層）框住。

第 3 層特別值得注意的兩個工程細節：

1. **fail-closed**：任何解析失敗（指令拆不開、引號沒閉合）都選擇「封鎖」。安全系統寧可錯殺，不可放過。
2. **參數級驗證**：白名單不只看「指令名稱」，對 `pkill`/`chmod`/`init.sh` 還看「參數內容」——`pkill` 只能殺 dev 程序、`chmod` 只能 `+x`。這擋掉了「指令名合法但參數惡意」的攻擊面。

---

## 7. 進度持久化機制（Persistence）

系統用三種檔案保存跨 session 的狀態：

- **`feature_list.json`**——唯一事實來源（single source of truth）。記錄所有功能項與各自的 `passes` 狀態。鐵律：只能 `false → true`，不可刪改。
- **git commits**——每個 session 結束前 commit，形成可追溯的進度歷史；也是「續做」能成立的基礎。
- **`claude-progress.txt`**——人類可讀的進度筆記。每個 coding session 會更新：這次做了什麼、完成哪幾項測試、發現/修了什麼問題、下次該做什麼、目前完成度（如 `45/200 tests passing`）。

三者分工：`feature_list.json` 是結構化的「契約與勾選表」，git 是「不可竄改的歷史」，`claude-progress.txt` 是「給下一棒的口頭交接」。

---

## 8. 它要打造的目標應用（app_spec.txt 摘要）

`prompts/app_spec.txt` 是一份約 680 行的 XML 規格，定義 agent 要打造的應用：**Claude.ai Clone — 一個 AI 聊天介面**。

- **技術棧**：前端 React + Vite + Tailwind CSS；後端 Node.js + Express + SQLite（`better-sqlite3`）；串流用 Server-Sent Events；串接 Claude API。
- **功能範圍**（極廣）：串流聊天、Markdown/程式碼高亮、Artifacts 側欄渲染（程式碼/HTML/SVG/React/Mermaid）、對話管理（建立/重新命名/刪除/搜尋/釘選/封存/資料夾）、Projects 群組、模型選擇、自訂指令、設定（深淺色主題等）、進階參數（temperature/top-p）、分享協作、搜尋、用量追蹤、新手導覽、無障礙、響應式設計。
- **資料庫 schema**：12 張表（users、projects、conversations、messages、artifacts、shared_conversations、prompt_library、folders…）。
- **API**：橫跨 auth、conversations、messages、artifacts、projects、sharing、prompts、search、folders、usage、settings、claude_api 等十幾組 RESTful endpoint。
- **9 個實作步驟**：從「專案基礎 + 資料庫」到「打磨與最佳化」。

重點：這份規格刻意設計得**非常龐大**——正是為了證明「單一 context 做不完、必須靠多 session 接力」這個論點。規格的複雜度本身就是這個 demo 存在的理由。

---

## 9. 產出的專案結構（Generated Output）

跑完後，`generations/my_project/` 內會有：

- `feature_list.json`——測試案例與進度（事實來源）。
- `app_spec.txt`——複製進來的規格。
- `init.sh`——環境設定腳本。
- `claude-progress.txt`——session 進度筆記。
- `.claude_settings.json`——安全設定（由 `create_client()` 每輪寫出）。
- `[應用程式檔案]`——agent 實際產出的前後端程式碼。

執行產出的應用：`cd` 進目錄 → `./init.sh`（或手動 `npm install && npm run dev`）→ 開 `http://localhost:3000`。

---

## 10. 關鍵設計決策與值得注意的模式

給資深工程師快速吸收的「為什麼這樣設計」清單：

1. **狀態外部化**：進度不存在記憶體，存在 `feature_list.json` + git。這讓「續做」變成免費的副產品——不需要寫任何 checkpoint / resume 邏輯。
2. **無狀態 session**：每輪 `create_client()` 建立全新 context。長對話劣化的問題被「定期重置」根除。
3. **提示詞即配置**：行為定義在 `.md` 檔，不寫死在 Python。改行為不必改碼。
4. **鴨子型別接收 SDK 訊息**：`run_agent_session()` 用 `type(msg).__name__` 字串比對，不 import SDK 內部型別類別——刻意降低與 SDK 版本的耦合。
5. **白名單 + fail-closed 安全**：只放行已知安全的，解析失敗一律封鎖。
6. **縱深防禦**：沙箱 / 檔案限制 / Bash hook 三層獨立，互為備援。
7. **薄進入點**：`autonomous_agent_demo.py` 只做檢查與委派，邏輯集中在 `agent.py`，易讀易測。
8. **錯誤即重試**：session 失敗不會讓整個程式崩潰，主迴圈用「全新 session」重試——把「重置」當成通用的錯誤復原手段。
9. **不可竄改的功能契約**：「只能 false→true」這條鐵律，是防止「LLM 為了讓進度好看而偷偷刪測試」的關鍵守門員。

---

## 11. 已知不一致與閱讀注意事項

供後續維護者注意的觀察點：

- **功能數量不一致**：`initializer_prompt.md` 要 5 個、`coding_prompt.md` 與 `README.md` 寫 200。閱讀時以 prompt 實際內容為準；若要恢復成 200，需同步改回 `initializer_prompt.md`。
- **`DEFAULT_MODEL` 是寫死常數**：`autonomous_agent_demo.py` 內 `claude-sonnet-4-5-20250929`。換模型可用 `--model` 參數覆寫。
- **單一外部相依**：`requirements.txt` 只有 `claude-code-sdk>=0.0.25`。另需全域安裝 Claude Code CLI（`npm install -g @anthropic-ai/claude-code`）與 Node.js（給目標應用與 Puppeteer MCP 用）。
- **成本意識**：本 demo 直接呼叫 Anthropic API，消耗 API Credits；跑完整 200 功能需數小時，費用不低。測試時務必加 `--max-iterations`（如 `3`）。

---

## 12. 如何執行（Quick Start）

```bash
# 安裝
npm install -g @anthropic-ai/claude-code
pip install -r requirements.txt

# 設定金鑰
export ANTHROPIC_API_KEY='your-api-key-here'

# 跑（測試用，限 3 輪）
python autonomous_agent_demo.py --project-dir ./my_project --max-iterations 3

# 續做：重跑同一條指令即可
python autonomous_agent_demo.py --project-dir ./my_project
```

---

## 13. 配套圖表索引

本報告搭配 6 張 Mermaid 圖（位於 `autonomous-coding/mermaid/`，`mmd/` 為原始檔、`png/` 為圖片）：

| 編號 | 圖表 | 看這張理解… |
|------|------|-------------|
| 01 | 心智圖 | 全貌：雙 Agent / 主迴圈 / 三層安全 / 核心模組 / 進度保存 |
| 02 | 流程圖 | 一次執行的完整控制流 |
| 03 | 系統架構圖 | 模組分層與依賴 |
| 04 | 序列圖 | 執行時的呼叫互動（含安全 hook 放行/封鎖分支） |
| 05 | 類別圖 | 6 個模組的函式、常數與依賴關係 |
| 06 | 狀態圖 | 兩種 session 的生命週期與狀態轉移 |

建議閱讀順序：01（抓全貌）→ 02（懂流程）→ 03（懂分層）→ 04 / 06（懂執行細節）→ 05（查函式）。

---

## 14. 一句話總結

> `autonomous-coding` 證明了一件事：**LLM 的 context window 有限，但「工作」可以被外部化成檔案與 git，於是長時程的自主編碼，就變成一連串『全新 context、讀檔案、做一件事、寫回檔案』的無狀態迴圈。** 這個 harness 用約 600 行 Python，把這個迴圈、加上雙 Agent 角色分工、加上三層安全防禦，完整地示範了出來。
