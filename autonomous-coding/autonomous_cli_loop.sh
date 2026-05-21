#!/bin/bash
set -euo pipefail

# ==============================================================================
# autonomous_cli_loop.sh
#
# autonomous_agent_demo.py 的 CLI 等價版。
#
# 原版用 Python + Claude Agent SDK 驅動「雙角色自主編碼」迴圈；本腳本改用
# claude CLI（claude -p）直接驅動，不依賴 Python SDK，只用 python 解析 JSON。
#
# 雙角色 pattern：
#   - Session 1（initializer）：讀 app_spec.txt → 生成 feature_list.json 等。
#   - Session 2+（coding）：讀 feature_list.json → 實作一個 feature → 標記 passes。
# 每個 session 都是全新 context；狀態靠 feature_list.json + git 外部化，
# 不靠對話延續（故意不用 claude --continue，見下方註解）。
#
# 用法：
#   ./autonomous_cli_loop.sh [專案名稱] [最大coding迭代數]
#   DRY_RUN=1 ./autonomous_cli_loop.sh    # 乾跑：只做檢查與設定，不真的呼叫 claude
#   MODEL=claude-opus-4-6 ./autonomous_cli_loop.sh   # 覆寫模型
# ==============================================================================

# --- 參數與變數 --------------------------------------------------------------

# $1：專案名稱（決定 generations/ 底下的子目錄），預設 cli_demo
PROJECT_NAME="${1:-cli_demo}"

# $2：coding 迴圈最大迭代數（initializer session 不計入），預設 30
MAX_ITER="${2:-30}"

# 模型：可用環境變數 MODEL 覆寫，否則用 Sonnet 4.5
MODEL="${MODEL:-claude-sonnet-4-5-20250929}"

# DRY_RUN：環境變數，設為 1 時進乾跑模式（只做檢查與設定，不呼叫 claude）
DRY_RUN="${DRY_RUN:-0}"

# SCRIPT_DIR：腳本自我定位，避免硬編碼 C:\Users\... 路徑
# 用 BASH_SOURCE 取得腳本本身位置，再 cd 進去取絕對路徑。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PROMPTS_DIR="$SCRIPT_DIR/prompts"
PROJECT_DIR="$SCRIPT_DIR/generations/$PROJECT_NAME"

# --- 前置檢查（preflight） ---------------------------------------------------
# 任一硬性檢查失敗：印繁中錯誤訊息到 stderr 並 exit 1。

# claude CLI 必須存在，否則整個迴圈無法驅動。
if ! command -v claude >/dev/null 2>&1; then
  echo "錯誤：找不到 claude CLI，請先安裝 Claude Code（npm install -g @anthropic-ai/claude-code）。" >&2
  exit 1
fi

# python 用來解析 feature_list.json，沒有就無法計算剩餘 feature 數。
if ! command -v python >/dev/null 2>&1; then
  echo "錯誤：找不到 python，本腳本需要 python 來解析 feature_list.json。" >&2
  exit 1
fi

# 三個 prompt 檔缺一不可。
if [ ! -f "$PROMPTS_DIR/initializer_prompt.md" ]; then
  echo "錯誤：缺少 $PROMPTS_DIR/initializer_prompt.md。" >&2
  exit 1
fi

if [ ! -f "$PROMPTS_DIR/coding_prompt.md" ]; then
  echo "錯誤：缺少 $PROMPTS_DIR/coding_prompt.md。" >&2
  exit 1
fi

if [ ! -f "$PROMPTS_DIR/app_spec.txt" ]; then
  echo "錯誤：缺少 $PROMPTS_DIR/app_spec.txt。" >&2
  exit 1
fi

# ANTHROPIC_API_KEY 警告（非致命，不 exit）：
# claude CLI 一旦偵測到 ANTHROPIC_API_KEY，會優先走 API Credits 計費，
# 而非免費的 Max 訂閱額度。此迴圈會跑數十次 session，成本差異可觀。
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  echo "警告：偵測到 ANTHROPIC_API_KEY，claude CLI 會改走 API Credits 計費（付費）。" >&2
  echo "      若要用 Max 訂閱額度（免費），請先執行 unset ANTHROPIC_API_KEY 再跑本腳本。" >&2
fi

# --- 設定階段 ----------------------------------------------------------------

# 建立專案目錄。
mkdir -p "$PROJECT_DIR"

# 複製 app_spec.txt 進專案目錄，讓 claude 從 cwd（PROJECT_DIR）直接讀得到。
cp "$PROMPTS_DIR/app_spec.txt" "$PROJECT_DIR/app_spec.txt"

# 寫入專案層級 .claude/settings.json：每次執行覆寫即可。
# 此設定給 claude 子程序自動 accept 編輯權限 + 白名單常用工具，
# 讓自主迴圈不會卡在權限確認。
mkdir -p "$PROJECT_DIR/.claude"
cat > "$PROJECT_DIR/.claude/settings.json" <<'EOF'
{
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": ["Read", "Write", "Edit", "Glob", "Grep", "Bash(npm:*)", "Bash(node:*)", "Bash(git init:*)", "Bash(git add:*)", "Bash(git commit:*)", "Bash(git status:*)", "Bash(git diff:*)", "Bash(git log:*)", "Bash(ls:*)", "Bash(cat:*)", "Bash(mkdir:*)", "Bash(head:*)", "Bash(tail:*)", "Bash(wc:*)", "Bash(grep:*)", "Bash(pwd)", "Bash(cp:*)"]
  }
}
EOF

# --- 計數 helper -------------------------------------------------------------

# count_remaining：印出「passes 不為 true 的 feature 數」到 stdout。
# 用 python 解析當前 cwd 下的 feature_list.json。
# 若檔案不存在 / JSON 解析失敗，python 會非零退出並把錯誤印到 stderr，
# 呼叫端可用 || 分支判斷（見主流程）。
count_remaining() {
  python -c "import json; print(sum(1 for f in json.load(open('feature_list.json',encoding='utf-8')) if not f.get('passes',False)))"
}

# --- 主流程 ------------------------------------------------------------------

# 進入專案目錄：claude 一律在 PROJECT_DIR 內執行，cwd 即為它的工作根目錄。
cd "$PROJECT_DIR"

echo "=============================================================="
echo " 自主編碼 CLI 迴圈"
echo "  專案目錄：$PROJECT_DIR"
echo "  模型：$MODEL"
echo "  最大 coding 迭代數：$MAX_ITER"
if [ "$DRY_RUN" = "1" ]; then
  echo "  模式：DRY-RUN（不會真的呼叫 claude）"
fi
echo "=============================================================="

# DISABLE_WRITER_QA_HOOK=1 的理由：
#   本腳本會以子程序呼叫 claude，而子程序會繼承使用者全域 ~/.claude/ 設定，
#   其中包含「程式碼三 agent 鐵律」hook（enforce_writer_qa.py）。該 hook 會
#   攔截 .sh / .py 等程式碼檔的 Write/Edit。若不停用，巢狀 agent 在迴圈內
#   寫程式碼會被攔截而卡死（演練實測踩過）。此處明確停用該 hook。

# Session 1（initializer）：只在 feature_list.json 尚未存在時跑一次。
if [ ! -f "feature_list.json" ]; then
  echo ""
  echo "--- Session 1：initializer（讀 app_spec → 生成 feature_list.json） ---"
  if [ "$DRY_RUN" = "1" ]; then
    echo "[DRY-RUN] 將執行：DISABLE_WRITER_QA_HOOK=1 claude -p --model '$MODEL' --permission-mode acceptEdits --max-turns 200 < '$PROMPTS_DIR/initializer_prompt.md'"
  else
    # prompt 用 stdin 重導向餵入，不當命令列參數：
    # Git Bash（MSYS2）命令列長度上限約 32KB，prompt 檔變長時用 "$(cat ...)"
    # 當單一 argument 會觸發「Argument list too long」或被截斷而靜默失敗。
    # claude -p 不給位置參數時會改從 stdin 讀，繞過參數長度上限。
    #
    # 用 if ! ... 包裹的理由：if 條件位置的指令不受 set -e 中止，
    # 因此 claude 非零退出時能落到 then 分支印診斷訊息再 exit，
    # 而不是被 set -e 直接 silent exit、讓使用者隔天看不出跑到第幾圈。
    if ! DISABLE_WRITER_QA_HOOK=1 claude -p \
      --model "$MODEL" \
      --permission-mode acceptEdits \
      --max-turns 200 \
      < "$PROMPTS_DIR/initializer_prompt.md"; then
      echo "錯誤：initializer session 非零退出（可能 rate limit / max-turns 耗盡 / auth 過期 / 網路中斷）。中止迴圈。" >&2
      exit 1
    fi
  fi
else
  echo ""
  echo "--- Session 1：略過（feature_list.json 已存在，沿用既有進度） ---"
fi

# Session 2+（coding 迴圈）：每圈跑一個全新 context 的 claude session。
# 不用 claude --continue 的理由：autonomous coding pattern 刻意要求每個
# session 都是乾淨 context，避免長對話脈絡污染；session 之間靠
# feature_list.json + git 傳遞狀態，而非靠對話延續。
for i in $(seq 1 "$MAX_ITER"); do
  # DRY_RUN：在讀 feature_list.json 之前就攔截。
  # 乾跑模式下 initializer 沒真的執行，feature_list.json 不存在，
  # 若先呼叫 count_remaining 會解析失敗而誤判 exit 1。故 guard 必須是
  # for 迴圈內第一個動作，早於任何 count_remaining 呼叫。
  if [ "$DRY_RUN" = "1" ]; then
    echo ""
    echo "--- coding 迴圈（DRY-RUN 示意，不讀 feature_list.json） ---"
    echo "[DRY-RUN] 將執行：DISABLE_WRITER_QA_HOOK=1 claude -p --model '$MODEL' --permission-mode acceptEdits --max-turns 200 < '$PROMPTS_DIR/coding_prompt.md'"
    # 乾跑時不真的跑迴圈，印一次示意指令後即跳出。
    break
  fi

  # 算剩餘 feature 數；feature_list.json 缺失或損毀時，count_remaining 失敗。
  if remaining="$(count_remaining 2>/dev/null)"; then
    :
  else
    echo "錯誤：無法解析 feature_list.json（檔案不存在或格式錯誤），中止 coding 迴圈。" >&2
    exit 1
  fi

  # 全部 feature 通過 → 完成，跳出迴圈。
  if [ "$remaining" -eq 0 ]; then
    echo ""
    echo "全部 feature 通過，自主編碼完成。"
    break
  fi

  echo ""
  echo "--- Session $((i + 1))：coding（第 $i/$MAX_ITER 圈，剩餘 $remaining 個 feature） ---"

  # prompt 用 stdin 重導向餵入，不當命令列參數：
  # Git Bash（MSYS2）命令列長度上限約 32KB，prompt 檔變長時用 "$(cat ...)"
  # 當單一 argument 會觸發「Argument list too long」或被截斷而靜默失敗。
  # claude -p 不給位置參數時會改從 stdin 讀，繞過參數長度上限。
  #
  # 用 if ! ... 包裹的理由：if 條件位置的指令不受 set -e 中止，
  # 因此 claude 非零退出時能落到 then 分支印診斷訊息再 exit，
  # 而不是被 set -e 直接 silent exit、讓使用者隔天看不出跑到第幾圈。
  if ! DISABLE_WRITER_QA_HOOK=1 claude -p \
    --model "$MODEL" \
    --permission-mode acceptEdits \
    --max-turns 200 \
    < "$PROMPTS_DIR/coding_prompt.md"; then
    echo "錯誤：第 $i 圈 coding session 非零退出（可能 rate limit / max-turns 耗盡 / auth 過期 / 網路中斷）。剩餘 $remaining 個 feature，中止迴圈。" >&2
    exit 1
  fi

  # 兩個 session 之間稍作停頓，避免連續打 API。
  sleep 3
done

# --- 結尾總結 ----------------------------------------------------------------

if [ "$DRY_RUN" = "1" ]; then
  echo ""
  echo "=============================================================="
  echo " DRY-RUN 結束：preflight 檢查與設定階段完成，未呼叫 claude。"
  echo "  專案目錄：$PROJECT_DIR"
  echo "=============================================================="
  exit 0
fi

# 非乾跑：再算一次剩餘數做總結（feature_list.json 此時應已存在）。
if final_remaining="$(count_remaining 2>/dev/null)"; then
  :
else
  final_remaining="未知（feature_list.json 無法解析）"
fi

echo ""
echo "=============================================================="
echo " 自主編碼 CLI 迴圈結束"
echo "  專案目錄：$PROJECT_DIR"
echo "  剩餘未通過 feature 數：$final_remaining"
echo "=============================================================="
