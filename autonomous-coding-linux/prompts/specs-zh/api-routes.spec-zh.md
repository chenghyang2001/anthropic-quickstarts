# API 路由規格書

## 概述

以 **Next.js App Router Route Handlers** 建構的 HookHub 後端 API 路由。
每個變體是一個**完整、自給自足的 API 模組**，涵蓋一個業務領域
（Hook 探索、使用者個人資料，或 Hook 提交工作流）。

本規格書產出 TypeScript API 路由檔案與共用型別定義。

## 技術堆疊

- 執行環境：Next.js 15 App Router（`app/api/...route.ts`）
- 語言：TypeScript（strict 模式）
- 資料：`src/data/` 中的 JSON 檔案（此階段不使用資料庫）
- 認證：透過 `x-api-key` 標頭模擬（非真實認證 — 僅為 mock）
- 回應格式：`{ data, meta, success, error?, timestamp }`

## 檔案規範

每個變體是一組相關檔案的**束（bundle）**：

```
src/app/api/<領域>/
├── route.ts          — 集合端點（GET 清單、POST 建立）
├── [id]/
│   └── route.ts     — 單一資源端點（GET、PUT、DELETE）
└── _types.ts         — 此領域的共用 TypeScript 介面
```

匯出模式：Route Handlers 使用具名匯出 `GET`、`POST`、`PUT`、`DELETE`。

## 共用回應信封（所有路由必須使用）

```ts
// 成功
{ "success": true, "data": <酬載>, "meta": { "total": N, ... }, "timestamp": "ISO8601" }

// 錯誤
{ "success": false, "error": { "code": "NOT_FOUND", "message": "人類可讀的訊息" }, "timestamp": "ISO8601" }
```

HTTP 狀態碼必須正確（200 / 201 / 400 / 404 / 422 / 500）。

## 必要 API 行為（每個變體都必須實作）

1. **輸入驗證** — 驗證查詢參數和請求本體欄位，回傳含欄位層級錯誤的 400
2. **錯誤處理** — 全部包 try/catch，不可有未處理的 Promise rejection
3. **分頁** — 所有清單端點支援 `?page=1&perPage=20`
4. **排序** — 清單端點支援 `?sortBy=stars|downloads|lastUpdated&order=asc|desc`
5. **篩選** — 清單端點支援特定領域的查詢參數（例：`?category=SECURITY`）
6. **CORS 標頭** — 所有回應加上 `Access-Control-Allow-Origin: *`
7. **無硬編碼路徑** — 資料透過 `path.join(process.cwd(), 'src/data/...')` 載入

## 變體設計規範

每個變體涵蓋 HookHub API 的**不同業務領域**：

### 變體 A — Hook 探索 API
端點：
- `GET /api/hooks` — 列出所有 Hook（分頁 + 依類別、語言、hookType 篩選 + 排序）
- `GET /api/hooks/[id]` — 單一 Hook 詳情
- `GET /api/hooks/featured` — 僅限精選 Hook
- `GET /api/hooks/search?q=...` — 對名稱、描述、標籤進行全文搜尋

TypeScript 型別：`Hook`、`HookListResponse`、`HookDetailResponse`、`SearchResponse`

### 變體 B — 使用者個人資料 API
端點：
- `GET /api/users` — 列出社群貢獻者（分頁 + 依星星數、Hook 數量排序）
- `GET /api/users/[username]` — 單一使用者個人資料
- `GET /api/users/[username]/hooks` — 該使用者發布的 Hook
- `GET /api/users/[username]/stats` — 貢獻統計（總星星數、下載數、Hook 數量）

TypeScript 型別：`UserProfile`、`UserStats`、`UserListResponse`、`UserHooksResponse`

### 變體 C — Hook 提交工作流 API
端點：
- `POST /api/submissions` — 提交新 Hook（請求本體：githubUrl + 元資料）
- `GET /api/submissions` — 列出待審提交（管理員 mock — 需要 x-api-key）
- `GET /api/submissions/[id]` — 單一提交狀態
- `PUT /api/submissions/[id]/review` — 核准 / 拒絕（本體：`{ action: 'approve'|'reject', reason?: string }`）
- `GET /api/submissions/[id]/validate` — 驗證 GitHub URL 並取得 repo 元資料

TypeScript 型別：`HookSubmission`、`SubmissionStatus`、`ReviewAction`、`ValidationResult`

## 錯誤代碼列舉

所有變體必須使用此共用錯誤詞彙：
```ts
type ApiErrorCode =
  | 'NOT_FOUND'           // 找不到資源
  | 'INVALID_INPUT'       // 輸入格式錯誤
  | 'MISSING_REQUIRED_FIELD'  // 缺少必填欄位
  | 'UNAUTHORIZED'        // 未授權
  | 'RATE_LIMITED'        // 請求過於頻繁
  | 'INTERNAL_ERROR'      // 伺服器內部錯誤
```

## 資料來源

從既有 JSON 檔案讀取：
- `src/data/hooks.json` — Hook 資料（已存在）
- `src/data/mocks/*.mock.json` — 擴充模擬資料（若已產生）

變體 B 與 C 請在記憶體中自行產生逼真的模擬資料（不需要外部檔案）。

## Route Handler 標準模式範例

```ts
// src/app/api/hooks/route.ts
import { NextRequest, NextResponse } from 'next/server'
import path from 'path'
import fs from 'fs'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const page = parseInt(searchParams.get('page') ?? '1')
    const perPage = parseInt(searchParams.get('perPage') ?? '20')
    const category = searchParams.get('category')

    // 載入資料
    const dataPath = path.join(process.cwd(), 'src/data/hooks.json')
    const raw = JSON.parse(fs.readFileSync(dataPath, 'utf-8'))
    let hooks: Hook[] = raw.hooks

    // 篩選
    if (category) hooks = hooks.filter(h => h.category === category)

    // 分頁
    const total = hooks.length
    const items = hooks.slice((page - 1) * perPage, page * perPage)

    return NextResponse.json({
      success: true,
      data: items,
      meta: { total, page, perPage, totalPages: Math.ceil(total / perPage) },
      timestamp: new Date().toISOString()
    })
  } catch (error) {
    return NextResponse.json(
      { success: false, error: { code: 'INTERNAL_ERROR', message: '無法取得 Hook 資料' }, timestamp: new Date().toISOString() },
      { status: 500 }
    )
  }
}
```
