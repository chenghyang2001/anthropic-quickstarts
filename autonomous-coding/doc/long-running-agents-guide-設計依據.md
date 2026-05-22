# autonomous-coding 的設計依據 — Long-running Agents Guide 與「為什麼是這 6 個檔」

> 文件版本：2026-05-22
> 對象專案：`anthropic-quickstarts/autonomous-coding`
> 用途：考證並回答「這個 harness 的 6 個 Python 檔從何而來、為什麼是這個結構」。可作為 NotebookLM 知識來源。

---

## 1. 這份文件在回答什麼問題

`autonomous-coding` 這個 quickstart 的核心程式碼是 6 個 Python 檔：
`autonomous_agent_demo.py`、`agent.py`、`client.py`、`security.py`、`progress.py`、`prompts.py`
（另有 1 個測試檔 `test_security.py`，合計 7 個 `.py`）。

常見的疑問是：**這 6 個檔是 AI 自主產生的嗎？是什麼 input / 提示詞 / 設定，讓它決定要產生這 6 個檔？**

本文件用 git 與官方 GitHub 的證據，加上 Anthropic 官方設計指南，給出完整答案。

---

## 2. 程式碼來源考證

### 2.1 它不是「AI 在某個 session 逐檔生成」的

在 Anthropic 官方 repo `anthropics/anthropic-quickstarts` 中，整個 `autonomous-coding` 目錄**只來自一個 Pull Request**：

| 項目 | 內容 |
|------|------|
| PR | **#314 — "Introduce Claude-Builds-Claude quickstart"** |
| 作者 | **PedramNavid**（Pedram Navid，Anthropic 員工） |
| 建立 / 合併 | 2025-11-25 建立、2025-11-26 合併 |
| 規模 | 開發過程 4 個 commit、共變更 13 個檔案 |
| PR 說明結尾 | **「🤖 Generated with Claude Code」** |

那 13 個檔 = 7 個 `.py` + `README.md` + `.gitignore` + `requirements.txt` + `prompts/` 內 3 個檔——整個目錄是這一個 PR 一次性帶進來的。

### 2.2 AI 確實有參與，但機制是「人主導 + AI 為工具 + 受審查的 PR」

PR #314 的描述明文寫著「Generated with Claude Code」——所以 Anthropic 的工程師確實用 Claude Code 協助打造這個 quickstart（這很合理：這個 quickstart 的內部代號就是 "Claude-Builds-Claude"，是自家狗糧示範）。

但「AI 有參與」不等於「AI 自主無人監督地生出檔案」。實際機制是：

```
Anthropic 工程師 Pedram Navid
   │ 用 Claude Code 當「工具」協助撰寫
   ▼
開立正式 Pull Request #314
   │ 有具名人類作者（owner）
   │ 有 Test plan（人工審查清單）
   │ 經 4 輪 commit 迭代
   ▼
經審查、合併進 Anthropic 官方 repo
```

最終的所有權、設計責任、審查把關都在人類手上。

---

## 3. 設計藍圖：《Effective harnesses for long-running agents》

`autonomous_agent_demo.py` 開頭的 docstring（第 6-8 行）自己標明了設計來源：

> "A minimal **harness** demonstrating long-running autonomous coding with Claude. This script implements the **two-agent pattern** (initializer + coding agent) and incorporates all the strategies from the **long-running agents guide**."

這份「long-running agents guide」就是 Anthropic 工程部落格的文章
**《Effective harnesses for long-running agents》**
（https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents）。
標題裡的 **harness** 一字，與程式碼 docstring 的「A minimal harness」完全對應。

---

## 4. 指南「有」規定什麼 — 它定義了「該有哪些關注點」

指南明確列出一個長時程 harness 必須處理的**概念元件**：

| 指南講的概念元件 | 內容 |
|------------------|------|
| 雙 Agent 模式 | 初始化 agent（建環境）+ 編碼 agent（逐功能推進） |
| Feature List（JSON） | 唯一事實來源；特意選 JSON 不選 Markdown，因為「模型比較不會去亂改 JSON 檔」 |
| Progress File | 跨 session 的工作歷史，讓新 session 能恢復脈絡 |
| Git History | 提供回滾能力與狀態記錄 |
| Init Script | 確保開發環境一致啟動 |
| Session 啟動例程 | 讀 pwd → 看 git log → 查進度 → 驗證基本功能 |
| 測試策略 | 強制用瀏覽器自動化（Puppeteer）端對端驗證 |

指南也強調幾個關鍵失敗模式與對策：

- **Agent 提早宣告成功** → 用 Feature List 強制系統化追蹤完成度。
- **環境被留在壞掉狀態** → git commit + 進度筆記 + 啟動驗證。
- **功能沒測就標記完成** → 強制端對端瀏覽器自動化測試。
- **Agent 浪費 token 重新進入狀況** → 標準化的啟動檢查清單。

---

## 5. 指南「沒有」規定什麼 — 這就是問題的核心

抓取指南全文後，最關鍵的一項發現：

> **指南只描述「概念上的元件分離」（initializer 與 coding 兩種 prompt 跑在同一套 agent 基礎設施上），完全沒有規定 harness 的程式碼要怎麼切成檔案 / 模組。**

換句話說——指南給的是「**要處理哪些關注點**」，從來沒說「**要寫成 6 個檔**」。

---

## 6. 概念 → 6 個檔的對應（看就懂為什麼不是 1:1）

| 指南的概念 | 由哪個檔實作 |
|-----------|-------------|
| 雙 Agent 模式 | `agent.py`（迴圈切換角色）+ `prompts.py` + `prompts/` |
| Session 管理 / 啟動例程 | `agent.py` + `prompts/coding_prompt.md` |
| Feature List 事實來源 | `progress.py`（讀取與計數） |
| 安全 / 沙箱 | `security.py` + `client.py` |
| Context window 管理 | `client.py`（每輪建立全新 client） |
| 進入點 / 編排 | `autonomous_agent_demo.py` |

指南有約 7 個概念，harness 是 6 個檔，而且**不是一對一**：

- 有的檔實作多個概念——`agent.py` 同時包了「雙 Agent 模式」與「Session 管理」。
- 有的概念散在多個檔——「安全」由 `security.py` 與 `client.py` 共同實作。

這正好證明：「**6**」這個數字不是從指南推導出來的。

---

## 7. 結論：為什麼是這 6 個檔

| 問題 | 答案 |
|------|------|
| 「該有哪些功能 / 關注點」 | 來自《Effective harnesses for long-running agents》指南。這是最接近「設計 input」的東西。 |
| 「切成 6 個檔、取這 6 個名字」 | **沒有任何 input 決定它**。這是工程師（在 Claude Code 協助下）當下的模組化判斷。重做一次可能變成 5 個或 8 個檔。 |
| 「作者餵給 Claude Code 的實際 prompt」 | 在 Pedram Navid 私人的 Claude Code session 裡，從未被 commit，repo 中找不到。 |
| 「公開可查、最接近意圖說明的」 | PR #314 的描述 + `README.md` 的 Project Structure 章節。 |

**最誠實的總結：**

> 有一份指南決定了「骨架要包含什麼」（要有迴圈、要有安全控管、要有進度保存、要有雙 Agent 角色……）；但「切成剛好 6 個檔、取這些名字」這個具體模組化手法，是人臨場的設計選擇——它不存在於任何可被「找出來」的 input 裡。
>
> 補充觀念：LLM 的程式碼生成**不是決定論的 config→output**。沒有任何規則、設定、提示詞寫著「要產生 6 個檔」。「6」是設計判斷的結果，不是被輸入決定的數字。

---

## 8. 延伸區分（避免常見混淆）

要分清楚兩層東西：

- **harness 本身**（這 6 個 `.py`）→ 由 PR #314 帶進來的固定檔案；結構由人決定、AI 輔助、經審查。
- **harness 跑起來後 AI 會自主生成的應用程式**（產物放在 `generations/` 目錄）→ **那個**的檔案結構才是由 `app_spec.txt` + 提示詞驅動的。

本文件討論的「6 個檔」屬於第一種；由規格 / 提示詞驅動結構的是第二種。

---

## 9. 參考來源

- Effective harnesses for long-running agents — https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Building agents with the Claude Agent SDK — https://www.anthropic.com/engineering/building-agents-with-the-claude-agent-sdk
- Anthropic 官方 repo PR #314「Introduce Claude-Builds-Claude quickstart」— github.com/anthropics/anthropic-quickstarts/pull/314
- 配套文件：`autonomous-coding-codebase-report.md`（同目錄，codebase 深度技術報告）
