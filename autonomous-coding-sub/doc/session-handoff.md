# Session Handoff — 2026-05-23

> 本檔記錄這個訂閱版分支從建立到驗證的完整過程，方便未來 Claude session 接手。

## 任務脈絡

使用者要從 `anthropic-quickstarts/autonomous-coding`（強制要 API key、扣 API Credits）分支出**訂閱版**，走 `claude` CLI 的 OAuth 用 Pro/Max 訂閱額度。

對應同 session 的姐妹專案：`../financial-data-analyst-sub/`（同 pattern，但用 TS SDK）。

## 完成事項

### Phase 1 — 訂閱版基本分支建立

走 code-writer → code-qa → 主 Claude（簡單複雜度不派 reviewer）：

- `cp -r autonomous-coding autonomous-coding-sub`
- 改 2 個 Python 檔（各 ~9 行）：
  - `autonomous_agent_demo.py:80-85`：移除 ANTHROPIC_API_KEY hard-check，改 `os.environ.pop` 強制清掉 env 強制 OAuth
  - `client.py:57-62`：移除 `raise ValueError`，改 `print('[client] Subscription mode...')`；順手清掉 unused `import os`
- 加 README.md 訂閱版說明 + `doc/subscription-version-notes.md` 架構筆記

驗證（max-iter 1）：
- `[Subscription mode]` 啟動訊息確認
- Initializer 完整跑完
- feature_list.json 產生 5 features
- init.sh + Vite 專案結構 + git commit 全部到位
- console.anthropic.com Credits 沒動 → 確認走訂閱

Commit：`a8133f3 新增 autonomous-coding-sub：訂閱版分支`（push 完）

### Phase 2 — bash 版 verbose tool 可見性

走 code-writer → code-qa（簡單複雜度 / 2 test cases / 不派 reviewer）：

- 新建 `scripts/parse_claude_stream.py`（107 行 Python parser）：
  - 讀 stdin JSONL → 印 `[Tool: name] {input}` / `[OK/ERR] result` / `> text` / `=== DONE ===`
  - unicode-safe（`ensure_ascii=False`）+ 非 JSON 行 fallback 原樣印
  - `flush=True` stream-friendly
- 改 `autonomous_cli_loop.sh` 兩處 `claude -p`：
  - 加 `--output-format stream-json --verbose` flag
  - pipe 到 parser
  - 保留 `set -o pipefail` 讓 `if !` 正常捕獲失敗
- 加 `*.log` `*_run.log` 到 .gitignore

QA 全 PASS。

### Phase 3 — Windows 路徑修復

5 features full run（`./autonomous_cli_loop.sh five_demo 5`）一啟動就掛：

```
python.exe: can't open file 'C:\\c\\Users\\user\\workspace\\...\\parse_claude_stream.py'
```

Git Bash 的 `$SCRIPT_DIR = /c/Users/...` 餵 Windows 原生 Python 變成 `C:\c\Users\...`（多餘 `\c\`）。

修法（3 行小修豁免）：
- 加 `PARSER_PATH="$(cygpath -w "$SCRIPT_DIR/scripts/parse_claude_stream.py" 2>/dev/null || ...)"`
- 兩處 python 引用改 `"$PARSER_PATH"`

Commit：`fccbabb 新增 autonomous-coding-sub verbose 模式 + parser`（push 完，含上面所有 Phase 2/3 改動）

### Phase 4 — 5 features full run 驗證

第二次跑（v3）成功啟動，verbose 模式運作完美：

```
--- Session 1：initializer (讀 app_spec → 生成 feature_list.json) ---
  > I'll start by reading the project specification...
[Tool: Read] {"file_path": "...\\app_spec.txt"}
   [OK] 1<project_specification> 2<project_name>Claude.ai Clone...
[Tool: Write] {"file_path": "feature_list.json"}
   [OK] (created)
...
=== DONE [success] (cost: $1.0087, turns: 18) ===
```

但 **0/8 features 通過**。stall detection 在第 4 圈正確 abort（連續 3 圈剩餘數沒下降）。

根因（log 結尾找到）：
```
[Tool: mcp__chrome-devtools__new_page] {"url": "http://localhost:5173"}
   [ERR] Claude requested permissions to use mcp__chrome-devtools__new_page, but you have...
```

bash 腳本的 `.claude/settings.json` permissions.allow 不含 `mcp__chrome-devtools__*` → agent 想驗 UI 被擋 → 跑不動 features → stall abort。

總成本（4 sessions）：~$3.69 USD 等價（全走訂閱配額，不扣 API Credits）。

## 已驗證的事

| 項目 | 結果 |
|---|---|
| 訂閱模式 OAuth 走通 | ✅ |
| `os.environ.pop` 隔離 API key 成功 | ✅ |
| Python 版 max-iter 1 完整成功 | ✅ |
| bash 版 verbose tool 可見性 | ✅ |
| stall detection 救成本 | ✅ |
| cygpath 路徑修復 | ✅ |
| 5 features full run 通過率 | ❌ 0/8（MCP allowlist 缺）|

## 未解決問題

### #1 bash MCP allowlist 缺（**高優先**）

`autonomous_cli_loop.sh` 寫進 `$PROJECT_DIR/.claude/settings.json` 的 allow 清單：

```json
["Read", "Write", "Edit", "Glob", "Grep",
 "Bash(npm:*)", "Bash(node:*)", "Bash(git init:*)", "Bash(git add:*)",
 "Bash(git commit:*)", "Bash(git status:*)", "Bash(git diff:*)",
 "Bash(git log:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(mkdir:*)",
 "Bash(head:*)", "Bash(tail:*)", "Bash(wc:*)", "Bash(grep:*)",
 "Bash(pwd)", "Bash(cp:*)"]
```

少了 MCP browser tools。對照 Python 版 `client.py:19-27`：

```python
PUPPETEER_TOOLS = [
    "mcp__puppeteer__puppeteer_navigate",
    "mcp__puppeteer__puppeteer_screenshot",
    "mcp__puppeteer__puppeteer_click",
    "mcp__puppeteer__puppeteer_fill",
    "mcp__puppeteer__puppeteer_select",
    "mcp__puppeteer__puppeteer_hover",
    "mcp__puppeteer__puppeteer_evaluate",
]
```

下次修：把這 7 個加進 bash 腳本的 settings.json allow + spawn puppeteer-mcp-server 在 bash 啟動時。

或：改用 Chrome DevTools MCP（`mcp__chrome-devtools__*`），對齊主 Claude 工具集。

### #2 Windows SDK 「Stream closed」（Python 版獨有）

長任務（> 5 min）會中斷。bash 版沒這問題。詳見 CLAUDE.md「已知議題 2」。

### #3 agent 自由發揮 feature 數量

initializer prompt 寫「Minimum 5 features」，agent 看 Claude.ai clone spec 太大，自己生成 8 個或 12 個 features。會延長 run time + 訂閱用量。考慮：
- prompt 改成 hard limit `Exactly 5 features`
- 或縮減 app_spec.txt 範圍

### #4 父 repo contamination 風險

agent 在 `generations/<project>/` 工作但若該目錄沒 .git，`git commit` 會往上找命中**父 repo** 的 .git → 不小心 commit 進父 repo。

防禦：bash 腳本應該確保 `generations/<project>/` 在 agent 工作前**先** `git init`，搶在 agent 之前佔住。Python 版的 client.py 限制 cwd 但沒設 git boundary。

5/23 session 確實踩到一次：agent 留下 `feeb1e3` commit 到父 repo（我用 `soft reset HEAD~1` 收回，最終以 `fccbabb` push 出去）。

## 下次接手建議步驟

1. 讀 `CLAUDE.md` 全文（5 分鐘）
2. 讀本檔（5 分鐘）
3. 確認 `claude` CLI 登入：`claude --version`
4. 跑短驗證：`./autonomous_cli_loop.sh quick_test 1`（max-iter 1）
5. 修議題 #1：加 puppeteer MCP 進 bash 腳本 settings.json allowlist
6. 重跑 5 features full：`./autonomous_cli_loop.sh test_with_mcp 5`
7. 看 feature 通過率有沒有突破

## 重要紀錄：成本

5/23 session 在 autonomous-coding-sub 累計訂閱用量：

| Run | sessions | cost (USD 等價) |
|---|---|---|
| test_sub_run (max-iter 1) | 1 init | ~$0.30 |
| five_demo_bash (失敗) | 1 partial init | ~$0.50 |
| five_demo_v2 (path bug) | ~0（早 abort）| <$0.10 |
| five_demo_v3 (full) | 1 init + 3 coding | ~$3.69 |
| **合計** | | **~$4.59** |

跑 Claude.ai clone 規模的 spec full features 完整流程，建議預留 USD $10-20 等價的訂閱配額。

## 同 session 姐妹專案

`../financial-data-analyst-sub/` — 另一個訂閱版分支（TS SDK web app）。已完整成功，5/5 tests + browser E2E PASS。內容詳見該專案的 `CLAUDE.md` + `doc/session-handoff.md`。
