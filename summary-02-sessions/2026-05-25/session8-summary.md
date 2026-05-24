# Session 8 — 2026-05-25

## 日期
2026-05-25

## 完成事項

### 1. Claude Code 書籍市場調查（完整篩選）
搜尋 Amazon Kindle 上所有與 Claude Code / Multi-Agent 自動化編程相關書籍，篩選條件：**有公開 Sample Code**（GitHub / 出版社 / 個人網頁）。

- 搜尋範圍：Amazon Kindle + Leanpub
- 篩選流程：逐一搜尋 `site:github.com PacktPublishing/<書名>` 等，確認 GitHub repo 存在
- 結果：9 本書調查，僅 1 本通過 ✅，1 本次推 ⚠️，7 本排除 ❌

### 2. 書籍篩選結果存檔 + 寄 Gmail
- 存檔：`autonomous-coding-sub/doc/claude-code-books-with-sample-code.md`（commit b2a9ed6）
- 調查日期：2026-05-25
- Gmail 寄送：寄至 chenghyang2001@gmail.com

### 3. Kindle 帳號購買記錄確認
- 透過 Gmail MCP 搜尋 `from:digital-no-reply@amazon.com "Agentic Coding with Claude Code"` 找到購買記錄
- Eden Marco 書：Order D01-0838421-3200238，購買日 2026-03-27，金額 $23.51（eBook）
- Thomas De Vos（Leanpub）：未購買

### 4. NotebookLM Kindle-07 確認
透過 `mcp__notebooklm__list_notebooks` 掃描所有 NLM notebooks，確認：
- Eden Marco 書 = **Kindle-07**（非我之前說的 Kindle-26，是已存在的）
- NLM 名稱：Kindle-07 🤖 Agentic Coding with Claude Code - Eden Marco
- NLM ID：`de0718af-a00e-4f89-a41b-d41d29dc8da7`
- 加入：2026-03-28（購書隔天），已全部完成（Audio 11章 ✅ / Video 11章 ✅ / Slide 11+8章中文化 ✅）

### 5. Session 收尾（git commit push）
- commit b2a9ed6：書籍調查 MD 檔
- commit 29c8adf：session8-summary（doc 目錄版）

## 關鍵技術筆記

### Amazon Kindle 書籍品質辨識法
2025-2026 年 Amazon Kindle 上充斥 AI 代筆 Claude Code 書籍：
- **徵兆**：書名聳動（"Mastery" / "Advanced" / "Production"）、作者無可驗證背景（LinkedIn 空白）、無 GitHub repo
- **可信指標**：有出版社背書（Packt / O'Reilly / Manning）、作者有公開技術背景、有 GitHub repo

### 只通過篩選的書

| 書名 | 作者 | GitHub |
|------|------|--------|
| Agentic Coding with Claude Code | Eden Marco（Packt, $22 eBook）| `PacktPublishing/Agentic-Coding-with-Claude-Code` — TS 52.8% / Python 29.4% |

### Leanpub 次推書

Thomas De Vos「Claude Code: Building Production Agents That Actually Scale」：Leanpub $9.99-$29，93% 完成，31章，真實作者（HCLTech 25年資深工程師），書中有 production code 範例但無公開 GitHub repo。

## 產出檔案

| 檔案 | commit | 說明 |
|------|--------|------|
| `autonomous-coding-sub/doc/claude-code-books-with-sample-code.md` | b2a9ed6 | 書籍篩選結果，含 87 行完整分析 |
| `autonomous-coding-sub/doc/session8-summary.md` | 29c8adf | 工作記錄（doc 目錄版） |

---

## HANDOFF（下次 session 優先處理）

### 立即行動
- [ ] **🔴 撤銷重發 Anthropic API key**：`sk-ant-api03-enO3cUTonXnigSso_...` Session 7 中出現在 VPS log，立即到 console.anthropic.com 撤銷並重發；刪除 `~/Downloads/anthropic-api-key.txt`
- [ ] **autonomous-coding-sub Windows 0/7 問題**：目前 app spec（Claude.ai clone）需要真實 Claude API streaming，建議改成純前端 spec（如 Todo App / 天氣 App）驗證 features 是否能通過
- [ ] **Thomas De Vos 書購買評估**：若要閱讀，最低 $9.99（Leanpub），內容包含真實 production agent 完整 31 章

### 進行中（需接續）
- **剩餘演練站**：`computer-use-demo`、`browser-use-demo` 需 Docker Desktop；`computer-use-best-practices` 是 macOS 專屬不演練
- sessions 6, 7 沒有 `summary-02-sessions/` 記錄（只有 doc/ 版），可補建也可跳過

### 注意事項
- Eden Marco 書（Kindle-07）NLM 已全處理完，下次不需重做
- VPS harness 正確啟動方式：不帶 `ANTHROPIC_API_KEY`，靠 `~/.claude/.credentials.json` 走 Max 訂閱
- `openai-codex` plugin SessionEnd hook 壞掉（路徑 `C:\c\Users\...` 畸形），污染 log 但不影響功能
