# Session Handoff — 2026-05-23

> 本檔記錄這個訂閱版分支從建立到完整驗證的過程，方便未來 Claude session 接手。

## 任務脈絡

使用者要從 `anthropic-quickstarts/financial-data-analyst`（強制要 API key、扣 API Credits）分支出**訂閱版**，走 `@anthropic-ai/claude-agent-sdk` + `claude` CLI 的 OAuth 用 Pro/Max 訂閱額度。

對應同 session 的姐妹專案：`../autonomous-coding-sub/`（同 pattern，但用 Python harness + bash CLI）。

## 完成事項（5/23 一個 session 內全做完）

### Phase 1 — Pre-flight verification

- `claude` CLI v2.1.149 ✅ 已登入 OAuth
- `@anthropic-ai/claude-agent-sdk` v0.3.149 ✅ npm 可裝
- `zod` v4 必要（SDK 要 zod@^4.0.0，不是 v3）

### Phase 2 — 複製 + 設定

```bash
cp -r financial-data-analyst financial-data-analyst-sub
```

改 `package.json`：
- name → `financial-assistant-sub`
- script dev/start → `next dev/start -p 3001`
- 移除 `@anthropic-ai/sdk@^0.29.0`
- 加 `@anthropic-ai/claude-agent-sdk@^0.3.0`、`zod@^4.0.0`

寫 `.env.local.example` 標明不需 API key。

`npm install` → 566 packages，SDK + zod 都到位。

### Phase 3 — 重寫 route.ts（writer → QA → reviewer 完整三 agent）

完整鐵律流程：

| Step | 動作 | 結果 |
|---|---|---|
| Writer 第一版 | 484 行 (原 432) | SHA 9408...c3 |
| QA | V1-V5 + 3 test cases | 全 PASS |
| Reviewer | 3 個 MUST_FIX + 4 NICE_TO_HAVE + 4 ARCHITECTURE | CHANGES_REQUESTED |
| Writer 修正版 | 484 行 | SHA 4abc...8b |

Reviewer 的 3 個 MUST_FIX 全部解決：

1. **`delete process.env.ANTHROPIC_API_KEY` process-wide 污染問題**：
   - 原寫法在 POST handler 開頭刪 env，會影響其他 concurrent request / 其他 route
   - 改用 SDK options.env：`env: { ...process.env, ANTHROPIC_API_KEY: undefined }` — request-scoped 只影響該次 spawn 的 claude CLI subprocess
   - SDK 型別來源：`node_modules/@anthropic-ai/claude-agent-sdk/sdk.d.ts:1326-1344`

2. **Input validation 缺**：
   - `model` 字串直接餵 SDK，無白名單檢查
   - `msg.role` 沒驗證，惡意 client 可塞 `role: "system"` 改 prompt
   - 改用 zod `RequestSchema`（model 限定 haiku/sonnet 白名單；role 限 `user|assistant`；content 限 string|array）

3. **catch block leak raw error.message**：
   - 改成分類錯誤碼：CLI_NOT_FOUND（ENOENT）/ OAUTH_EXPIRED（401/unauthorized）/ INTERNAL_ERROR
   - 完整 stack 只進 server log，前端只看通用訊息 + 分類碼

順手吃了 4 個 NICE_TO_HAVE：移掉 `...({ tools: [] } as any)` spread（SDK 型別其實支援 `tools: []` 直接寫）、移掉 `cwd: process.cwd()` 多餘、縮減 `as AsyncIterable<any>` cast 範圍。

### Phase 4 — 驗證 5 + 1

全測通過：

| Test | 結果 |
|---|---|
| Test 1 (Happy): "Show me Q1-Q4 2024 revenue" → bar chart | ✅ 24.2s（cache warm）, chartType=bar, data=4 |
| Test 2 (Edge): "What is 2+2?" → 不畫圖 | ✅ chartData=null, content="Four.", 12.8s |
| Test 3 (Integration): 多輪轉 pie chart | ✅ chartType=pie, data=2, 29.1s |
| Test 4: Invalid model `claude-opus-9.9-hacker` | ✅ HTTP 400 + zod 結構化 error |
| Test 5: Invalid role `system` | ✅ HTTP 400 + zod 結構化 error |
| Browser E2E (Puppeteer 開 localhost:3001/finance + 送查詢 + 截圖) | ✅ chart 渲染完整 |

訂閱模式確認：log 看不到 API call，response 無 `total_cost_usd` 從 API 來。

截圖留底：`doc/smoke-test-screenshot.png`。

Commit：`151d0ff 新增 financial-data-analyst-sub：訂閱版分支`（push 完）

## 已驗證的事

| 項目 | 結果 |
|---|---|
| SDK + zod 安裝 + 編譯 | ✅ |
| 訂閱模式 OAuth 走通 | ✅ |
| `env` request-scoped 隔離 API key | ✅ |
| zod input validation 攔得住惡意輸入 | ✅ |
| Error 分類不洩漏 raw message | ✅ |
| chart tool MCP pattern 保留結構化合約 | ✅ |
| 前端 100% 不動 + JSON 形狀相容 | ✅ |
| 三 agent 鐵律完整跑完 | ✅ |
| Browser E2E | ✅ |

## 未解決問題（留給未來）

### #1 圖片上傳關閉（POC 範圍）

`utils/fileHandling.ts` 前端 UI 仍可選圖片，但 route.ts 對圖片 mediaType：

```typescript
console.warn('[POC] Image upload skipped — SDK prompt is string only');
```

要恢復需把圖片轉 base64 嵌進 prompt 字串（model 看不太懂）或改走 vision SDK。

### #2 多輪對話結構降級

route.ts 把 messages 攤平成單一字串：

```
User: 訊息1
Assistant: 回覆1
User: 訊息2
```

短對話沒差，長對話會降低 chart 工具觸發精準度。SDK 的 `query()` prompt 只吃 string 或 `AsyncIterable<SDKUserMessage>`（但只能塞 user message，不能餵歷史 assistant 回應）。

解法選項：
- (a) 只把 last user 當 prompt + systemPrompt 補歷史摘要
- (b) 用 SDK session resume：傳 `resume: sessionId`，前端配合存 sessionId

### #3 每 session warm-up ~25-30 秒

SDK 每次 query 都 spawn 一個新的 `claude` CLI 子行程，每次都重載 ~70k tokens 預設 Claude Code system prompt。用字串 `systemPrompt` 覆寫掉預設只省了 token，沒省掉 spawn 啟動成本。

POC 階段 OK，但生產級體驗需要：
- 用 SDK 的 session resume keep-alive
- 或考慮回到原版 API mode（首次 1-2 秒）

### #4 Self-host only

雲端 serverless（Vercel / Cloudflare）沒 claude CLI binary + OAuth 憑證，本版**無法部署**。

需要部署只能 self-host 在有完整 Claude Code 環境的機器。

### #5 訂閱用量上限

Pro 約 5 hours/週、Max 約 25 hours/週。猛測試 + 演示會撞牆。

## 重要紀錄

### Reviewer ARCHITECTURE_CONCERNS（POC 沒解，留給未來）

1. **messages 攤平丟失結構**：見 #2
2. **per-request 重建 MCP server 的 CPU 成本**：低 QPS POC 沒問題；> 10 req/s 會看到 CPU spike。是 SDK 限制下的必要成本（避免 closure race condition）。**chartTool/chartServer 不能 hoist 到模組頂層**
3. **maxTurns: 3 邊界沒測**：QA 三個 case 都正常 turn 內結束，沒測超時情境。SDK 超時會丟 `error_max_turns` subtype → route.ts line 376 直接 break，前端看到 content="" 會以為「Claude 沒回應」。建議補 UX fallback
4. **child_process spawn 部署可移植性**：見 #4

## 下次接手建議步驟

1. 讀 `CLAUDE.md`（5 分鐘）
2. 讀本檔（5 分鐘）
3. 確認 `claude --version` + `echo "hi" | claude -p` 還能回應
4. `npm install` + `npm run dev`
5. 開 `localhost:3001/finance` 送一個查詢確認還能用
6. 從 #1-#5 挑一個議題動工

## 重要紀錄：成本

5/23 session 累計訂閱用量（test + browser smoke）：< $0.5 USD 等價。financial-data-analyst-sub 性質是「每次 chat 一次 query」，比 autonomous-coding-sub（持續跑 sessions）省太多。

## 同 session 姐妹專案

`../autonomous-coding-sub/` — 另一個訂閱版分支（Python harness）。技術上成功啟動訂閱模式，但 5 features full run 0/8 通過（bash 版 MCP allowlist 不完整導致 agent 無法驗 UI）。詳見該專案的 `CLAUDE.md` + `doc/session-handoff.md`。
