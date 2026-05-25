# Hook 詳情頁面規格書

## 概述

Hook 詳情頁面是單一 Hook 的**深度體驗**。
讓開發者在不離開 HookHub 的情況下，獲得評估、了解並安裝 Hook 所需的一切資訊。

這是一個展示單一 Hook 完整資訊的**整頁元件**。
每個變體對資訊層次和使用者流程採取完全不同的設計方式。

## 商業目標

開發者進入此頁面後，應能：
1. 在 10 秒內了解這個 Hook 的功能
2. 看到精確的安裝指令（一鍵複製）
3. 不前往 GitHub 就能預覽原始碼（關鍵檔案）
4. 閱讀社群評論和星級評分
5. 探索相關 Hook

## 資料結構

```ts
interface HookDetail extends Hook {
  readme: string           // Hook README 的 Markdown 內容
  installCommand: string   // 例：「npx hookhub install security-scanner」
  sourcePreview: {         // 關鍵原始碼檔案預覽
    filename: string
    language: string
    content: string        // 主要 hook 檔案的前 50 行
  }
  reviews: Review[]
  relatedHooks: Hook[]     // 同類別的 3 個 Hook
  changelog: ChangelogEntry[]
}

interface Review {
  id: string
  author: string
  avatarInitials: string   // 例：「JL」（不需要圖片 URL）
  rating: 1 | 2 | 3 | 4 | 5
  body: string
  createdAt: string        // ISO 8601
  helpful: number          // 「X 人覺得這很有幫助」
}

interface ChangelogEntry {
  version: string
  date: string             // ISO 8601
  changes: string[]        // 此版本的變更清單
}
```

所有資料**直接寫在元件內**（不需要 Props，不發送 API 請求）。
使用符合真實安全掃描 Hook 的逼真模擬資料。

## 檔案規範

- 檔名：`HookDetailPage<Variant>.tsx`
- 位置：`src/components/pages/`
- 必須加 `'use client'`（頁籤切換、複製按鈕狀態）
- 不需要 Props（所有資料直接寫入）
- 匯出：`export default function HookDetailPage<Variant>()`
- 不可使用外部 import（只能用 Tailwind + React）

## 必要區塊（每個變體都必須包含全部 7 個）

### 1. 頁面標題 / Header
- Hook 名稱（H1），大型醒目顯示
- 類別徽章 + 語言徽章
- 作者 + GitHub 連結
- 星星數 + 下載數計數器
- 「精選」徽章（如適用）
- **安裝指令區塊**：`npx hookhub install <id>` 含一鍵複製按鈕
  - 複製按鈕在「複製」→「已複製！」之間切換 2 秒（useState）

### 2. 總覽頁籤 / 區塊
- Hook 說明（完整版，不截斷）
- 支援的 Hook 類型（視覺化標籤，顯示所有生命週期事件）
- 版本 + 授權 + 最後更新 元資料列
- 標籤（可點擊徽章）

### 3. 原始碼預覽
- 檔名標頭（例：`hook.py` 或 `hook.ts`）
- 程式碼區塊含語法突顯（僅用 CSS，不使用套件 — 用 `<pre><code>`）
- 語言標籤
- 前往 GitHub 完整檔案的連結
- 最少 20 行逼真的 Hook 原始碼（直接寫入）

### 4. README 區塊
- 以樣式化 HTML 呈現（使用 Tailwind prose 風格，不使用外部套件）
- 必須包含：說明段落、使用範例、設定選項表格
- 底部加上「在 GitHub 上查看」連結

### 5. 評論區塊
- 星級評分摘要：平均分（例：4.3 ★）+ 分佈長條圖（僅用 CSS）
- 至少 4 個個別評論卡片，含：頭像縮寫、星級評分、評論文字、日期、有幫助數量
- 「這有幫助嗎？」拇指上/下按鈕（視覺呈現，不需狀態）

### 6. 更新日誌
- 版本歷史表格或時間軸
- 至少 3 個版本，含逼真的變更說明
- 最新版本突顯顯示

### 7. 相關 Hook
- 同類別的 3 個 Hook 卡片
- 緊湊卡片設計（僅顯示名稱 + 說明）
- 「瀏覽更多 SECURITY Hook →」連結

## 色彩系統

- 主色：`#d97757`
- 次要色：`#6a9bcc`
- 背景色：`var(--background)`
- 前景色：`var(--foreground)`
- 框線色：`var(--border)`
- 石板淺色：`var(--slate-light)`
- 程式碼背景：`#1e1e2e`（深色，永遠深色 — 即使在亮色模式下）
- 程式碼文字：`#cdd6f4`

## 變體設計規範

每個變體必須選擇明顯不同的**導航 / 版面模式**：

- **頁籤版面** — 7 個區塊收納在頁籤後（總覽 / 原始碼 / 評論 / 更新日誌 / 相關）
- **單頁捲動** — 所有區塊垂直堆疊，左側固定區塊導航
- **分割面板** — 左側：元資料 + 安裝 + 頁籤；右側：固定的安裝卡片 + 相關 Hook
- **雜誌版面** — 頁面標題橫跨全寬，下方以不對稱 3 欄格線排列各區塊

## 互動需求

1. **複製按鈕** — 安裝指令剪貼簿複製，含「已複製！」回饋（useState）
2. **頁籤 / 區塊切換** — 使用頁籤版面時，平滑切換內容（useState activeTab）
3. **評論有幫助** — 每則評論的「有幫助」按鈕視覺點擊狀態（每個評論 id 的 useState）
4. **星級顯示** — 評分用填滿 / 空心 SVG 星星（不使用套件）

## 需寫入的模擬資料

使用此 Hook 作為範例：
- **名稱**：Security Scanner Pro
- **ID**：`security-scanner-pro`
- **類別**：SECURITY
- **作者**：`alex-devops`
- **星星數**：2847
- **下載數**：18432
- **語言**：Python
- **Hook 類型**：`["PRE_TOOL_USE"]`
- **版本**：`2.1.0`
- **授權**：MIT
- **精選**：true
- **平均評分**：4.6（來自 89 則評論）

原始碼預覽應為逼真的 Python Hook，功能包含：
- 在執行前攔截工具使用
- 檢查危險模式（rm -rf、DROP TABLE 等）
- 偵測到威脅時回傳封鎖回應
- 將所有檢查記錄到 `~/.claude/security-log.json`
