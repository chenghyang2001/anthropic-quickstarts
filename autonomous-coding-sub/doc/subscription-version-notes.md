# Subscription Edition — 架構筆記

> 從原版 `autonomous-coding/` 分支出來的「不扣 API Credits 版」。
> 建立日期：2026-05-23

## 為什麼有這個分支

原版 Python harness 兩個檔有 hard-coded 的 `ANTHROPIC_API_KEY` 檢查：

- `autonomous_agent_demo.py` 第 80-85 行：沒 key 就 `return` 提早結束
- `client.py` 第 57-62 行：沒 key 就 `raise ValueError`

但底層 `claude_code_sdk` 跟 `financial-data-analyst-sub` 用的 TS Agent SDK 是同家機制（都 wrap `claude` CLI）。CLI 沒看到 API key 就會走 OAuth → 用 Pro/Max 訂閱額度。

**這兩個 hard-check 是「人為阻擋」，不是真實技術障礙。** 移掉就走訂閱模式。

## 三條路徑回顧

`autonomous-coding/` 在 Session 2 已經衍生出 **bash 版訂閱合規版**：`autonomous_cli_loop.sh`。但 bash 版捨棄了 Python harness 的 sandbox / security hook / MCP server 配置。

| 入口 | 認證 | 完整功能 |
|---|---|---|
| `autonomous-coding/autonomous_agent_demo.py`（原版）| API key（強制）| ✅（sandbox + hook + MCP）|
| `autonomous-coding/autonomous_cli_loop.sh`（Session 2 衍生）| OAuth（訂閱）| ❌（簡化版，無 hook / MCP）|
| `autonomous-coding-sub/autonomous_agent_demo.py`（本版）| OAuth（訂閱）| ✅（保留全部 Python harness 能力）|

## 核心改動

### `autonomous_agent_demo.py`

**移除**（line 80-85）：
```python
if not os.environ.get("ANTHROPIC_API_KEY"):
    print("Error: ANTHROPIC_API_KEY environment variable not set")
    ...
    return
```

**新增**（同位置）：
```python
if os.environ.pop("ANTHROPIC_API_KEY", None):
    print("[Subscription mode] Detected ANTHROPIC_API_KEY in env — removed ...")
else:
    print("[Subscription mode] No ANTHROPIC_API_KEY — will use claude CLI OAuth ...")
```

主動 pop 的關鍵：即使使用者的 shell 環境有設 `ANTHROPIC_API_KEY`，啟動瞬間就清掉，避免 SDK spawn `claude` CLI 時 CLI 看到 env 走 API 模式。

### `client.py`

**移除**（line 57-62）：
```python
api_key = os.environ.get("ANTHROPIC_API_KEY")
if not api_key:
    raise ValueError("ANTHROPIC_API_KEY environment variable not set...")
```

**新增**（同位置）：
```python
print("[client] Subscription mode — claude CLI will use OAuth via ~/.claude/.credentials.json")
```

順手移除 line 9 的 `import os`（unused after change，pyflakes 會抱怨）。

## process-wide pop 在這個專案的安全性

`financial-data-analyst-sub` 的 reviewer 強調過 `os.environ.pop`（process-wide mutation）在 Next.js Node runtime 並發 request 下會污染其他 route。但 **autonomous-coding 是單 process CLI 工具**：

- 沒有並發 request
- 一個 process 只跑一條主迴圈
- 不會有其他「同 process 同時需要 ANTHROPIC_API_KEY」的程式碼

→ process-wide pop 在這裡是**乾淨可接受**的。不需要 request-scoped env 隔離。

## 三 agent 流程紀錄

走 code-writer → code-qa（簡單複雜度 / 2 test case / 不派 reviewer）：

- **Writer**：兩個檔各 ~9 行改動，產出 SHA fa96... + 1b89...
- **QA**：V1-V4 + 2 test case 全 PASS；V5 抓到 client.py 多了一行 `import os` unused
- **主 Claude 小修豁免**：直接 Edit 移除該行（1 行）
- **重驗 V3/V5 全綠**

## 已知限制

### 1. Windows OS 沙箱層失效
`security_settings` 開了 `sandbox.enabled = true`，但 Claude Code 對 Windows 不支援 sandbox。會 silently 失敗 → 三層防禦（sandbox / permissions / hook）剩兩層。本 issue 與訂閱模式無關，bash 版也中招。

### 2. SDK warm-up 每 session 重新付出
每個 coding session 是全新 context，每次都要重新 spawn `claude` CLI、載 ~70k tokens 預設 system prompt。每 session ~25-30 秒 warm-up overhead。200 features 全跑 = 額外 1-2 小時純 overhead。

### 3. 訂閱用量上限
- Pro: ~5 hours/週
- Max: ~25 hours/週
- 跑滿 200 features 大概率撞牆。建議先用 5 features 演練版驗證流程。

### 4. 巢狀 hook 衝突（必設 `DISABLE_WRITER_QA_HOOK=1`）
SDK spawn 出的 claude 子行程會繼承使用者全域 `~/.claude/` 設定，包含「程式碼三 agent 鐵律」hook。該 hook 為「互動式」設計（預期人類確認），放到「自主 agent」環境會卡死。啟動時必須：

```bash
DISABLE_WRITER_QA_HOOK=1 python autonomous_agent_demo.py ...
```

### 5. 沒前端可截圖驗證
不像 financial-data-analyst-sub 有 UI，autonomous-coding 是 CLI tool。驗證手段：

- 看 stdout log（看到「[Subscription mode]」訊息確認 OAuth 路徑啟動）
- 看 `feature_list.json` 是否被建立 + 內容（5 features 演練版）
- 看 git log（agent 是否有 commit）
- 跑 generated app 的 `init.sh` 起來看 output
- 檢查 `console.anthropic.com` Credits 沒動（這是訂閱 vs API 的關鍵差異）

## 啟動方式

```bash
cd autonomous-coding-sub

# 確認 claude CLI 登入：claude --version

# 演練版（5 features，只跑 initializer）
DISABLE_WRITER_QA_HOOK=1 python autonomous_agent_demo.py \
  --project-dir ./test_run \
  --max-iterations 1

# 想跑完整 5 features 演練：max-iterations 6（initializer + 5 coding）
DISABLE_WRITER_QA_HOOK=1 python autonomous_agent_demo.py \
  --project-dir ./five_demo \
  --max-iterations 6
```

## 驗證訂閱模式真的有走 OAuth

跑完後檢查兩件事：

1. **stdout 有印 `[Subscription mode]`** —— 證明啟動時 pop 邏輯啟動
2. **console.anthropic.com Credits 沒動** —— 證明沒走 API 模式
3. （可選）`~/.claude/.credentials.json` 的 `mtime` 應在跑完後接近當下 —— 證明 OAuth 有被使用過
