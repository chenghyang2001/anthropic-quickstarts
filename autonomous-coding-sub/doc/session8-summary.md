# Session 8 Summary — 2026-05-25

## 完成事項

### Claude Code 書籍調查

搜尋 Amazon Kindle 上有關 Claude Code / Multi-Agent 自動化編程的書籍，篩選條件：有公開 Sample Code（GitHub / 出版社 / 個人網頁）。

**篩選結果：**

| 等級 | 書名 | 作者 | 備注 |
|------|------|------|------|
| ✅ 強推 | Agentic Coding with Claude Code | Eden Marco（Packt, $22）| GitHub repo 確認 |
| ⚠️ 次推 | Claude Code: Building Production Agents | Thomas De Vos（Leanpub, $9.99-$29）| 書中有 code，無公開 repo |
| ❌ 排除 | 7 本 AI 代筆書 | 多位自出版作者 | 無 GitHub repo |

Amazon Kindle 充斥大量 AI 代筆書（2025-2026 年湧現），書名聳動但無 code、無可驗證作者背景。

**存檔：** `doc/claude-code-books-with-sample-code.md`（commit b2a9ed6）

### NotebookLM 掃描

確認 Eden Marco 的書已在 NotebookLM：
- **Kindle-07** 🤖 Agentic Coding with Claude Code - Eden Marco
- NLM ID：`de0718af-a00e-4f89-a41b-d41d29dc8da7`
- 加入：2026-03-28（購書隔天）
- 狀態：Audio 11章 ✅、Video 11章 ✅、Slide 11+8章中文化 ✅ — **全部完成**

Thomas De Vos（Leanpub）未購買、不在 NLM。

### Gmail 確認

Eden Marco 購買紀錄：Order D01-0838421-3200238，2026-03-27，$23.51。

## Commits

| Hash | 說明 |
|------|------|
| b2a9ed6 | 新增 Claude Code 書籍調查：有 sample code 的書籍清單 |

## 待辦（下次接續）

1. 🔴 撤銷重發 Anthropic API key（console.anthropic.com）
2. autonomous-coding-sub Windows 0/7 問題（換純前端 spec）
3. Docker Desktop 安裝後演練 computer-use-demo / browser-use-demo
