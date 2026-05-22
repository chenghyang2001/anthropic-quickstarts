# Session 4 Summary

> 日期：2026-05-23
> 主題：`autonomous-coding` quickstart 深度演練

---

## 完成事項

### 架構理解
- 解析 `autonomous-coding` harness：6 個 Python 檔（`autonomous_agent_demo.py` / `agent.py` / `client.py` / `prompts.py` / `progress.py` / `security.py`）
- 釐清雙 agent 模式：Session 1 initializer、Session 2+ coding agent，靠 `feature_list.json` 是否存在自動切換
- 釐清狀態外部化：每個 session 全新 context，靠 `feature_list.json` + git + `claude-progress.txt` 交接
- 釐清「200」迷思：`agent.py` / `coding_prompt.md` 殘留舊文字寫 200，實際 `initializer_prompt.md` 已調為最小演練（5–8 功能）

### 環境前置
- 安裝 `claude-code-sdk==0.0.25`（原本未裝），Python 3.14.3 import 正常
- API key 以單次內聯方式提供；依使用者指示存成 `~/Downloads/anthropic-api-key.txt`（明文，**不做 setx 全域**）

### 三次實跑
| 跑次 | 目錄 | 參數 | 結果 |
|------|------|------|------|
| Run 1 | `demo_run` | `--max-iterations 1` | initializer only；`feature_list.json`（8）+ README；`init.sh` 被鐵律 hook 擋；尾段 credit balance too low |
| Run 2 | `demo_run2` | `--max-iterations 2` + `DISABLE_WRITER_QA_HOOK=1` | Session 1 initializer 完整成功（5 功能/init.sh/git/骨架）；Session 2 撞 API usage limit |
| Run 3 | `demo_run2` | `--max-iterations 5` + `DISABLE_WRITER_QA_HOOK=1` | S1–S3 蓋完整前後端 6 commit；S4–S5 啟動即死 credit balance too low；最終 0/5 |

### 收尾
- 寫 `doc/autonomous-coding-演練紀錄.md`（7 段、八個發現）
- 更新 MEMORY.md（Session 4、claude-code-sdk、autonomous-coding 進度、HANDOFF）
- commit `e84e650` 推上 main（19 檔）

---

## 關鍵技術筆記

- **Windows OS 沙箱失效**：`sandbox is enabled but windows is not supported`，三層防禦剩兩層
- **harness 與鐵律 hook 本質衝突**：harness 內層 agent 寫 `.sh`/`.js` 被 `enforce_writer_qa.py` 擋下、停下問人類「Which would you prefer?」，無人值守迴圈卡死 → 跑 autonomous-coding 必須 `DISABLE_WRITER_QA_HOOK=1`
- **harness 自身 bash 白名單過嚴**：`security.py` 擋 `cd`/`echo`/`test`/`bash`/`find`/`sort`，agent 全程繞道（`npm --prefix`、`git -C`）
- **兩種額度卡關不同**：`API usage limit`（每月用量上限，需 console 調高）≠ `Credit balance too low`（儲值餘額耗盡，需儲值）
- **haiku 能力邊界**：haiku 蓋的 React App 跑出空白頁（疑 SettingsModal import bug），複雜全端 App 建議用 sonnet
- **0/5 是誠實結果**：coding agent 守「沒 Puppeteer 截圖驗證不標 passes」，App 跑不起來就維持 false，非偷懶

---

## 產出檔案

| 檔案 | 說明 |
|------|------|
| `autonomous-coding/doc/autonomous-coding-演練紀錄.md` | 本 session 新增——三次實跑、八個發現、結論 |
| `autonomous-coding/doc/autonomous-coding-codebase-report.md` | 前次產出，本 session 一併 commit |
| `autonomous-coding/doc/long-running-agents-guide-設計依據.md` | 前次產出，本 session 一併 commit |
| `autonomous-coding/README.md` | 中英對照版（前次改，本 session commit）|
| `autonomous-coding/mermaid/`（6 mmd + 6 png）| 前次產出，本 session commit |
| `autonomous-coding/prompts-中文/`（3 檔）| 前次產出，本 session commit |
| `~/Downloads/anthropic-api-key.txt` | API key 明文（repo 外，待刪）|
| `generations/demo_run`、`demo_run2` | agent 產出，gitignore 不入庫 |

commit：`e84e650`（19 files changed, 1963 insertions）

---

## HANDOFF（下次 session 優先處理）

### 立即行動
- [ ] **撤銷重發 Anthropic API key**——key 多次出現在對話紀錄，且明文存於 `~/Downloads/anthropic-api-key.txt`；到 console.anthropic.com 撤銷重發後刪除該檔
- [ ] 演練剩餘站 `computer-use-demo` / `browser-use-demo`——需先裝 Docker Desktop
- [ ] （選做）若要拚 autonomous-coding feature 變綠：換 `--model sonnet` + 儲足 credits + `DISABLE_WRITER_QA_HOOK=1`

### 進行中（需接續）
- `autonomous-coding` 演練已完整收尾，無未完成項。7 站演練剩 `computer-use-demo`、`browser-use-demo`（需 Docker）、`computer-use-best-practices`（macOS 專屬，此機不演練）

### 注意事項
- 跑 `autonomous-coding` harness 必須 `DISABLE_WRITER_QA_HOOK=1`，否則內層 agent 寫程式碼檔被鐵律 hook 卡死
- Windows 上 harness 的 OS 沙箱層失效，只剩檔案權限 + bash 白名單兩層
- `agents` 專案類直接呼叫 API → 扣 API Credits（非 Max 訂閱），演練成本要留意
- `openai-codex` plugin 的 SessionEnd hook 壞掉（`MODULE_NOT_FOUND`，路徑畸形 `C:\c\Users\...`），與演練無關但會污染 log，可考慮另外修
