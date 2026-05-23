# autonomous-coding-sub — Claude Code 專案指引

> 給 Claude Code 開此目錄當專案根時的簡報。讀完應該能直接接手繼續工作，不需要回問使用者。

## 這是什麼

`anthropic/anthropic-quickstarts/autonomous-coding` 的**訂閱版分支**，不扣 API Credits，走 `claude` CLI 的 OAuth 用 Pro/Max 訂閱額度。

兩個入口：

| 入口 | 用途 | 完整功能 |
|---|---|---|
| `autonomous_agent_demo.py` | Python harness，完整功能（sandbox / security hook / MCP）| ✅ |
| `autonomous_cli_loop.sh` | bash 版本，輕量但缺 MCP 預配置 | ⚠️ 缺 browser MCP allowlist |

## 跟原版（`../autonomous-coding`）的差異

| 面向 | 原版 | 本 sub |
|---|---|---|
| 認證 | `ANTHROPIC_API_KEY` hard-check | `claude` CLI OAuth |
| 扣費 | API Credits | Pro/Max 訂閱額度 |
| 主要改動檔 | — | `autonomous_agent_demo.py` line 80-85、`client.py` line 57-62 都改 |
| 啟動行為 | 沒 key 就 `return` | 主動 `os.environ.pop` 清掉 env 強制 OAuth |
| bash verbose | 無 | `autonomous_cli_loop.sh` 加了 `--output-format stream-json --verbose` + `scripts/parse_claude_stream.py` parser |
| `.gitignore` | 基本 | 加 `*.log` `*_run.log` |

## 啟動方式

### Python 版（功能完整）

```bash
# 必設環境變數
DISABLE_WRITER_QA_HOOK=1 PYTHONUTF8=1 \
  python autonomous_agent_demo.py \
  --project-dir ./test_run \
  --max-iterations 6
```

### Bash 版（含 verbose tool 可見性）

```bash
./autonomous_cli_loop.sh five_demo 5
```

- 第 1 個參數：專案名（在 `generations/` 底下）
- 第 2 個參數：max coding 迭代數（不含 initializer session）
- 環境變數可覆寫：`MODEL` `DRY_RUN` `SLEEP_INTERVAL` `STALL_LIMIT`

## 必設環境變數（鐵律）

| 變數 | 設法 | 為什麼 |
|---|---|---|
| `DISABLE_WRITER_QA_HOOK=1` | **每次**執行前設 | 巢狀 agent 寫 `.sh`/`.py` 會被全域三 agent 鐵律 hook 攔截。Python 版必設；bash 版內建會設 |
| `ANTHROPIC_API_KEY` | **不要設**（或設空字串）| 一旦設了 SDK / CLI 會優先走 API 模式變成扣 Credits。Python 版會 `os.environ.pop`；bash 版會印警告但仍會走 API |
| `PYTHONUTF8=1` | 跑 Python 時設 | Windows cp950 編碼會炸繁中字串 |

## 已知議題（重要 — 開工前讀）

### 議題 1：bash 版 0/N features 通過（5/23 演練實證）

`.claude/settings.json` 的 `permissions.allow` 沒包 `mcp__chrome-devtools__*` 或 `mcp__puppeteer__*`，agent 想驗 UI 時被擋 → 改不動 `feature_list.json` → stall detection 自動 abort。

**修法**：把 bash 腳本的 settings.json allow list 補上 puppeteer MCP（參考 Python 版 `client.py:19-27` 的 `PUPPETEER_TOOLS` 清單）+ spawn `npx puppeteer-mcp-server` 在 bash 啟動時。

### 議題 2：Windows Python SDK「Stream closed」不穩

Python 版 `claude_code_sdk` 透過 stdin/stdout 跟 spawn 出的 `claude` 子行程通訊。Windows 上 stream 偶發中斷：

- 短任務（max-iter 1）：agent 完成才出錯，filesystem 已落地，funcationally OK
- 長任務（max-iter 6）：agent 寫到一半 stream 斷 → python 主迴圈卡在 `await receive_response()` idle 不動

bash 版**沒這個問題**（每 session 獨立 process），是長任務的首選。

### 議題 3：Windows OS Sandbox 失效

`client.py` 開 `sandbox.enabled = true`，但 Claude Code 對 Windows 不支援 sandbox → silently 失敗。三層防禦（sandbox / permissions / hook）剩兩層。

## 重要檔案

| 路徑 | 用途 |
|---|---|
| `autonomous_agent_demo.py` | Python 入口 |
| `client.py` | SDK client 配置 + sandbox + hooks |
| `agent.py` | core agent loop |
| `security.py` | bash command 白名單（PreToolUse hook）|
| `autonomous_cli_loop.sh` | bash 入口 |
| `scripts/parse_claude_stream.py` | stream-json → 人類可讀 parser（bash 版 verbose 用）|
| `prompts/initializer_prompt.md` | initializer agent prompt（**目前是 5 features 演練版**，非 200 features 原始版）|
| `prompts/coding_prompt.md` | coding session prompt |
| `prompts/app_spec.txt` | 要建的 App spec（預設 Claude.ai clone）|
| `doc/session-handoff.md` | 跨 session 工作交接 |
| `doc/subscription-version-notes.md` | 訂閱版完整架構筆記 |

## 演練輸出

`generations/` 目錄（gitignored）放每次跑的 generated app。每次跑會在裡面建一個專案名子目錄，含 agent 寫的所有檔案 + 各自的 `.git`。要清磁碟空間直接 `rm -rf generations/`。

## 跨機器同步

- 路徑硬編碼禁忌：腳本用 `$SCRIPT_DIR`、Python 用 `pathlib.Path.home()`
- bash → Windows Python：必須 `cygpath -w` 轉路徑（已在 `autonomous_cli_loop.sh` line 54 用）

## 接續工作建議優先順序

1. **先解決議題 1**：補 bash 版 .claude/settings.json allow list 含 MCP browser tools
2. **驗證 puppeteer-mcp-server 安裝**：`npx puppeteer-mcp-server` 能起來
3. **重跑 5 features full**：看能否真的把 features 通過
4. **若 features 通過率還是低**：考慮把 prompts/initializer_prompt.md 改回 spec 對齊（5 features 對 Claude.ai clone 這種大 spec 太少）
