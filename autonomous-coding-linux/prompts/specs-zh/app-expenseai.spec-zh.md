# 應用程式規格：ExpenseAI — 智慧費用追蹤（含 AI 自動分類）

## 專案概述

ExpenseAI 是一款桌面個人財務應用程式，結合手動費用記錄、AI 自動收據處理與消費分析。使用者可手動輸入費用、匯入銀行對帳單 CSV，或拍攝收據讓 Claude 自動萃取並分類。應用程式強制執行每個類別的月度預算，並在接近上限時通知使用者。每個月，Claude 會產生個人化消費洞察報告，比較各月模式並標記異常交易。本應用程式專注於乾淨、快速的每日費用記錄工作流，不需要雲端連線。

---

## 技術堆疊

| 層級         | 技術                                          |
|--------------|-----------------------------------------------|
| 語言         | Python 3.11+                                  |
| GUI 框架     | PyQt6                                         |
| 資料庫       | SQLite（透過 SQLAlchemy 2.x ORM）             |
| AI           | Anthropic Claude API (`claude-sonnet-4-6`)    |
| 資料分析     | pandas                                        |
| 圖表         | matplotlib（內嵌 PyQt6 FigureCanvas）         |
| PDF 匯出     | reportlab                                     |
| Excel 匯出   | openpyxl                                      |
| 貨幣         | 離線 JSON 快取（exchangerate-api 快照）       |
| 依賴套件     | anthropic, sqlalchemy, pandas, matplotlib,    |
|              | reportlab, openpyxl, PyQt6, Pillow            |

---

## 核心功能

### 1. 手動費用輸入
- 快速輸入對話框：金額、商家名稱、日期（日期選擇器）、備註
- 類別下拉選單（預先填入，使用者可擴充）
- 鍵盤快捷鍵：從應用程式任何位置按 Ctrl+N 開啟輸入對話框
- 重複偵測：24 小時內相同商家 + 金額時給予警告
- 定期費用範本：定義每月帳單，到期日時自動建議
- 輸入驗證：金額 > 0、日期不得為未來日期、類別為必填

### 2. 收據照片匯入（Claude OCR）
- 匯入方式：檔案對話框（jpg/png/webp）或拖放至主視窗
- 圖片編碼為 base64，送至 Claude vision API
- Claude 萃取：商家名稱、總金額、日期、貨幣、明細項目（若可見）
- 回傳結構化 JSON：`{merchant, amount, date, currency, items: [{name, price}]}`
- 使用者在儲存前審閱預填表單；所有欄位可編輯
- OCR 失敗時顯示 Claude 原始回應供人工修正
- 收據圖片以檔案路徑參照儲存（非嵌入資料庫）

### 3. AI 自動分類
- 所有費用（手動或匯入）均由 Claude 自動分類
- 分類提示詞包含商家名稱 + 備註上下文
- 類別：餐飲、交通、公用事業、娛樂、健康、購物、教育、旅遊、訂閱、其他（使用者可新增自訂類別）
- 顯示信心度：HIGH / MEDIUM / LOW — 信心度 LOW 時使用者可覆蓋
- 分類規則本地快取：同一商家出現 3 次以上，使用快取類別
- 批次重新分類：選取費用並一次對全部執行 Claude

### 4. 預算設定與超支警報
- 設定每類別每月預算（例如：餐飲：$400、娛樂：$100）
- 每類別進度條：綠色（< 75%）、黃色（75–99%）、紅色（>= 100%）
- 任何類別達到預算的 80% 和 100% 時發出桌面通知
- 預算結轉選項：未使用預算加入下個月（每類別設定）
- 預算與實際比較圖表：每類別水平長條圖
- 「預計支出」計算：當前支出 / 已過天數 * 本月天數

### 5. 每月消費報告
- 圓餅圖：所選月份的類別消費分布
- 類別明細表格：計劃 vs 實際、差異、佔總計百分比
- 趨勢線：過去 6 個月每類別的月度總計（折線圖）
- 本月消費金額前 5 名商家
- 星期幾消費熱力圖：哪些天花費最多
- 比較切換：在所有圖表上疊加上個月資料

### 6. Claude 每月洞察報告
- 手動觸發（「產生洞察」）或月底自動觸發
- Claude 接收彙總消費資料（非原始交易，保護隱私）
- 洞察內容：
  - 各類別的月對月變化（百分比和絕對值）
  - 商家頻率分析（「8 次 Starbucks = $62」）
  - 預算遵守評分（0–100）
  - 3 項具體可行建議
  - 異常標記：任何費用 > 類別平均的 2 倍
- 洞察儲存至 monthly_summaries 資料表，可在歷史中檢視

### 7. 銀行對帳單 CSV 匯入
- 解析器支援常見格式：Visa CSV、Mastercard CSV、通用 4 欄格式
- 欄位對應精靈：首次匯入時使用者將 CSV 欄位對應至系統欄位
- 每家銀行儲存對應設定（未來匯入時重複使用）
- 重複偵測：略過符合既有記錄的列（日期 + 金額 + 商家）
- 匯入預覽：提交前顯示已解析列，標示潛在重複項目
- 錯誤列報告：顯示無法解析的列及原因

### 8. 匯出選項
- PDF 報告：含圖表的月度摘要（reportlab，A4 版面）
- CSV：所有費用含所有欄位，可依日期範圍篩選
- Excel：依類別 x 月份的樞紐分析表（openpyxl）
- 匯出對話框含：日期範圍、類別篩選、是否包含圖表
- 若在設定中啟用，月底自動匯出

---

## 資料庫 Schema

```sql
CREATE TABLE expenses (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    amount          DECIMAL(10, 2) NOT NULL CHECK (amount > 0),  -- 金額
    currency        TEXT NOT NULL DEFAULT 'USD',                  -- 貨幣
    amount_usd      DECIMAL(10, 2),              -- 換算後的 USD 金額（供彙總用）
    merchant        TEXT NOT NULL,               -- 商家名稱
    category_id     INTEGER REFERENCES categories(id),
    date            DATE NOT NULL,               -- 消費日期
    notes           TEXT DEFAULT '',             -- 備註
    receipt_path    TEXT,                        -- 收據圖片檔案路徑
    source          TEXT DEFAULT 'manual',       -- manual | receipt | csv_import
    ai_category     TEXT,                        -- Claude 的建議類別
    ai_confidence   TEXT DEFAULT 'HIGH',         -- HIGH | MEDIUM | LOW
    user_overridden BOOLEAN DEFAULT 0,           -- 使用者是否已覆蓋
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL UNIQUE,            -- 類別名稱
    color       TEXT DEFAULT '#4A90E2',          -- 顏色
    icon        TEXT DEFAULT '📂',              -- 圖示
    is_custom   BOOLEAN DEFAULT 0,              -- 是否為自訂類別
    sort_order  INTEGER DEFAULT 99              -- 排序順序
);

CREATE TABLE budgets (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    category_id     INTEGER NOT NULL REFERENCES categories(id),
    amount          DECIMAL(10, 2) NOT NULL,     -- 預算金額
    month           TEXT NOT NULL,               -- 格式：YYYY-MM
    carry_over      BOOLEAN DEFAULT 0,           -- 是否結轉
    carry_over_amt  DECIMAL(10, 2) DEFAULT 0,    -- 結轉金額
    UNIQUE (category_id, month)
);

CREATE TABLE monthly_summaries (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    month           TEXT NOT NULL UNIQUE,        -- 格式：YYYY-MM
    total_spend     DECIMAL(10, 2),              -- 總支出
    budget_score    INTEGER,                     -- 0–100
    claude_insight  TEXT,                        -- AI 洞察文字
    generated_at    DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 架構 / UI 版面

```
┌─────────────────────────────────────────────────────────────┐
│  ExpenseAI                         [Ctrl+N 新增]  [_ □ ×]  │
├────────────────────────────┬────────────────────────────────┤
│  類別側邊欄                │  主要交易清單                  │
│                            │                                │
│  本月：$1,247 / $2k        │  [2025 年 5 月 ▾] [搜尋...] [⚙]│
│  ────────────────────      │  ─────────────────────────     │
│  🍔 餐飲                   │  日期    商家       金額  類別 │
│  ████████░░ $320/$400      │  5/26   Starbucks $6.50  ☕  │
│                            │  5/25   Uber      $12.3  🚗  │
│  🚗 交通                   │  5/25   Amazon    $89.0  🛍  │
│  ██░░░░░░░░ $45/$150       │  5/24   全聯      $67.2  🍔  │
│                            │  5/23   Netflix   $15.9  📺  │
│  📺 娛樂                   │  ...                           │
│  ██████████ $102/$100 ⚠️   │                                │
│                            │  ─────────────────────────     │
│  💊 健康                   │  本次檢視合計：$191.20         │
│  ██░░░░░░░░ $30/$200       │                                │
│                            │                                │
│  [+ 新增預算]              │  [匯入收據] [匯入 CSV]         │
├────────────────────────────┴────────────────────────────────┤
│  AI 洞察面板（可收合）                                      │
│  「本月餐飲比 3 個月平均多 40%。                            │
│   8 次 Starbucks = $62。考慮在家沖咖啡。」                  │
│  [產生新洞察]                     最後更新：5/26 10:31      │
└─────────────────────────────────────────────────────────────┘

每月報告檢視：
┌────────────────────────────────┬────────────────────────────┐
│  圓餅圖（matplotlib）          │  類別表格                  │
│                                │  類別     計劃  實際  %    │
│      🍕 餐飲 32%               │  餐飲    $400   $320  80%  │
│      🚗 交通 12%               │  交通    $150   $45   30%  │
│      🛍 購物 28%               │  娛樂    $100  $102  102%⚠│
│                                │  健康    $200   $30   15%  │
│                                │                            │
└────────────────────────────────┴────────────────────────────┘
```

---

## 關鍵互動

### 互動 1：透過 Claude Vision 匯入收據
```
使用者將收據圖片拖放至主視窗
  → 開啟 ReceiptImportDialog，含圖片預覽
  → 讀取圖片檔案，編碼為 base64
  → Claude API 呼叫（vision 模型）：
      提示詞：「從這張收據中萃取：商家名稱、總金額、
               日期、貨幣。回傳 JSON：{merchant, amount, date, currency}」
  → 解析 JSON 至表單欄位
  → 使用者審閱預填對話框：
      商家：「Whole Foods Market」（可編輯）
      金額：$67.20（可編輯）
      日期：2025-05-24（可編輯）
      類別：[AI 建議「餐飲」→ 顯示為預選]
  → 使用者點擊儲存
  → 插入費用列，儲存 receipt_path
  → 類別側邊欄更新預算進度條
```

### 互動 2：預算超支警報
```
使用者儲存娛樂費用 $5（當前合計：$98/$100）
  → 儲存後觸發預算檢查：
      SELECT SUM(amount_usd) FROM expenses
      WHERE category_id=X AND strftime('%Y-%m', date)='2025-05'
  → 結果：$103 > $100 預算
  → 發出桌面通知：
      「娛樂預算已超支！本月已花費 $103，預算 $100。」
  → 類別側邊欄進度條變紅
  → 交易清單標題標示超支類別
  → 重新計算「預計支出」並顯示於側邊欄
```

### 互動 3：Claude 每月洞察生成
```
使用者點擊「產生 2025 年 5 月洞察」
  → 執行彙總查詢（不傳送原始交易至 Claude）：
      {
        month: "2025 年 5 月",
        total_spend: 1247,
        categories: [{name: "餐飲", actual: 320, budget: 400, tx_count: 24}, ...],
        top_merchants: [{"Starbucks": 62, visits: 8}, ...],
        vs_last_month: {total_change: +12%, food_change: +40%, ...}
      }
  → 以彙總 JSON + 洞察提示詞呼叫 Claude
  → Claude 回傳結構化洞察文字（400–600 字）
  → 洞察儲存至 monthly_summaries.claude_insight
  → AI 洞察面板更新為新內容
  → 從 Claude 回應中萃取預算評分（0–100），儲存
```

---

## 實作步驟

1. **專案鷹架**：PyQt6 主視窗，4 張資料表的 SQLAlchemy 模型，預設類別（10 個內建），啟動時執行 `create_all` 資料庫遷移。

2. **費用 CRUD**：AddExpenseDialog 含表單驗證，ExpenseListWidget（QTableWidget）含排序 / 篩選，含撤銷的行內刪除，重複偵測查詢。

3. **類別側邊欄**：CategorySidebarWidget 使用 QListWidget，預算進度條（自訂樣式的 QProgressBar），費用新增 / 刪除時即時更新。

4. **收據匯入**：ReceiptImportDialog，base64 圖片編碼，Claude vision API 呼叫含 JSON 回應解析，預填表單欄位，錯誤退回手動輸入。

5. **CSV 匯入**：CSVImportWizard（3 步驟：選擇檔案 → 欄位對應 → 預覽/確認），將對應設定儲存至設定 JSON，匯入時偵測重複。

6. **預算管理**：BudgetDialog（每類別 / 月份），使用 `plyer.notification` 超支通知，預計支出計算，結轉邏輯。

7. **報告與圖表**：ReportWidget 含 matplotlib FigureCanvas，圓餅圖 + 類別表格 + 趨勢線，月份選擇器，上個月疊加切換。

8. **Claude 洞察 + 匯出**：`claude_insight.py` 建構彙總酬載，呼叫 API，解析回應；ExportDialog 產生 PDF（reportlab）/ CSV / Excel（openpyxl）。

---

## 成功標準

### 功能性
- 收據 OCR 從清晰收據中萃取正確商家和金額的成功率 > 85%
- CSV 匯入 500 列 < 2 秒，重複偵測正確
- 費用儲存導致超支後 1 秒內觸發預算警報
- Claude 每月洞察在 15 秒內產生
- PDF 匯出產生含嵌入圖表、可閱讀的 A4 報告

### 使用者體驗
- 從任何畫面按 Ctrl+N 在 100ms 內開啟輸入對話框
- 交易清單篩選 / 搜尋 5,000 筆以上列，無延遲
- 每次儲存後類別側邊欄預算進度條即時更新
- 收據匯入對話框以正確長寬比顯示圖片預覽

### 技術品質
- 所有金額以 DECIMAL 儲存，絕不用 float（避免捨入誤差）
- pandas 彙總查詢在從資料庫載入的記憶體 DataFrame 上執行（非原始 SQL 迴圈）
- Claude API 呼叫不阻塞：QThread worker 搭配 signal/slot 進行 UI 更新
- 收據圖片絕不嵌入資料庫；僅儲存檔案路徑
- `ANTHROPIC_API_KEY` 從環境變數讀取，絕不硬編碼
- 單元測試：預算超支偵測、CSV 欄位對應、SM-2（共用模組）
