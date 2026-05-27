# Session 13 Summary — 2026-05-28

## 完成事項

### 1. PodcastBrain CI/CD GitHub Actions 工作流修復（podcastbrain-harness repo）

本 session 從前次 session 遺留的「OAuth 認證失敗」問題繼續，主要除錯兩個獨立 bug 並修復工作流：

#### Bug 1：YAML heredoc 與 GitHub go-yaml parser 衝突（commit `565c42d`）
- **根本原因**：`python3 - << 'PYEOF'` 語法的 Python body 出現在 YAML `run: |` block scalar 的第 0 欄，導致 GitHub go-yaml parser 誤判 block scalar 已結束，拒絕整個 workflow（HTTP 422）。
- **現象**：`gh workflow run` 回傳 HTTP 422「does not have workflow_dispatch trigger」；GitHub UI 顯示「This run likely failed because of a workflow file issue」。
- **修法**：將所有 `python3 - << 'PYEOF'` 改為 `python3 -c "..."` 多行字串。Python 程式碼與 YAML 縮排對齊，go-yaml 不再誤解析。
- **驗證**：QA agent 5 層驗證通過（V1 exists / V2 SHA256 `9e2af8a` / V3 yaml.safe_load / V4 3 test cases / V5 heredoc grep）。

#### Bug 2：CLAUDE_CREDENTIALS secret 含 9 個多餘位元組（commit `db7dc4f`）
- **根本原因**：GitHub Secret `CLAUDE_CREDENTIALS` 的內容為 480 bytes（strip newline 後），本機 `~/.claude/.credentials.json` 為 471 bytes；多出 9 bytes 在有效 JSON 結尾後，導致 `json.JSONDecodeError: Extra data: line 1 column 472 (char 471)`。
- **防禦修法**：在工作流 restore step 加 `| tr -d '\r\n'`，strip 前後 `\r\n`。
- **根本修法**（使用者需手動）：用 `python3 -c "import json,sys; print(json.dumps(json.load(open('/c/Users/user/.claude/.credentials.json'))), end='')"` 取得乾淨的 JSON，重新設定 GitHub Secret。

### 2. 工作流整體品質提升
- Shell injection 防禦：所有 `github.event.inputs.*` 移入各 step `env:` 區塊，run script 改用 `$ENV_VAR`
- Path traversal 防禦：`project_name` 在 "Show feature results" step 加 `^[a-zA-Z0-9_-]+$` regex 白名單驗證
- upload-artifact `path: generations/`（固定字串，不展開 `${{ }}`）

### 3. Writer→QA→Reviewer 三 agent 鐵律正確執行
- `build-podcastbrain.yml`（`.yml` 副檔名）觸發 medium 複雜度評估
- Writer 產出 175 行，SHA256 `9e2af8a`（exact: `9e2af8a8c80fcb19a03bd7c38c2d9550cabd9bad0e1f123122d45dcf08af02be`）
- QA 5 層全 PASS：存在性 / 雜湊吻合 / YAML 語法 / 動態 3 test case / heredoc grep 乾淨
- Reviewer 選擇不派（使用者在 test 循環中不需要）

## 關鍵技術筆記

### YAML block scalar + bash heredoc 衝突（永久規則）
GitHub go-yaml v3 parser 在解析 `run: |` block scalar 時，若 Python code 出現在第 0 欄（與 `run:` 同縮排），會視為 block scalar 結束。**解決方案**：一律用 `python3 -c "..."` 多行字串，Python code 保持 YAML 縮排層（通常 10 spaces），go-yaml 不誤判。

### GitHub Secret 內容長度不等於本機檔案
GitHub Secret 儲存時可能含有額外字元（換行、空白），`wc -c` 本機是 471 bytes 不代表 secret 也是 471 bytes。防禦：(1) 寫入前 `tr -d '\r\n'`；(2) 設 secret 時用 Python `json.dumps()` re-serialize，保證無額外內容。

### gh run view 快速診斷
```bash
gh run view <run_id> --repo <owner/repo>           # 看步驟概覽
gh run view <run_id> --repo <owner/repo> --log-failed  # 看失敗步驟完整 log
```

## 產出檔案

| 檔案 | 操作 | commit | 說明 |
|------|------|--------|------|
| `podcastbrain-harness/.github/workflows/build-podcastbrain.yml` | 修改 | `565c42d` | heredoc → python3 -c 修復（175 行） |
| `podcastbrain-harness/.github/workflows/build-podcastbrain.yml` | 修改 | `db7dc4f` | tr -d '\r\n' 防禦 secret 換行 |

---

## HANDOFF（下次 session 優先處理）

### 立即行動
- [ ] **更新 CLAUDE_CREDENTIALS GitHub Secret**：在 Git Bash 執行 `python3 -c "import json,sys; print(json.dumps(json.load(open('/c/Users/user/.claude/.credentials.json'))), end='')"` → 複製輸出 → 到 [https://github.com/chenghyang2001/podcastbrain-harness/settings/secrets/actions](https://github.com/chenghyang2001/podcastbrain-harness/settings/secrets/actions) 更新 `CLAUDE_CREDENTIALS`
- [ ] **重觸發測試 run**：`gh workflow run build-podcastbrain.yml --repo chenghyang2001/podcastbrain-harness --field project_name=test_run5 --field num_features=1 --field max_iterations=8`，確認 "Restore Claude OAuth credentials" step 綠燈 + Claude CLI 認證通過（無 "Not logged in" 訊息）
- [ ] **若認證通過後 harness 執行**：確認 1 feature run 完整跑完，artifact `generations/test_run5/` 上傳成功

### 進行中（需接續）
- podcastbrain-harness CI/CD 整體可用狀態：YAML 已修、secret trailing bytes 已有防禦，缺最後一步「secret 更新」才能真正通過認證
- 工作流 test_run4 在 run `26541634212` 時仍失敗（同 Extra data 錯誤），確認 `tr -d '\r\n'` 跑的是 `db7dc4f` 的版本（log 顯示確實有 `| tr -d '\r\n'`，但 secret 本身 9 byte 問題超出 strip 範圍）

### 注意事項
- **Secret 問題根因**：secret 有 480 bytes（strip 後），不是單純的 `\n`（1 byte）而是 9 bytes 額外資料在有效 JSON 之後。`tr -d '\r\n'` 只能 strip newlines，無法去掉這 9 bytes（可能是空格、BOM、或其他字元）。根本解：重新設 secret，用 `json.dumps()` 保證乾淨。
- **OAuth token 有效期**：本機 `expiresAt` 是 1779934669115（2026-04 驗證時有 269 分鐘剩餘），token 會自動 refresh（有 refreshToken），但需要確認 GitHub Actions runner 上 OAuth refresh 是否正常觸發
- **run_number 連續性**：test_run1~run4 已消耗，下次從 test_run5 開始
