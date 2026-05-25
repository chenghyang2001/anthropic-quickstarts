# HookCard 元件規格書

## 概述

HookCard 是展示單一 Claude Code Hook 項目的 UI 卡片元件。
每個變體以完全不同的視覺版面呈現相同的資料。

## 資料結構（固定不變）

```ts
interface Hook {
  id: string
  name: string
  category: string       // UTILITY / SECURITY / WORKFLOW / MONITORING / TESTING / LEARNING
  description: string
  githubUrl: string
  author: string
  stars: number
  language: string       // Python / TypeScript / PHP / Go / JavaScript
  hookTypes: string[]    // PRE_TOOL_USE / POST_TOOL_USE / STOP / NOTIFICATION / 等
  featured: boolean
}
```

## 檔案規範

- 檔名：`HookCard<Variant>.tsx`
- 位置：`src/components/cards/`
- 必須加 `'use client'` 指令
- Props：`interface Props { hook: Hook }` — 傳入單一 hook 物件
- 匯出：`export default function HookCard<Variant>({ hook }: Props)`
- 不可使用外部 import（只能用 Tailwind + React）

## 色彩系統

| 類別 | 色碼 |
|------|------|
| UTILITY | `#6a9bcc`（藍色）|
| SECURITY | `#dc2626`（紅色）|
| WORKFLOW | `#d97757`（橙色）|
| MONITORING | `#7c3aed`（紫色）|
| TESTING | `#059669`（綠色）|
| LEARNING | `#788c5d`（橄欖色）|

語言徽章色彩：Python→`#3b82f6`、TypeScript→`#8b5cf6`、Go→`#06b6d4`、JavaScript→`#f59e0b`、PHP→`#a855f7`

## 必要顯示元素（每個變體都必須包含）

1. Hook 名稱（醒目顯示）
2. 類別徽章（依類別顯示對應顏色）
3. 說明文字（截斷為 2 行）
4. 作者 + GitHub 連結
5. 星星數（格式化：1200 → 「1.2k」）
6. 語言徽章
7. hookTypes 標籤（最多顯示 3 個）
8. 精選指示器（`hook.featured = true` 時顯示）

## 變體設計規範

每個變體必須有明顯不同的視覺版面：
- 不同的卡片形狀 / 邊框樣式
- 不同的資訊層次
- 不同的懸停互動效果
- 相同的資料，不同的 UX 感受
