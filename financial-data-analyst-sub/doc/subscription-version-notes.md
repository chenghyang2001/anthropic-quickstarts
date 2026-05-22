# Subscription Edition — 架構筆記

> 從原版 `financial-data-analyst/` 分支出來的「不扣 API Credits 版」。
> 建立日期：2026-05-23

## 為什麼有這個分支

原版 `app/api/finance/route.ts` 直接打 `api.anthropic.com`（用 `@anthropic-ai/sdk` + `ANTHROPIC_API_KEY`），每次 chart 生成都扣 **API Credits**。

訂閱版改走 `@anthropic-ai/claude-agent-sdk` → spawn `claude` CLI → OAuth → 使用者的 **Pro/Max 訂閱額度**。不需要 API key，不扣 API Credits。

## 核心改動（vs 原版）

| 面向 | 原版 | 訂閱版 |
|---|---|---|
| SDK 套件 | `@anthropic-ai/sdk@^0.29` | `@anthropic-ai/claude-agent-sdk@^0.3` |
| Runtime | Edge | Node.js（SDK 要 spawn child process） |
| 認證 | `ANTHROPIC_API_KEY` 環境變數 | `claude` CLI OAuth（`~/.claude/.credentials.json`） |
| Tool use | 原生 messages.create + `input_schema` | SDK MCP tool（`createSdkMcpServer` + `tool()`） |
| Tool 名稱 | `generate_graph_data` | `mcp__chart__generate_graph_data`（對前端仍 expose 原名） |
| API key 隔離 | n/a | request-scoped `env: { ...process.env, ANTHROPIC_API_KEY: undefined }` |
| Input validation | 鬆散 | zod schema 白名單（model + role） |
| Error 回傳 | leak raw error.message | 分類錯誤碼（CLI_NOT_FOUND / OAUTH_EXPIRED / INTERNAL_ERROR） |
| Port | 3000 | 3001 |

**前端 100% 不動。** route.ts 回傳的 JSON 形狀跟原版完全相同：`{ content, hasToolUse, toolUse, chartData }`。

## 三 agent 流程紀錄

走 code-writer → code-qa → code-reviewer：

- **Writer** 寫出第一版（432 行，SHA256 9408...c3）
- **QA** 5 層全綠 + 3 個 test case 全 PASS（happy / edge / integration）
- **Reviewer** 提 3 個 MUST_FIX + 4 個 NICE_TO_HAVE + 4 個 ARCHITECTURE_CONCERNS
- **Writer 修正版**（484 行，SHA256 4abc...8b）解決全部 must-fix + 4 個 nice-to-have

最終驗證：
- TS compile 0 error / ESLint 0 warning
- 5 個 API test 全 PASS（含 2 個 zod 惡意輸入測試）
- Browser smoke test PASS（見 `smoke-test-screenshot.png`）

## 已知限制（POC 範圍）

### 1. 純文字 only
圖片上傳 UI 保留，但後端跳過並 `console.warn`。原因：SDK 的 `prompt` 只吃字串，無法塞 image block。若要支援圖片：考慮把圖片轉 base64 後嵌進 prompt（效果差）或改走 vision-capable model 的不同 SDK 路徑。

### 2. 多輪對話結構降級
原版用 messages array 結構化送出，model 能清楚看到對話輪次邊界。訂閱版攤平成 `"User: ...\n\nAssistant: ...\n\nUser: ..."` 字串。短對話沒差，5-10 輪以上會降低 chart 工具觸發精準度。

### 3. Localhost-only
SDK spawn `claude` CLI 子行程 → 要本機有 CLI binary + OAuth 憑證。**無法部署到 Vercel / Cloudflare / 任何 serverless 平台**。要部署只能上自己有完整 Claude Code 環境的機器（NUC、VPS 等）。

### 4. 訂閱額度限制
不是「無限免費」。Pro / Max 各有 5 小時/週用量上限。猛測試會被限流。

### 5. 延遲增加
首次呼叫 ~25-30 秒（SDK 載入 + cache warm-up），後續 ~12-17 秒。原版直打 API 約 1-2 秒。要快只能回原版或預熱 SDK。

## Reviewer 標記的架構議題（未來迭代）

POC 階段先不處理，但要記下來：

### A1. messages 攤平丟失結構
- 問題：對話越長越糟
- 解法 1：只把 last user message 當 prompt，先前對話用 systemPrompt 補摘要
- 解法 2：用 SDK 的 session resume（`resume: sessionId`），前端配合存 sessionId

### A2. per-request 重建 MCP server 的 CPU 成本
- 問題：每個 request 重新建 `tool()` + `createSdkMcpServer()`
- 現況：低 QPS POC 沒問題；> 10 req/s 會看到 CPU spike
- 解法：無乾淨解。若想 hoist 到模組頂層共用會立刻打開 closure race condition（不同 request 互相污染 `capturedChartData`）。這是 SDK 限制下的必要成本

### A3. maxTurns: 3 邊界沒測
- 問題：QA 三個 case 都正常 turn 內結束，沒測「Claude 想多輪修正」的情境
- 解法：在 result subtype === `error_max_turns` 時，主動在 content 塞「處理超時，請重試或簡化問題」訊息，避免無聲失敗

### A4. 部署可移植性
- 問題：Vercel deploy 100% 失敗（serverless 沒 claude CLI）
- 解法：在 README / route.ts 檔頭明確標註「self-host only」（已加進此版本 README）

## Tools 一覽

```typescript
import { query, tool, createSdkMcpServer } from '@anthropic-ai/claude-agent-sdk';
import { z } from 'zod';

// 1. tool() 定義工具（name + description + zod schema + handler）
const chartTool = tool('generate_graph_data', '...', { /* zod schema */ }, async (args) => {
  capturedChartData = args;
  return { content: [{ type: 'text', text: 'captured' }] };
});

// 2. createSdkMcpServer() 包成 in-process MCP server
const chartServer = createSdkMcpServer({ name: 'chart', version: '1.0.0', tools: [chartTool] });

// 3. query() 跑 agent loop
for await (const message of query({
  prompt,
  options: {
    model,
    systemPrompt: SYSTEM_PROMPT,            // 字串覆寫 Claude Code 預設 70k tokens
    mcpServers: { chart: chartServer },
    allowedTools: ['mcp__chart__generate_graph_data'],
    tools: [],                              // 空陣列移除所有 built-in tools
    maxTurns: 3,
    env: { ...process.env, ANTHROPIC_API_KEY: undefined } as any,  // request-scoped 強制 OAuth
  },
})) {
  if (message.type === 'assistant') { /* 收集 text */ }
  if (message.type === 'result') { /* 結束 */ break; }
}
```

## 啟動方式

```bash
cd financial-data-analyst-sub
npm install                    # 已裝過跳過
# 確認 claude CLI 登入：claude --version
npm run dev                    # localhost:3001
```

要訂閱版正確走 OAuth，呼叫 API 時 process.env.ANTHROPIC_API_KEY **必須是 undefined / 空**（zod 不檢查，但 SDK 看到會優先走 API 模式）。route.ts 已用 request-scoped env 隔離，parent process 有沒有 key 都沒差。
