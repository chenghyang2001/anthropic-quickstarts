# autonomous-coding 演練紀錄

> 日期：2026-05-23
> 專案：`anthropic-quickstarts/autonomous-coding`
> 模型：`claude-haiku-4-5-20251001`（harness 預設為 `claude-sonnet-4-5-20250929`）

---

## 一、演練目標

不追求蓋完整個 App，只求**完整跑過一遍流程**、看懂這個「長時自主編碼 harness」的運作機制，並記錄過程中踩到的環境問題。

---

## 二、環境前置

| 項目 | 狀態 |
|------|------|
| Python | 3.14.3 |
| `claude-code-sdk` | 演練時才安裝 `0.0.25`（原本未裝），Python 3.14 import 正常 |
| Node / npm | v24.13.1 / 11.8.0 |
| `claude` CLI | 2.1.148 |
| `ANTHROPIC_API_KEY` | 未設於環境變數；演練時以單次內聯方式提供，後存成 `~/Downloads/anthropic-api-key.txt` 供腳本引用（不做 `setx` 全域設定，避免所有 `claude -p` 改扣 API Credits） |

---

## 三、三次實跑紀錄

| 跑次 | 專案目錄 | 參數 | 結果 |
|------|---------|------|------|
| Run 1 | `demo_run` | `--max-iterations 1` | 只跑 initializer；產出 `feature_list.json`（8 功能）+ `README.md`；`init.sh` 被鐵律 hook 擋；尾段 `Credit balance is too low` |
| Run 2 | `demo_run2` | `--max-iterations 2` + `DISABLE_WRITER_QA_HOOK=1` | Session 1 initializer 完整成功（5 功能、`init.sh`、`git init`、骨架）；Session 2 coding agent 啟動即撞 `API usage limit` |
| Run 3 | `demo_run2` | `--max-iterations 5` + `DISABLE_WRITER_QA_HOOK=1` | 續跑（CODING AGENT 模式）；S1–S3 蓋出完整前後端共 6 commit；S4–S5 啟動即死 `Credit balance is too low`；最終 **0/5** |

說明：

- **Run 1 → Run 2 換目錄**：`feature_list.json` 存在與否決定走 initializer 還是 coding agent。Run 1 留下 `demo_run/feature_list.json`，且該目錄被佔用（`rm` 報 Device busy），故 Run 2 改用新目錄 `demo_run2` 從頭跑。
- **Run 3 沿用 `demo_run2`**：因 `feature_list.json` 已存在，自動進入 CODING AGENT 模式，連跑 5 個 coding session。

---

## 四、雙 agent 流程實證（機制正常）

harness 的核心設計在這次演練中**全部正常運作**：

1. **雙 agent 模式**：Session 1 套用 `initializer_prompt.md`，Session 2 起自動切換 `coding_prompt.md`，判斷依據是 `feature_list.json` 是否存在。
2. **狀態外部化**：每個 session 都是全新 context window，靠 `feature_list.json` + `git log` + `claude-progress.txt` 重建進度，不依賴記憶。Run 3 的 5 個 session 確實每次都重新讀這三個來源。
3. **session 交接**：`--max-iterations` 控制迴圈次數，每個 session 結束前 commit、留乾淨狀態給下一棒。
4. **誠實驗證**：coding agent 嚴守「沒有 Puppeteer 截圖驗證過，不可標 `passes:true`」——App 跑不起來時維持 0/5，**不灌水**。

---

## 五、八個發現

### 環境相容性

**① Windows OS 沙箱自動停用**
`⚠ Sandbox disabled: sandbox is enabled but windows is not supported (requires macOS, Linux, or WSL2)`。
harness 宣稱的三層防禦（OS 沙箱 / 檔案權限 / Bash 白名單），在 Windows 上第一層直接失效，只剩兩層。

**② 使用者鐵律 hook 與 harness 本質衝突**
Run 1 中 harness 內層 agent 想 `Write` 一個 `init.sh`，被使用者全域 `~/.claude` 的 PreToolUse hook `enforce_writer_qa.py` 攔下。內層 agent 看到錯誤後**停下來問人類**「Which would you prefer?」——但這是無人值守迴圈，沒有人能回答。
→ harness 的工作本質就是自主狂寫程式碼檔，與「每個程式碼檔都要派 writer/qa/reviewer」的鐵律無法共存。**必須**啟動時加 `DISABLE_WRITER_QA_HOOK=1`。

**③ harness 自身的 Bash 白名單過嚴**
`security.py` 的 `ALLOWED_COMMANDS` 擋掉 `cd`、`echo`、`test`、`bash`、`find`、`sort`；`pkill` 只允許特定 process 名（`vite/node/next/npx/npm`）。
agent 全程被迫繞道：`cd server && npm install` → `npm --prefix <絕對路徑> install`；`git commit` → `git -C <路徑> commit`。Run 3 log 共 78 筆 BLOCKED/Error，大量 session 時間耗在繞過白名單。

**④ chrome-devtools MCP 工具未授權**
agent 想用 `mcp__chrome-devtools__list_console_messages` 抓瀏覽器 console error 來 debug 空白頁，但該工具權限未授權被擋，少了一個關鍵除錯手段。

### 額度卡關（兩種，需分別處理）

**⑤ API 用量上限（usage limit）**
`API Error: 400 You have reached your specified API usage limits. You will regain access on 2026-06-01`。
帳號設了每月用量上限且已達標 → 需到 console 調高上限。

**⑥ Credits 餘額耗盡（credit balance）**
`Credit balance is too low`。
與 ⑤ 不同——這是實際儲值餘額見底。Run 3 的 S1–S3 蓋完整 App 把餘額燒乾，S4–S5 啟動即死。
→ 兩種額度問題獨立，調高 usage limit ≠ 有 credits。

### 模型能力

**⑦ haiku 蓋複雜全端 App 的能力邊界**
haiku 寫出的 React App 跑出**空白頁**（agent 自己懷疑是 `SettingsModal` 的 import bug）。Puppeteer 能 navigate（HTTP 200）但畫面空白，agent 花整個 Session 3 debug 仍未修好。
→ 蓋 claude.ai clone 這種複雜度，建議用 `sonnet`；haiku 適合看流程、不適合產出可動的成品。

### 無關雜訊

**⑧ openai-codex plugin 的 SessionEnd hook 壞掉**
log 反覆出現 `Cannot find module 'C:\c\Users\user\.claude\plugins\cache\openai-codex\...session-lifecycle-hook.mjs'`（路徑開頭 `C:\c\` 畸形）。與本 demo 無關，是另一個 plugin 自身的問題，但會污染 log。

---

## 六、產出檔案（`generations/demo_run2/`）

initializer + 3 個 coding session 累積產出：

```
feature_list.json          5 個端對端測試（全 passes:false）
init.sh                    環境設定腳本
README.md / INITIALIZATION_COMPLETE.md / claude-progress.txt
package.json / vite.config.js / index.html / .gitignore / .env
src/
  App.jsx / App.css / main.jsx
  components/  ChatArea.jsx / Sidebar.jsx / ArtifactPanel.jsx
               MessageBubble.jsx / SettingsModal.jsx
server/
  server.js (667 行：SQL.js 資料庫 + Claude API 串流 + artifact 偵測)
  package.json
```

git 共 10 個 commit。程式碼有寫出來，但因 App 跑空白頁、未通過驗證，`feature_list.json` 維持 **0/5**。

---

## 七、結論與建議

**演練目標達成**：harness 的雙 agent 流程、狀態外部化交接、誠實驗證機制全部親眼跑過一遍。`feature_list.json` 裡的「200」只是 harness 留下的舊文字，實際 initializer 依 prompt 產生 5–8 個（`initializer_prompt.md` 已被前次 session 調為最小演練設定）。

**未竟之處**：沒有任何 feature 變綠。原因是 ⑦ haiku 產出有 bug 的 App + ⑥ credits 耗盡，**並非 harness 設計缺陷**。

**若未來要拚「feature 變綠」**：
1. 換 `--model claude-sonnet-4-5-20250929`（haiku 能力不足以蓋可動的全端 App）
2. 預先儲足 credits 並調高 usage limit（一個 coding session 蓋整個 App 不便宜）
3. 啟動時務必 `DISABLE_WRITER_QA_HOOK=1`，否則內層 agent 每寫一個程式碼檔就卡住問人
4. 在 macOS / Linux / WSL2 上跑，才有完整三層沙箱

**啟動指令範本（供日後參考）**：

```bash
cd autonomous-coding
DISABLE_WRITER_QA_HOOK=1 \
ANTHROPIC_API_KEY="$(tr -d '[:space:]' < ~/Downloads/anthropic-api-key.txt)" \
PYTHONUTF8=1 \
python -u autonomous_agent_demo.py \
  --project-dir ./demo_run \
  --max-iterations 5 \
  --model claude-sonnet-4-5-20250929
```
