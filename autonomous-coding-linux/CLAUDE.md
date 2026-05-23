# autonomous-coding-linux — Claude Code 專案指引（Linux 版）

> Linux 相容版。原 Windows 版在 `../autonomous-coding-sub/`，請勿修改那份。

## 這是什麼

`autonomous-coding-sub` 的 **Linux 相容版**。差異如下：

| 面向 | Windows 版（autonomous-coding-sub） | Linux 版（此目錄） |
|---|---|---|
| 路徑轉換 | `cygpath -w` 轉 MSYS2→Windows | 直接用原生路徑 |
| Python 指令 | `python` | `python3` |
| UTF-8 設定 | `PYTHONUTF8=1` | 不需要（Linux 預設 UTF-8）|
| Prompt 變數 | `INITIALIZER_PROMPT_WIN` / `CODING_PROMPT_WIN` | `INITIALIZER_PROMPT` / `CODING_PROMPT` |
| settings.json | 含 `powershell.exe`、`taskkill`、`tasklist`、`findstr`、`cmd`、`where`、`type` | 移除以上，改加 `ss`、`ps`、`find`、`xargs`、`pip3` |

## VPS / 無頭伺服器注意事項

### 認證（最重要）

Claude CLI 在無頭 Linux 伺服器上無法開啟瀏覽器做 OAuth 認證。兩個選項：

**選項 A：API Key（推薦 VPS 用）**

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
# 警告：走 API Credits 計費，不是 Max 訂閱額度
```

**選項 B：OAuth（需要有頭環境先認證）**

在有瀏覽器的機器上先跑 `claude` 完成 OAuth，再把 `~/.claude/` 複製到 VPS。
Token 有效期 ~1-2 小時，長任務會中斷。

### Puppeteer 依賴

VPS 跑 puppeteer 需先安裝 Chrome headless 依賴：

```bash
# Ubuntu/Debian
sudo apt-get install -y \
  libnspr4 libnss3 libatk1.0-0 libatk-bridge2.0-0 \
  libcups2 libdrm2 libxkbcommon0 libxcomposite1 \
  libxdamage1 libxfixes3 libxrandr2 libgbm1 libasound2
```

驗證：`npx puppeteer-mcp-server --version`

### Node.js / npm

```bash
# 確認版本
node --version   # 需 >= 18
npm --version

# 全局安裝 Claude Code
npm install -g @anthropic-ai/claude-code
```

## 啟動方式

```bash
# 標準啟動
./autonomous_cli_loop.sh [專案名稱] [最大coding迭代數]

# 用 API Key（VPS 常用）
ANTHROPIC_API_KEY="sk-ant-..." ./autonomous_cli_loop.sh my_project 10

# 乾跑（只檢查不執行）
DRY_RUN=1 ./autonomous_cli_loop.sh

# 覆寫模型
MODEL=claude-haiku-4-5-20251001 ./autonomous_cli_loop.sh my_project 20
```

## 必設環境變數

| 變數 | 設法 | 原因 |
|---|---|---|
| `DISABLE_WRITER_QA_HOOK=1` | 每次執行前設（或加到啟動指令）| 巢狀 agent 寫 `.sh`/`.py` 會被全域三 agent 鐵律 hook 攔截 |
| `ANTHROPIC_API_KEY` | VPS：設真實 key；個人機：不設（走 OAuth）| CLI 偵測到 key 就走 API Credits 計費 |

## 重要檔案

| 路徑 | 用途 |
|---|---|
| `autonomous_cli_loop.sh` | 主入口（Linux 版）|
| `scripts/parse_claude_stream.py` | stream-json → 可讀格式 parser（與 Windows 版相同）|
| `prompts/initializer_prompt.md` | Session 1 prompt |
| `prompts/coding_prompt.md` | Session 2+ prompt |
| `prompts/app_spec.txt` | App 規格（Claude.ai clone）|

## 演練輸出

`generations/` 目錄（gitignored）放每次跑的 generated app。
