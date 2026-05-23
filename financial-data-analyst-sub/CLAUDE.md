# financial-data-analyst-sub — Claude Code 專案指引

> 給 Claude Code 開此目錄當專案根時的簡報。讀完應該能直接接手繼續工作，不需要回問使用者。

## 這是什麼

`anthropic/anthropic-quickstarts/financial-data-analyst` 的**訂閱版分支**，不扣 API Credits，走 `@anthropic-ai/claude-agent-sdk` 透過 `claude` CLI 的 OAuth 用 Pro/Max 訂閱額度。

Next.js 14 App Router 應用：使用者打字 → Claude 分析財務資料 → 自動產生互動式圖表（6 種圖型）。

## 跟原版（`../financial-data-analyst`）的差異

| 面向 | 原版 | 本 sub |
|---|---|---|
| SDK | `@anthropic-ai/sdk@^0.29`（Anthropic API 直連）| `@anthropic-ai/claude-agent-sdk@^0.3`（spawn `claude` CLI）|
| 認證 | `ANTHROPIC_API_KEY` 環境變數 | `claude` CLI OAuth（`~/.claude/.credentials.json`）|
| 扣費 | API Credits | Pro/Max 訂閱額度 |
| Runtime | Edge | Node.js（SDK 要 spawn child process）|
| Port | 3000 | 3001 |
| 部署 | 可上 Vercel | **Self-host only**（雲端沒 claude CLI）|
| 首次延遲 | ~1-2 秒 | ~25-30 秒（SDK warm-up）|
| 後續延遲 | ~1-2 秒 | ~12-17 秒 |
| Input validation | 鬆散 | **zod RequestSchema** 嚴格白名單（model + role）|
| Error 回傳 | leak raw error | 分類錯誤碼（CLI_NOT_FOUND / OAUTH_EXPIRED / INTERNAL_ERROR）|
| 圖片上傳後端 | 可用 | **POC 暫關**（SDK prompt 是 string 不接 image block）|
| 多輪對話 | 結構化 messages array | 攤平字串（POC 範圍）|

## 啟動方式

```bash
cd financial-data-analyst-sub
npm install
# 不需要 .env.local（不用 ANTHROPIC_API_KEY）
# 但要先確認 claude CLI 登入：claude --version + echo "hi" | claude -p
npm run dev
```

開 `http://localhost:3001` 進 chat UI。

## 必設環境

| 變數 | 設法 | 為什麼 |
|---|---|---|
| `ANTHROPIC_API_KEY` | **不要設** | 一旦設了 SDK spawn 的 claude CLI 會優先走 API 模式。route.ts 已用 request-scoped `env` 隔離（line 377），但 shell 不設更安全 |

route.ts 用 `env: { ...process.env, ANTHROPIC_API_KEY: undefined }` 在 SDK options 內隔離 → request-scoped、不污染 parent process。

## 重要檔案

| 路徑 | 用途 |
|---|---|
| `app/api/finance/route.ts` | **訂閱版核心**（重寫過，484 行）— 用 SDK `query()` + custom tool 擷取結構化 chart 輸出 |
| `app/finance/page.tsx` | 前端（**未動，跟原版相同**）|
| `components/ChartRenderer.tsx` | Recharts 渲染（未動）|
| `types/chart.ts` | ChartData 型別（未動）|
| `package.json` | 換掉 `@anthropic-ai/sdk` 為 `@anthropic-ai/claude-agent-sdk` + `zod@^4` |
| `next.config.mjs` | 預設 |
| `.env.local.example` | 訂閱版說明，**不需要 API key** |
| `doc/subscription-version-notes.md` | 完整架構筆記 |
| `doc/session-handoff.md` | 跨 session 工作交接 |
| `doc/smoke-test-screenshot.png` | Browser E2E 驗證證據 |

## 核心技術點（讀懂 route.ts 之前必看）

### 1. SDK 結構化合約

原版用 `anthropic.messages.create({ tools, tool_choice })` 配 input_schema 鎖死圖表 JSON。本版用：

```typescript
const chartTool = tool(
  'generate_graph_data',
  '...',
  { /* zod schema 等同原本的 input_schema */ },
  async (args) => {
    capturedChartData = args;  // closure 變數擷取
    return { content: [{ type: 'text', text: 'Chart data captured' }] };
  }
);
const chartServer = createSdkMcpServer({ name: 'chart', version: '1.0.0', tools: [chartTool] });

for await (const message of query({
  prompt,
  options: {
    model,
    systemPrompt: SYSTEM_PROMPT,
    mcpServers: { chart: chartServer },
    allowedTools: ['mcp__chart__generate_graph_data'],
    tools: [],   // 移除所有 built-in tools (Read/Write/Bash etc)
    maxTurns: 3,
    env: { ...process.env, ANTHROPIC_API_KEY: undefined } as any,
  },
})) { /* ... */ }
```

### 2. 為什麼 chartTool/chartServer 在 POST handler 內建立

避免 concurrent request race condition。capturedChartData 是 POST handler 內的 `let` 宣告 closure 變數，每個 request 各自獨立。**不能** hoist 到模組頂層共用。

### 3. 為什麼前端不動

回傳格式 `{ content, hasToolUse, toolUse, chartData }` 跟原版完全相同。`toolUse.name` 對外仍用 `generate_graph_data`（不含 `mcp__chart__` 前綴）維持 API 契約。

## 已知議題

### 議題 1：圖片上傳後端跳過（POC 範圍）

`utils/fileHandling.ts` 支援 PDF/圖片/CSV 三種，前端 UI 全保留。route.ts 對圖片：

```typescript
} else if (mediaType.startsWith("image/")) {
  console.warn('[POC] Image upload skipped — SDK prompt is string only');
}
```

**解法**：要支援需要把圖片轉 base64 嵌進 prompt 字串（效果差）或改走 vision-capable model 的不同 SDK 路徑。

### 議題 2：多輪對話結構降級

原版用 messages array，model 看得清楚輪次邊界。本版攤平：

```
User: 訊息1
Assistant: 回覆1
User: 訊息2
```

短對話沒差，5-10 輪以上會降低 chart 工具觸發精準度。

**解法**：考慮 SDK 的 session resume（傳 `resume: sessionId`），讓 SDK 自己管 history。

### 議題 3：每 session warm-up ~25-30 秒

SDK spawn `claude` CLI 每次都重載 ~70k tokens 預設 system prompt。雖然 `systemPrompt` 字串覆寫掉，但啟動延遲還是有。

**解法**：暫無。SDK 限制。POC 階段可忍。

### 議題 4：localhost only

無法部署到 Vercel / Cloudflare（雲端沒 claude CLI binary + OAuth 憑證）。

**解法**：要部署需 self-host 在有完整 Claude Code 環境的機器（NUC / VPS / 自己的 server）。

## 已驗證

| 項目 | 結果 |
|---|---|
| TS 編譯 0 errors | ✅ |
| ESLint 0 warnings | ✅ |
| Test 1: Happy（產生 bar chart）| ✅ chartType=bar, data=4 |
| Test 2: Edge（What is 2+2 不畫圖）| ✅ chartData=null, content="Four." |
| Test 3: Integration（多輪 pie chart）| ✅ chartType=pie, data=2 |
| Test 4: Invalid model rejection | ✅ HTTP 400 + 結構化 error |
| Test 5: Invalid role rejection | ✅ HTTP 400 + 結構化 error |
| Browser E2E（瀏覽器送 query 看 chart）| ✅ chart 渲染成功 |
| 訂閱模式 OAuth 走通 | ✅ Credits 沒動 |

## 接續工作建議優先順序

1. 讀本檔 + `doc/session-handoff.md`（10 分鐘）
2. 跑 `npm run dev` 確認還能跑（dev server localhost:3001）
3. 議題 1：恢復圖片上傳（hardest，需要思考架構）
4. 議題 2：多輪對話結構化（嘗試 SDK session resume）
5. 把 architecture concerns 寫進 ADR
