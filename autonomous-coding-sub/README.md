# Autonomous Coding Agent Demo — Subscription Edition｜自主編碼 Agent 範例（訂閱版）

> 🔀 這是 [autonomous-coding](../autonomous-coding/) 的**訂閱版分支**。原版強制要 `ANTHROPIC_API_KEY` 扣 API Credits；本版本走 `claude` CLI 的 OAuth，使用你的 **Pro/Max 訂閱額度**，不扣 API Credits。架構細節見 [`doc/subscription-version-notes.md`](doc/subscription-version-notes.md)。

A minimal harness demonstrating long-running autonomous coding with the Claude Agent SDK. This demo implements a two-agent pattern (initializer + coding agent) that can build complete applications over multiple sessions.

> 一個最精簡的 harness（驅動外殼程式），用來示範如何透過 Claude Agent SDK 進行「長時間運行的自主編碼」。這個範例實作了**雙 Agent 模式**（初始化 Agent ＋ 編碼 Agent），能夠跨多個 session 打造出完整的應用程式。

## ⚠️ Self-Host Only 與訂閱用量警告

- 本版只能本機跑（要 `claude` CLI + OAuth 憑證），無法部署到任何 serverless 平台。
- **每 session 都會重新 warm-up SDK ~25-30 秒**（cache miss）。完整 200 features run 額外 1-2 小時純 overhead。
- **強烈建議用演練模式（5 features）跑**，避免猛吃訂閱額度。`prompts/initializer_prompt.md` 預設已是 5 features 演練版。
- Pro/Max 訂閱每週有用量上限，跑完整 200 features 大概率會撞牆。

## Prerequisites｜事前準備

**Required:** 安裝 Claude Code CLI 並完成 OAuth 登入：

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Install Python dependencies
pip install -r requirements.txt

# 確認 CLI 已登入（必須）
claude --version          # 應印 2.1.x (Claude Code)
echo "hi" | claude -p     # 秒回代表 OAuth 活著
```

**不需要 `ANTHROPIC_API_KEY`**。本版啟動時會主動 `os.environ.pop` 清掉它（即使你的 shell 有設），強制 SDK 走 OAuth。詳見 `autonomous_agent_demo.py` 的 `main()` 開頭。

## 與原版差異一覽｜vs Upstream

| 面向 | 原版（`../autonomous-coding`）| 訂閱版（本版）|
|---|---|---|
| 認證 | `ANTHROPIC_API_KEY`（hard-check）| `claude` CLI OAuth（自動 pop 掉 env）|
| 扣費 | API Credits | Pro/Max 訂閱額度（不扣 Credits）|
| 啟動時 | 沒 key 就 `return` 不跑 | 自動 pop env、log 模式|
| `client.py` hard-check | `ValueError` if no key | 移除，改 log 訊息 |
| 首次延遲 | ~1-2 秒 | ~25-30 秒（SDK warm-up）|
| 後續每 session | ~1 秒 | ~25-30 秒（每 session cache miss）|
| 部署 | 無限制 | **Self-host only** |
| 用量上限 | API account credits | 訂閱週用量（Pro 5h/Max 25h）|

## 啟動：演練模式（推薦）

```bash
# 跑 1 圈（只跑 initializer 產 feature_list.json）
DISABLE_WRITER_QA_HOOK=1 python autonomous_agent_demo.py \
  --project-dir ./test_run \
  --max-iterations 1

# 跑 5 features 完整：initializer + 5 coding sessions
DISABLE_WRITER_QA_HOOK=1 python autonomous_agent_demo.py \
  --project-dir ./five_demo \
  --max-iterations 6
```

`DISABLE_WRITER_QA_HOOK=1` 是必設的 —— 否則巢狀 agent 寫 `.sh`/`.py` 會被全域三 agent 鐵律 hook 攔截而卡死（MEMORY 已記）。

## Quick Start｜快速開始

```bash
python autonomous_agent_demo.py --project-dir ./my_project
```

For testing with limited iterations:

> 若要限制迭代次數來做測試：

```bash
python autonomous_agent_demo.py --project-dir ./my_project --max-iterations 3
```

## Important Timing Expectations｜重要的執行時間預期

> **Warning: This demo takes a long time to run!**

> **警告：這個範例會跑很久！**

- **First session (initialization):** The agent generates a `feature_list.json` with 200 test cases. This takes several minutes and may appear to hang - this is normal. The agent is writing out all the features.

- **Subsequent sessions:** Each coding iteration can take **5-15 minutes** depending on complexity.

- **Full app:** Building all 200 features typically requires **many hours** of total runtime across multiple sessions.

> - **第一個 session（初始化）：** agent 會產生一份含 200 個測試案例的 `feature_list.json`。這會花上好幾分鐘，過程中看起來像當機——這是正常的，agent 正在把所有功能寫出來。
> - **後續的 session：** 每一輪編碼依複雜度不同，可能花上 **5～15 分鐘**。
> - **完整應用：** 把全部 200 個功能做完，跨多個 session 加總通常需要**好幾個小時**的執行時間。

**Tip:** The 200 features parameter in the prompts is designed for comprehensive coverage. If you want faster demos, you can modify `prompts/initializer_prompt.md` to reduce the feature count (e.g., 20-50 features for a quicker demo).

> **提示：** 提示詞裡的「200 個功能」是為了完整覆蓋而設計的。如果想跑快一點的示範，可以修改 `prompts/initializer_prompt.md`，把功能數量調低（例如改成 20～50 個就會快很多）。

## How It Works｜運作方式

### Two-Agent Pattern｜雙 Agent 模式

1. **Initializer Agent (Session 1):** Reads `app_spec.txt`, creates `feature_list.json` with 200 test cases, sets up project structure, and initializes git.

2. **Coding Agent (Sessions 2+):** Picks up where the previous session left off, implements features one by one, and marks them as passing in `feature_list.json`.

> 1. **初始化 Agent（第 1 個 session）：** 讀取 `app_spec.txt`，建立含 200 個測試案例的 `feature_list.json`，搭建專案結構，並初始化 git。
> 2. **編碼 Agent（第 2 個 session 起）：** 接續上一個 session 的進度，逐一實作功能，並在 `feature_list.json` 中把完成的功能標記為通過（passing）。

### Session Management｜Session 管理

- Each session runs with a fresh context window
- Progress is persisted via `feature_list.json` and git commits
- The agent auto-continues between sessions (3 second delay)
- Press `Ctrl+C` to pause; run the same command to resume

> - 每個 session 都以全新的 context window 執行。
> - 進度透過 `feature_list.json` 與 git commit 來保存。
> - agent 會在 session 之間自動接續（間隔 3 秒）。
> - 按 `Ctrl+C` 可暫停；重新執行同一條指令即可繼續。

## Security Model｜安全模型

This demo uses a defense-in-depth security approach (see `security.py` and `client.py`):

> 這個範例採用「縱深防禦」的安全策略（詳見 `security.py` 與 `client.py`）：

1. **OS-level Sandbox:** Bash commands run in an isolated environment
2. **Filesystem Restrictions:** File operations restricted to the project directory only
3. **Bash Allowlist:** Only specific commands are permitted:
   - File inspection: `ls`, `cat`, `head`, `tail`, `wc`, `grep`
   - Node.js: `npm`, `node`
   - Version control: `git`
   - Process management: `ps`, `lsof`, `sleep`, `pkill` (dev processes only)

Commands not in the allowlist are blocked by the security hook.

> 1. **作業系統層級沙箱：** Bash 指令在隔離的環境中執行。
> 2. **檔案系統限制：** 檔案操作只能在專案目錄內進行。
> 3. **Bash 白名單：** 只允許特定指令：
>    - 檔案檢視：`ls`、`cat`、`head`、`tail`、`wc`、`grep`
>    - Node.js：`npm`、`node`
>    - 版本控制：`git`
>    - 程序管理：`ps`、`lsof`、`sleep`、`pkill`（僅限開發用程序）
>
> 不在白名單內的指令會被安全 hook 攔截封鎖。

## Project Structure｜專案結構

```
autonomous-coding/
├── autonomous_agent_demo.py  # Main entry point
├── agent.py                  # Agent session logic
├── client.py                 # Claude SDK client configuration
├── security.py               # Bash command allowlist and validation
├── progress.py               # Progress tracking utilities
├── prompts.py                # Prompt loading utilities
├── prompts/
│   ├── app_spec.txt          # Application specification
│   ├── initializer_prompt.md # First session prompt
│   └── coding_prompt.md      # Continuation session prompt
└── requirements.txt          # Python dependencies
```

> 各檔案說明：
> - `autonomous_agent_demo.py`：主程式進入點
> - `agent.py`：Agent session 的邏輯
> - `client.py`：Claude SDK 客戶端設定
> - `security.py`：Bash 指令白名單與驗證
> - `progress.py`：進度追蹤工具
> - `prompts.py`：提示詞載入工具
> - `prompts/app_spec.txt`：應用程式規格
> - `prompts/initializer_prompt.md`：第一個 session 的提示詞
> - `prompts/coding_prompt.md`：續做 session 的提示詞
> - `requirements.txt`：Python 套件相依清單

## Generated Project Structure｜產出的專案結構

After running, your project directory will contain:

> 執行完成後，你的專案目錄會包含：

```
my_project/
├── feature_list.json         # Test cases (source of truth)
├── app_spec.txt              # Copied specification
├── init.sh                   # Environment setup script
├── claude-progress.txt       # Session progress notes
├── .claude_settings.json     # Security settings
└── [application files]       # Generated application code
```

> 各檔案說明：
> - `feature_list.json`：測試案例（進度的單一事實來源 / source of truth）
> - `app_spec.txt`：複製進來的規格檔
> - `init.sh`：環境設定腳本
> - `claude-progress.txt`：session 進度筆記
> - `.claude_settings.json`：安全設定
> - `[application files]`：產出的應用程式程式碼

## Running the Generated Application｜執行產出的應用程式

After the agent completes (or pauses), you can run the generated application:

> agent 完成（或暫停）後，你可以執行產出的應用程式：

```bash
cd generations/my_project

# Run the setup script created by the agent
./init.sh

# Or manually (typical for Node.js apps):
npm install
npm run dev
```

The application will typically be available at `http://localhost:3000` or similar (check the agent's output or `init.sh` for the exact URL).

> 應用程式通常會在 `http://localhost:3000` 之類的網址啟動（確切網址請看 agent 的輸出或 `init.sh`）。

## Command Line Options｜命令列參數

| Option 參數 | Description 說明 | Default 預設值 |
|--------|-------------|---------|
| `--project-dir` | Directory for the project｜專案目錄 | `./autonomous_demo_project` |
| `--max-iterations` | Max agent iterations｜agent 最大迭代次數 | Unlimited｜無限制 |
| `--model` | Claude model to use｜要使用的 Claude 模型 | `claude-sonnet-4-5-20250929` |

## Customization｜客製化

### Changing the Application｜更換要打造的應用程式

Edit `prompts/app_spec.txt` to specify a different application to build.

> 編輯 `prompts/app_spec.txt`，即可指定要打造的另一種應用程式。

### Adjusting Feature Count｜調整功能數量

Edit `prompts/initializer_prompt.md` and change the "200 features" requirement to a smaller number for faster demos.

> 編輯 `prompts/initializer_prompt.md`，把「200 個功能」的要求改成較小的數字，示範就會跑得更快。

### Modifying Allowed Commands｜修改允許的指令

Edit `security.py` to add or remove commands from `ALLOWED_COMMANDS`.

> 編輯 `security.py`，在 `ALLOWED_COMMANDS` 中新增或移除指令。

## Troubleshooting｜疑難排解

**"Appears to hang on first run"**
This is normal. The initializer agent is generating 200 detailed test cases, which takes significant time. Watch for `[Tool: ...]` output to confirm the agent is working.

> **「第一次執行時看起來像當機」**
> 這是正常的。初始化 agent 正在產生 200 個詳細的測試案例，會花不少時間。觀察 `[Tool: ...]` 的輸出，就能確認 agent 仍在運作。

**"Command blocked by security hook"**
The agent tried to run a command not in the allowlist. This is the security system working as intended. If needed, add the command to `ALLOWED_COMMANDS` in `security.py`.

> **「指令被安全 hook 封鎖」**
> agent 嘗試執行了不在白名單內的指令。這代表安全系統正按預期運作。若有需要，可在 `security.py` 的 `ALLOWED_COMMANDS` 中加入該指令。

**"API key not set"**
Ensure `ANTHROPIC_API_KEY` is exported in your shell environment.

> **「API 金鑰未設定」**
> 請確認 `ANTHROPIC_API_KEY` 已在你的 shell 環境中設定（export）。

## License｜授權

Internal Anthropic use.

> 僅供 Anthropic 內部使用。
