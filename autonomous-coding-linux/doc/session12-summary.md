# Session 12 — 2026-05-27（CI/CD Pipeline 除錯完成）

## 完成事項

### 1. 診斷 verify-and-merge.yml 無法被 repository_dispatch 觸發

**根本原因**：Python heredoc（`<<'PYEOF'`）放在 `run: |` YAML block scalar 內，heredoc 內容從 column 0 開始 → YAML block scalar 提前終止 → GitHub YAML parser 視整份 workflow YAML 為無效檔案 → `repository_dispatch` 觸發後靜默不執行。

**症狀**：

- `repository_dispatch` 送出 HTTP 204（已接受）但 GitHub Actions 看不到新 run
- 在「push」事件下出現「0s failure」的 workflow run，說明「This run likely failed because of a workflow file issue」

**驗證方式**：用 `python -c "import yaml; yaml.safe_load(open('file'))"` 確認 → `YAML ERROR: while scanning a simple key, line 68, column 1: import json, sys`

### 2. 修復 verify-and-merge.yml（兩個 bug）

**Bug 1：YAML heredoc 問題**（commit `deba3f1895efcf9fe11e9b201750e1f26f761971`）

- 原因：Python heredoc 內容在 column 0 破壞 YAML block scalar
- 修法：改用 shell 變數 `PY="..."` 儲存 Python one-liner，透過 `python3 -c "$PY"` 執行
- 額外挑戰：寫入包含 YAML 單引號的 shell heredoc 本身也會失敗 → 改用 Python 寫檔（raw string，完全繞過 shell quoting）

**Bug 2：`gh pr merge` 找不到 git repo**（commit `59f4e6d2fb3ebcd281afec2ba17cb23146f99967`）

- 原因：`repository_dispatch` workflow 沒有 `actions/checkout` → runner 無 `.git` 目錄 → `gh` CLI 無法推斷 remote
- 症狀：`fatal: not a git repository (or any of the parent directories): .git`
- 修法：所有 `gh pr merge` / `gh issue close` / `gh pr comment` 加 `--repo "${{ github.repository }}"` 旗標

### 3. 端對端 Pipeline 驗證完成

最終結果（2026-05-27）：

- Issue #1 創建 ✅
- Workflow 1（`issue-to-feature.yml`）觸發：branch `feature/issue-1` 建立 + PR #2 開啟 + VPS SSH 啟動 ✅
- VPS 完成 Feature #42（42/42 features pass）+ 送出 `repository_dispatch` ✅
- Workflow 2（`verify-and-merge.yml`）觸發：feature 驗證通過 + health HTTP 200 ✅
- PR #2 squash-merged（`2026-05-27T08:02:20Z`）+ branch deleted ✅
- Issue #1 closed（`2026-05-27T08:02:21Z`，`state_reason: "completed"`）✅

---

## 關鍵學到的事

| 教訓 | 細節 |
|------|------|
| YAML block scalar + heredoc 致命組合 | `run: |` 下的 heredoc 內容必須縮排；column 0 等於結束 block scalar |
| `repository_dispatch` 靜默失敗 | HTTP 204 只代表事件被接受，不代表 workflow 會跑；YAML 無效時靜默不執行 |
| `gh` CLI 無 checkout 需 `--repo` | `repository_dispatch` workflow 沒有本地 git 上下文，`--repo` 是必要旗標 |
| Python 寫檔繞過 shell quoting | 需要寫含單/雙引號的複雜內容時，用 Python raw string 比 bash heredoc 更可靠 |
| YAML 驗證指令 | `python3 -c "import yaml; yaml.safe_load(open('file'))"` 可快速定位 YAML parse 錯誤 |

---

## Pipeline 最終架構

```
GitHub Issue (label: feature-request)
  → issue-to-feature.yml
    → 建立 feature/issue-N branch
    → 開 PR
    → SSH VPS：nohup run_feature_loop.sh & （async）
        → DISABLE_WRITER_QA_HOOK=1 autonomous_cli_loop.sh
        → git push
        → curl /dispatches → repository_dispatch: vps-coding-complete
  → verify-and-merge.yml
    → SSH VPS：讀 feature_list.json 驗 passes
    → curl /health 驗服務存活
    → PASS：gh pr merge --squash --repo + gh issue close --repo
    → FAIL：gh pr comment --repo（留待人工處理）
```

### 所需 GitHub Secrets

| Secret | 值 |
|--------|---|
| `VPS_SSH_PRIVATE_KEY` | VPS 私鑰 |
| `VPS_HOST` | `187.127.109.145` |
| `VPS_USER` | `root` 或 `claude` |
| `GH_PAT` | GitHub PAT（repo scope） |
