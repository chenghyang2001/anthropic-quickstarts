# Section 元件規格書

## 概述

Section 元件是放置於 HookHub 登陸頁面 **Hero 區塊下方**的內容區塊。
每個 Section 傳達平台不同的價值主張。

## 內容背景（HookHub）

HookHub 是一個用於探索、分享與安裝 Claude Code Hooks 的社群平台。
- Hooks 是在生命週期事件（PRE_TOOL_USE、POST_TOOL_USE、STOP 等）觸發的自動化腳本
- 社群驅動：任何人都可以提交 Hooks
- 目標使用者：使用 Claude Code 的開發者

## 結構需求

每個 Section 必須包含：
1. **Section 標籤** — 小型大寫分類標籤（例：「為什麼選擇 HOOKHUB」、「使用者見證」）
2. **標題** — 粗體 H2，1-2 行
3. **說明文字** — 1-2 句描述
4. **主要內容區** — 獨特的視覺呈現（格線、卡片、引言、時間軸等）
5. **選用 CTA** — 底部連結或按鈕

## 色彩系統

| 代號 | 色碼 | 用途 |
|------|------|------|
| 主色 | `#d97757` | 強調色、重點 |
| 次要色 | `#6a9bcc` | 次要強調 |
| 第三色 | `#788c5d` | 第三強調 |
| 背景色 | `var(--background)` | Section 背景 |
| 前景色 | `var(--foreground)` | 文字 |
| 石板淺色 | `var(--slate-light)` | 低調文字 |
| 框線色 | `var(--border)` | 分隔線 |

## 版面規範

- 最大寬度：`max-w-6xl mx-auto px-6 lg:px-8`
- Section 內距：`py-20 lg:py-28`
- 響應式：手機優先，使用 `sm:` / `md:` / `lg:` 斷點
- 使用 CSS Grid 或 Flexbox 排列內容

## 可用的動畫類別

`animate-fade-in`、`animate-slide-up`、`animate-float`、`animate-pulse-slow`、`animate-ping-slow`

## 檔案規範

- 檔名：`Section<Name>.tsx`
- 位置：`src/components/sections/`
- 必須加 `'use client'` 指令
- 不可使用外部 import（只能用 Tailwind + React）
- 匯出：`export default function Section<Name>()`

## 變體設計規範

建立新的 Section 變體時：
1. **獨特的內容版面** — 每個 Section 外觀需明顯不同
2. **一致的品牌形象** — 使用色彩系統的顏色代號
3. **真實內容** — 使用真實的 HookHub 相關文字（不用 lorem ipsum）
4. **自給自足** — 不需要 props，所有資料直接寫在元件內
