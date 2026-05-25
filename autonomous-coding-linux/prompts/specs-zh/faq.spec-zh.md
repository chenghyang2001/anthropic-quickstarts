# FAQ 區塊規格書

## 概述

HookHub 登陸頁面的常見問題（FAQ）區塊。
每個變體以不同的互動版面呈現相同的問答內容。

## 內容（固定 — 所有變體相同）

### 8 個必須包含的問答：

1. **什麼是 Claude Code Hook？**
   答：Hooks 是在 Claude Code 生命週期事件（PreToolUse、PostToolUse、Stop 等）自動執行的腳本。它們讓你可以在每次 AI 工作階段中加入自訂邏輯，例如安全性檢查、日誌記錄、通知與自動化測試。

2. **HookHub 是免費的嗎？**
   答：是的，完全免費。HookHub 是一個開源社群平台。所有 Hooks 均可在各自的授權條款下（大多為 MIT）免費瀏覽、安裝和使用。

3. **如何安裝一個 Hook？**
   答：在終端機執行 `npx hookhub install <hook-id>`。CLI 會自動將 Hook 配置添加到你的 `~/.claude/settings.json` 檔案中，無需手動編輯。

4. **安裝 Hooks 安全嗎？**
   答：每個 Hook 的原始碼都可以在 GitHub 上公開查看。我們顯示作者、星星數與社群評論。用於生產環境前，請務必先審查原始碼——尤其是具有 `PreToolUse` 存取權限的 Hooks。

5. **我可以發布自己的 Hooks 嗎？**
   答：當然可以！向 HookHub 登錄表提交包含你的 Hook 的 GitHub URL 與元資料的 PR。社群審查通常在 48 小時內完成。

6. **支援哪些 Hook 類型？**
   答：PreToolUse、PostToolUse、Stop、Notification、SubagentStart、SubagentStop 和 SubagentStream — 涵蓋所有 8 種 Claude Code 生命週期事件。

7. **Hooks 支援 Claude Code 子代理（sub-agents）嗎？**
   答：支援。具有 `SubagentStart` / `SubagentStop` / `SubagentStream` 類型的 Hooks 會在每次子代理呼叫時觸發，讓你完整觀測多代理管道的運作情況。

8. **如何卸載 Hook？**
   答：執行 `npx hookhub uninstall <hook-id>`，或手動從 `~/.claude/settings.json` 中移除對應項目。

## 檔案規範

- 檔名：`SectionFaq<Variant>.tsx`
- 位置：`src/components/sections/`
- 必須加 `'use client'` 指令
- 不需要 Props（所有問答直接寫入元件）
- 匯出：`export default function SectionFaq<Variant>()`
- 不可使用外部 import（只能用 Tailwind + React）
- 互動性：點擊問題切換顯示 / 隱藏答案（使用 useState）

## 必要元素

1. Section 標籤：「FAQ」
2. H2 標題（每個變體自選措辭）
3. 全部 8 組問答（必須全部呈現）
4. 切換互動（點擊展開 / 收合每個答案）
5. 顯示開啟 / 關閉狀態的細微視覺指示器（箭頭、加號等）

## 色彩系統

- 主色：`#d97757`
- 次要色：`#6a9bcc`
- 背景色：`var(--background)`
- 前景色：`var(--foreground)`
- 框線色：`var(--border)`
- 石板淺色：`var(--slate-light)`

## 變體設計規範

每個變體必須使用明顯不同的版面 / 互動模式：
- **手風琴（Accordion）** — 經典的單一展開手風琴清單
- **雙欄格線** — 4+4 分割，預設全部展開，點擊收合
- **極簡風格** — 無邊框、預設展開、行內答案搭配淡出動畫
- **卡片格線** — 每組問答為獨立卡片，滑入 / 點擊展開
- 動畫：展開 / 收合必須有流暢過渡效果（max-height 或 opacity）
