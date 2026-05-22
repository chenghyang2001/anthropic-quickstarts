# Session 3 Summary — agents 三關演練實跑 + 專案導讀產出 + doc 目錄重整

**日期：** 2026-05-23
**專案：** `anthropic-quickstarts`（`chenghyang2001/anthropic-quickstarts`）
**Session 主題：** agents 站三關演練實跑、產出專案導讀（含 NotebookLM／Mermaid／Google Doc）、把 doc 目錄重整進 agents/doc、practice 腳本擴充為兩題版

---

## 完成事項

### agents 三關演練實跑

- `practice_01`（ThinkTool）、`practice_02`（FileRead/Write）、`practice_03`（Server 工具）全部實跑成功 —— 這三檔由 Session 2 建立，本 session 首次帶 API key 實跑
- **practice_03 首跑崩潰並修復**：`anthropic` SDK 0.40.0 與 Python 3.14 不相容 —— SDK 解析含 `code_execution` 工具的 API 回應時，會對 `typing.Union` 物件設 `__discriminator__` 屬性（`_models.py:646`），Python 3.14 已禁止此操作。升級 SDK `0.40.0 → 0.104.0` 後通過

### 專案導讀與多媒體產出

- 建立 `agents-專案導讀.md`：9 章完整導讀（專案定位／核心理念／進入點／檔案結構與各檔功能／核心迴圈詳解／工具系統／設計亮點／環境需求／總結）
- NotebookLM：建 notebook（ID `8d7d16fd-4a51-4b24-bdcc-1a54f900511b`）+ 加導讀為 source + 生成語音／影片／簡報三 studio 內容，下載到 `notebooklm/`（m4a 26.5MB／pptx 8.8MB／mp4 57.6MB）
- Google Doc：建立導讀內容文件（`docs.google.com/document/d/10qx9i5Mv-pZ9tLA3-Xt5rbl3QicIvXuCPyJAkbM7AWU`）
- Mermaid：心智圖／流程圖（`_agent_loop`）／系統架構圖三張，輸出 PNG，已視覺驗證中文正常

### README 繁體中文翻譯

- 建立 `agents/README-中文.md`：`README.md` 的繁體中文翻譯版（原檔保留不動，程式碼區塊保留原始 Python 語法、僅翻註解）

### doc/ 目錄重整（搬進 agents/doc/）

- 整個 `doc/` 從 repo 根目錄搬到 `agents/doc/`
- 4 個 git 追蹤檔用 `git mv`（`practice_01~03`、`quickstarts-演練計畫.md`，保留 rename 歷史）；3 個未追蹤項目用一般 `mv`（`agents-專案導讀.md`、`mermaid/`、`notebooklm/`）；移除空的舊 `doc/`
- 連帶修 3 個 practice 腳本的 `REPO_ROOT`：`parent.parent` → `parent.parent.parent`（搬深一層）+ docstring 執行範例路徑 `doc/` → `agents/doc/`
- 實測 3 支腳本搬移後仍能正確 `import agents`（不設 key、跑到金鑰檢查即停，不耗 API credits）

### practice 腳本擴充為兩題版

- **practice_01**：單一問題改成兩題 list + `enumerate(questions, start=1)` 迴圈（台灣最高山 + 最高建築物）。走 code-writer → code-qa（簡單／2 test case／不派 reviewer），QA 5 層 PASS。實跑答：玉山 3,952m、台北 101 508m
- **practice_03**：單一問題改成兩題（台灣 GDP 占全球比例 + 美國上月前五好萊塢電影占今年票房比例）+ `WebSearchServerTool` 的 `max_uses` 由 3 改 6（兩題共用搜尋額度）。走 code-writer → code-qa（簡單／2 test case／不派 reviewer），QA 5 層 PASS。實跑答：台灣 GDP 占全球約 0.88%；美國 2026 年 4 月前五電影合計 $688.5M、占 2026 YTD 全美票房約 21.65%

---

## 關鍵技術筆記

### SDK / Python 版本相容

`anthropic` SDK 0.40.0 解析含 `code_execution` 工具的 API 回應，會在 `typing.Union` 物件塞 `__discriminator__` 屬性；Python 3.14 已禁止對 `typing.Union` 設屬性 → 在 Python 3.14 環境必須用 `anthropic` 0.104.0 以上。

### 搬移「自我定位」腳本的階數陷阱

practice 腳本用 `Path(__file__).resolve().parent.parent` 自我定位 repo 根目錄。搬到更深一層的目錄後，`.parent` 階數必須同步加一，否則 `sys.path.insert` 與 `os.chdir` 全部指錯位置、`import agents` 直接失敗。混合追蹤狀態的批次搬移原則：tracked 檔用 `git mv`（保留 rename 歷史）、untracked 檔用一般 `mv`。

### Agent 工具錯誤自癒

practice_03 第 2 題開頭，Claude 呼叫 `think()` 漏帶 `thought` 參數 → `ThinkTool` 拋 `missing 1 required positional argument` → 錯誤訊息被當成 tool_result 餵回對話歷史 → Claude 看到後自我修正、重呼 `think(thought=...)`。示範 `_agent_loop()` 對工具錯誤的韌性：工具報錯不會讓迴圈崩潰。

### 單 agent 多問題的搜尋額度

`WebSearchServerTool(max_uses=N)` 是 agent 生命週期共用的搜尋次數上限。同一個 agent 實例連問多題時，`max_uses` 必須按題數放大（兩題演練 → 設 6，每題約 3 次），否則第二題會因額度耗盡而搜不到資料。

---

## 產出檔案

| 檔案 | 類型 | 說明 |
|---|---|---|
| `agents/README-中文.md` | 新增 | README 繁體中文翻譯版 |
| `agents/doc/`（整個目錄）| 搬移 | 從 repo 根 `doc/` 搬入 |
| `agents/doc/practice_01_think.py` | 搬移+修改 | REPO_ROOT 修正 + 擴充為兩題版 |
| `agents/doc/practice_02_files.py` | 搬移+修改 | REPO_ROOT 修正 |
| `agents/doc/practice_03_server_tools.py` | 搬移+修改 | REPO_ROOT 修正 + 擴充兩題 + max_uses 3→6 |
| `agents/doc/quickstarts-演練計畫.md` | 搬移 | 7 站演練計畫總表 |
| `agents/doc/agents-專案導讀.md` | 新增 | 9 章專案導讀 |
| `agents/doc/mermaid/` | 新增 | 心智圖／流程圖／系統架構圖（mmd + png）|
| `agents/doc/notebooklm/` | 新增 | NotebookLM 語音／影片／簡報（約 93MB，已 gitignore 不入庫）|
| `agents/summary.txt` | 新增 | practice_02 演練產出（已 gitignore）|
| `.gitignore` | 修改 | 加入 `agents/doc/notebooklm/` + `agents/summary.txt` 排除 |
| `MEMORY.md` | 修改 | 更新 `doc/` → `agents/doc/` 路徑記錄 |

---

## HANDOFF（下次 session 優先處理）

### 立即行動

- [ ] **撤銷重發 Anthropic API key** —— 本 session（與 Session 2）演練時 API key 多次完整出現在對話紀錄中，務必到 console.anthropic.com 撤銷該把 key 並重新發行。Session 2 HANDOFF 已列此項但尚未處理，本 session 使用者又貼了同一把 key
- [ ] 演練剩餘 3 站需先裝 Docker Desktop（`computer-use-demo` / `browser-use-demo`）；`computer-use-best-practices` 為 macOS 專屬，此 Windows 機無法演練

### 進行中（需接續）

- 7 站演練計畫：`agents` 站本 session 完整收尾（三關演練 + 專案導讀 + NotebookLM/Mermaid/Google Doc 多媒體）。`financial-data-analyst` / `autonomous-coding` / `customer-support-agent` 已於 Session 2 演練。剩 `computer-use-demo`、`browser-use-demo`、`computer-use-best-practices` 三站未演練
- 演練計畫總表現位於 `agents/doc/quickstarts-演練計畫.md`（本 session 從 repo 根 `doc/` 搬入）

### 注意事項

- `agents/doc/notebooklm/` 內 3 個檔約 93MB（m4a / pptx / mp4），已加入 `.gitignore` 不入版控；要看內容直接開本機檔案
- practice 腳本現在位於 `agents/doc/`，`REPO_ROOT` 用 `parent.parent.parent`（往上三層才是 repo 根）
- `practice_01` 與 `practice_03` 現為兩題版；要增減題目只動 `main()` 裡的 `questions` list，迴圈邏輯不必改
- 演練直接呼叫 Anthropic API → 扣 API Credits（非 Max 訂閱）；key 一律 inline 臨時帶入，不可 `setx` 永久設定
