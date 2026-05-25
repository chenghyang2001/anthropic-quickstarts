# 瀏覽頁面規格書

## 概述

瀏覽 / 探索頁面是 HookHub 的**核心體驗** — 使用者在此探索、篩選並找到要安裝的 Claude Code Hook。每個變體代表完全不同的資訊架構與探索 UX 設計方式。

這是一個**整頁元件**（`src/components/pages/`），而非單一區塊或卡片。

## 商業目標

讓開發者能夠：
1. 快速找到符合自己工作流的 Hook
2. 依類別、語言、Hook 類型和排序方式篩選
3. 在前往 GitHub 前預覽 Hook 的元資料
4. 複製一行 CLI 指令即可安裝

## 資料結構

```ts
interface Hook {
  id: string
  name: string
  category: 'UTILITY' | 'SECURITY' | 'WORKFLOW' | 'MONITORING' | 'TESTING' | 'LEARNING' | 'INTEGRATION' | 'TEAM'
  description: string
  githubUrl: string
  author: string
  stars: number
  downloads: number
  language: 'Python' | 'TypeScript' | 'Go' | 'JavaScript' | 'PHP' | 'Rust'
  hookTypes: string[]
  featured: boolean
  lastUpdated: string   // ISO 8601
  tags: string[]
  version: string
  license: string
}
```

所有資料來源：`@/data/hooks.json`（專案中已存在）。

## 檔案規範

- 檔名：`BrowsePage<Variant>.tsx`
- 位置：`src/components/pages/`
- 必須加 `'use client'`（篩選功能需要 useState）
- 不需要 Props（直接從 hooks.json 載入資料）
- 匯出：`export default function BrowsePage<Variant>()`
- 不可使用外部 import（只能用 Tailwind + React）

## 必要功能（每個變體都必須包含）

### 1. 搜尋列
- 對名稱、描述、作者、標籤進行全文搜尋
- 防抖輸入（不使用外部套件 — 用 useEffect + setTimeout 實作）
- 有文字時顯示清除按鈕
- 顯示結果數量（「顯示 18 個 Hook 中的 12 個」）

### 2. 篩選面板
必須同時支援以下所有篩選條件：
- **類別** — 多選核取方塊或切換按鈕（UTILITY、SECURITY、WORKFLOW、MONITORING、TESTING、LEARNING）
- **語言** — 多選（Python、TypeScript、Go、JavaScript、PHP）
- **Hook 類型** — 多選（PRE_TOOL_USE、POST_TOOL_USE、STOP、NOTIFICATION、SUBAGENT_*）
- **排序** — 單選下拉選單：星星數 ↓、下載數 ↓、最近更新、名稱 A-Z

### 3. 結果格線
- 響應式：1 欄（手機）→ 2 欄（平板）→ 3 欄（桌面）
- 使用 `@/components/HookCard` 元件
- 無結果時顯示空白狀態提示
- 「精選」Hook 優先顯示（或有明確標記）

### 4. 篩選狀態摘要
- 顯示已啟用的篩選條件為可關閉的標籤（chips）
- 任何篩選條件啟用時顯示「清除全部篩選」按鈕
- 手機版的篩選面板開關按鈕上顯示篩選數量徽章

### 5. 手機版篩選抽屜（選用但建議實作）
- 手機版：篩選條件收納在「篩選」按鈕後方
- 桌面版：篩選條件以側邊欄或頂部列形式顯示

## 色彩系統

- 主色：`#d97757`
- 次要色：`#6a9bcc`
- 背景色：`var(--background)`
- 前景色：`var(--foreground)`
- 框線色：`var(--border)`
- 石板淺色：`var(--slate-light)`

## 變體設計規範

每個變體必須選擇明顯不同的版面模式：

- **側邊欄版面** — 左側垂直篩選面板（240px），右側填滿結果格線
- **頂部列版面** — 結果上方水平篩選列，無側邊欄
- **命令面板風格** — 搜尋優先，篩選以下拉選單呈現，結果以緊湊清單顯示
- **雜誌版面** — 精選 Hook 以大型頂部橫幅呈現，其餘以不對稱格線排列

## 效能要求

所有篩選與搜尋必須在**客戶端**完成（不發送 API 請求）。
React 狀態：`hooks` 陣列載入一次，從篩選狀態同步計算衍生的 `filteredHooks`。
篩選不使用 useEffect — 直接從篩選狀態同步計算。

## 頁面結構

```
<BrowsePage>
  ├── 頁面標題（標題 + 說明 + 安裝數量統計）
  ├── 搜尋列
  ├── 篩選區域（依變體選擇側邊欄或頂部列）
  │   ├── 類別篩選
  │   ├── 語言篩選
  │   ├── Hook 類型篩選
  │   └── 排序控制
  ├── 已啟用篩選列（已啟用篩選條件的標籤）
  ├── 結果格線
  │   ├── 結果數量
  │   └── HookCard × N
  └── 空白狀態（filteredHooks.length === 0 時顯示）
</BrowsePage>
```
