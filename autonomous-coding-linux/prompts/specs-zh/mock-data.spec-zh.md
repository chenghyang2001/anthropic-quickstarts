# 模擬資料檔案規格書

## 概述

產生 JSON 資料檔案，模擬真實的 HookHub API 回應。
每個檔案代表不同的資料情境或端點回應。

## 檔案規範

- 檔名：`<情境名稱>.mock.json`
- 位置：`src/data/mocks/`
- 純 JSON（不含 TypeScript）
- 必須是有效、可解析的 JSON
- 所有日期使用 ISO 8601 格式
- 所有 ID 使用 kebab-case 字串

## 可用的資料型別

### Hook 項目
```json
{
  "id": "kebab-case-id",
  "name": "顯示名稱",
  "category": "UTILITY|SECURITY|WORKFLOW|MONITORING|TESTING|LEARNING|INTEGRATION|TEAM",
  "description": "1-2 句說明",
  "githubUrl": "https://github.com/作者/repo",
  "author": "github用戶名",
  "stars": 1234,
  "language": "Python|TypeScript|Go|JavaScript|PHP|Rust",
  "hookTypes": ["PRE_TOOL_USE", "POST_TOOL_USE", "STOP", "NOTIFICATION", "SUBAGENT_START", "SUBAGENT_STOP"],
  "featured": true,
  "downloads": 5678,
  "lastUpdated": "2025-05-01T00:00:00Z",
  "tags": ["security", "automation"],
  "version": "1.2.0",
  "license": "MIT"
}
```

### 使用者個人資料
```json
{
  "id": "user-id",
  "username": "github-handle",
  "displayName": "全名",
  "avatarUrl": "https://avatars.githubusercontent.com/...",
  "bio": "簡短自我介紹",
  "hooksPublished": 5,
  "totalStars": 1200,
  "joinedAt": "2024-01-01T00:00:00Z"
}
```

### API 回應包裝
```json
{
  "data": [...],
  "meta": {
    "total": 100,
    "page": 1,
    "perPage": 20,
    "totalPages": 5
  },
  "success": true,
  "timestamp": "2025-05-26T00:00:00Z"
}
```

## 變體設計規範

每個模擬檔案應代表不同的情境：
- 不同的類別 / 篩選狀態
- 不同的分頁頁數
- 不同的排序方式（依星星數、最新、依下載數）
- 邊界案例：空結果、單一結果、最大結果
- 每個檔案最少 10 筆、最多 25 筆 Hook 資料
- 所有資料必須真實且與 HookHub 相關（不用 lorem ipsum）
- 星星數範圍：10–20000，下載數範圍：50–100000
