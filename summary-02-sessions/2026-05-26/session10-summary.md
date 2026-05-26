# Session 10 — 2026-05-26

## 完成事項

### 1. 確認 10 個 app prompt 批次完成（Track A 收尾）

前一 session 派出的多個自主 agent 已全部完成（buildmaster、filesense、meetingmind、studybuddy 等）。
共新增 30 個檔案（10 個 app × 3 個 prompt 檔），commit `a03cee7` 已推送至 GitHub。
使用者詢問 studybuddy 是否需補做 → 確認 studybuddy 已在本批次中完成，無需重做。

### 2. 為 aihcr-daily/web 建立自主開發 prompt 套組（Track B 完成）

**需求**：為已存在的生產 Next.js 16 應用建立一套 app_spec.txt + initializer_prompt.md + coding_prompt.md，使未來的自主 coding agent 可以持續維護這個 app。

**深度閱讀的程式碼範圍**：

- `lib/types.ts` — Category、Room、KpiCounts、DashboardData、UserInsight、UserInsightsData 全部型別
- `lib/loadData.ts` — loadDashboardData()、loadUserInsights()、getStatusLabel()（含 ZERO_KPI fallback 邏輯）
- `app/page.tsx` — 主 Dashboard（force-dynamic、KpiGrid + CategoryPie + RoomTable + UserInsights）
- `app/api/status/route.ts` — 公開 health check（cache-control 設定、pickString 安全 sanitizer）
- `app/api/analyze-user/route.ts` — localhost-only、rate limit 10/hr、validateUserName()、isActiveUser() whitelist、NFC normalize
- `app/api/issues/route.ts` — GitHub issue 建立、GITHUB_FAE_TOKEN 環境變數
- `app/fae/page.tsx` — use client FAE form
- `app/fae/audit/page.tsx` — 平行抓 3 label GitHub issues
- `app/insight/[user]/page.tsx` — ReactMarkdown + urlTransform 安全保護

**建立的 3 個檔案**（commit `29bc196`，repo：chenghyang2001/aihcr-daily）：

| 檔案 | 大小 | 重點差異 |
|------|------|---------|
| `web/prompt/app_spec.txt` | 12.6 KB | XML 規格：4 頁面、5 API routes、TypeScript 型別、資安規則、品質標準 |
| `web/prompt/initializer_prompt.md` | 7.4 KB | **既有程式庫讀取優先**，不 scaffold；`****NUM_FEATURES****` 佔位符 |
| `web/prompt/coding_prompt.md` | 14.5 KB | Next.js 版 SOP：`localhost:3000`（非 8501）、`npm run build` 為品質閘 |

### 3. 設計決策：既有 vs 新建 app 的 prompt 差異

此次 aihcr 的 prompt 套組與其他 11 個「從零建立」的 app 最大差異：

- **initializer** 開頭聲明 `type: existing_nextjs_app`，Step 1 全改為「讀現有程式碼」指令（`cat`、`find`、`ls`）
- **不執行 scaffold**（不 `npm init`、不 `create-next-app`、不建資料夾結構）
- **安全規則**明確寫入 spec（localhost-only、shell injection 防禦、NFC normalize、GITHUB_FAE_TOKEN 禁止 bundle）
- **coding_prompt** 測試 URL 改為 `localhost:3000`，品質閘改為 `npm run build`（無 Python venv、無 Alembic）

---

## 關鍵技術筆記

### Next.js App Router 特有安全模式

```typescript
// localhost-only enforcement (analyze-user / run-pipeline)
const host = request.headers.get("host") ?? "";
if (!["localhost", "127.0.0.1", "[::1]"].includes(host.split(":")[0])) {
  return NextResponse.json({ error: "Forbidden" }, { status: 403 });
}

// NFC normalize for CJK username matching
const normalized = decodeURIComponent(rawParam).normalize("NFC");

// Child process spawn (not exec) to avoid stdout buffer overflow
const child = spawn("python3", ["scripts/analyze_users.py", "--users", userName], { cwd: repoRoot });
```

### Vercel 相容性制約

- `loadDashboardData()` 用靜態 import（build-time）而非 runtime `fs.readFile`，因為 Vercel Edge 無 fs
- `/insight/[user]` 例外：用 runtime `fs.readFile` 因為需要 analyze 後的最新資料
- `export const runtime = "nodejs"` 必須加在用 fs 的 API route

### 12 個 app 的相似度分析

使用者問哪個 app 最像 aihcr-daily web → **APIWatcher**（同為 FastAPI/Streamlit 監控 dashboard）。
主要差異：aihcr 是 Next.js SSR + 靜態 JSON 資料流；APIWatcher 是 Streamlit + SQLite + APScheduler 主動輪詢。

---

## 產出檔案

| 路徑 | 類型 | Repo | Commit |
|------|------|------|--------|
| `web/prompt/app_spec.txt` | 新建 | aihcr-daily | 29bc196 |
| `web/prompt/initializer_prompt.md` | 新建 | aihcr-daily | 29bc196 |
| `web/prompt/coding_prompt.md` | 新建 | aihcr-daily | 29bc196 |
| `prompts/specs/` (30 files, 10 apps) | 新建（前 session agent 完成）| anthropic-quickstarts | a03cee7 |

---

## HANDOFF（下次 session 優先處理）

### 立即行動

- [ ] 若需要讓 aihcr 進入自主開發流程，下一步是在 aihcr-daily/web 執行 initializer agent：`claude -p "$(cat web/prompt/initializer_prompt.md)"` 從 web/ 目錄執行以建立 feature_list.json
- [ ] anthropic-quickstarts 的 12 個 app spec 均已完備，可以開始實際執行 autonomous coding loop（`./autonomous_cli_loop.sh <app-name> <iterations>`）
- [ ] 確認 app-apiwatcher 與 app-codereviewbot 的 prompt 路徑格式一致（之前 apiwatcher 有搬遷）

### 進行中（需接續）

- **12 個 autonomous coding app spec** 全部建立完成，尚未實際執行 coding loop。下一步是挑選一個 app 開始跑（建議從 apiwatcher 或 codereviewbot 開始，規格最完整）。
- **aihcr-daily web prompt** 剛建立，尚未執行 initializer agent 建立 feature_list.json。

### 注意事項

- aihcr-daily/web 的 `public/data/latest.json` 在本機可能不存在（由 NUC pipeline push），initializer agent 必須預期這種情況（`ls public/data/ || echo "not found"` 是正常的）
- `DISABLE_WRITER_QA_HOOK=1` 必須在執行任何 autonomous coding agent 前設定，否則全域三 agent 鐵律 hook 會攔截 sub-agent 的程式碼寫入
- autonomous_cli_loop.sh 要用 `INITIALIZER_PROMPT` / `CODING_PROMPT` 環境變數（Linux 版），非 Windows 版的 `_WIN` 後綴變數
