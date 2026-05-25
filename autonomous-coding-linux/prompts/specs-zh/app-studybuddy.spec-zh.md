# 應用程式規格：StudyBuddy — AI 間隔重複學習應用

## 專案概述

StudyBuddy 是一款桌面閃卡應用程式，結合 SM-2 間隔重複演算法與 Claude AI，將原始筆記轉換為結構化學習素材。使用者匯入 Markdown、PDF 或純文字檔案後，Claude 會自動產生高品質的問答閃卡。在學習過程中，當使用者答錯時，Claude 會提供帶有範例的情境說明以強化理解。應用程式追蹤長期記憶保留指標，並支援以 Anki 相容格式匯出牌組。

---

## 技術堆疊

| 層級         | 技術                                         |
|--------------|----------------------------------------------|
| 語言         | Python 3.11+                                 |
| GUI 框架     | PyQt6                                        |
| 資料庫       | SQLite（透過 SQLAlchemy 2.x ORM）            |
| AI           | Anthropic Claude API (`claude-sonnet-4-6`)   |
| PDF 解析     | pdfplumber                                   |
| Markdown     | python-markdown2                             |
| 匯出         | genanki（Anki .apkg 匯出）                   |
| 圖表         | matplotlib（內嵌於 PyQt6 widget）            |
| 依賴套件     | anthropic, sqlalchemy, pdfplumber, genanki,  |
|              | markdown2, matplotlib, PyQt6                 |

---

## 核心功能

### 1. 筆記匯入與 AI 閃卡生成
- 透過拖放或檔案對話框接受 Markdown（.md）、PDF 及純文字（.txt）檔案
- 清除格式後將分段內容送至 Claude 進行問答萃取
- Claude 回傳結構化 JSON：`[{"question": "...", "answer": "...", "type": "basic"}]`
- 完形填充偵測：Claude 自動識別填空機會
- 使用者可在儲存至牌組前審閱、編輯或刪除生成的卡片

### 2. SM-2 間隔重複排程器
- 實作 SM-2 演算法：每張卡片的間隔天數、簡易係數、重複次數
- 每次複習後評分 1–5；1–2 重置間隔，3 以上推進排程
- 每張卡片的 `next_review` 日期計算後儲存至資料庫
- 開始學習時依逾期天數排序（最逾期者優先）
- 每日新卡數量可設定（預設：20 張新卡 + 所有到期卡）

### 3. 多種卡片類型
- **基本問答**：正面（問題）翻轉至背面（答案）
- **完形填充**：`{{c1::答案}}` 語法在正面呈現填空文字
- **圖片遮擋（模擬）**：匯入圖片上的佔位遮罩（未來功能預留）
- 卡片類型儲存於資料庫；渲染器依 type 欄位切換版面
- 批次卡片類型轉換：選取多張卡片，一鍵變更類型

### 4. 每日學習課程
- 全螢幕極簡模式：每次顯示一張卡片，支援鍵盤快捷鍵（空格翻卡，1–5 評分）
- 完成後顯示課程摘要：複習張數、平均評分、花費時間
- 連續記錄：追蹤連續有複習的天數
- 「撤銷上次評分」按鈕，防止誤點
- 課程進度條：顯示剩餘卡數 / 到期總數

### 5. AI「為什麼我答錯了」說明
- 評分 1 或 2 後出現「說明我的錯誤」按鈕
- 將問題及使用者作答情境送至 Claude 取得說明
- Claude 回傳：根本原因、更正說明、記憶技巧、真實案例
- 說明儲存於卡片供日後參考（可在卡片編輯器中檢視）
- 速率限制：每次課程最多 10 次 AI 說明，控管 API 成本

### 6. 牌組組織
- 階層式牌組結構：科目包含子牌組（最多 3 層）
- 標籤：每張卡片以逗號分隔，可在牌組檢視中篩選
- 牌組顏色標籤與圖示，便於快速視覺識別
- 搜尋：全文搜尋卡片正面與背面
- 批次操作：跨牌組移動、刪除、暫停卡片

### 7. 學習統計
- 每個牌組保留率：過去 30 天評分 3 以上的卡片百分比
- 連續日曆熱力圖：GitHub 風格活動格狀圖
- 隨時間學習的卡片數：累積折線圖
- 平均簡易係數趨勢：顯示牌組是否越來越難或越來越容易
- 以 CSV 格式匯出統計資料

### 8. Anki 匯出
- 使用 `genanki` 函式庫產生 .apkg 檔案
- 將 StudyBuddy 卡片類型對應至 Anki 筆記類型（Basic、Cloze）
- 包含排程資料：間隔天數、簡易係數、到期日
- 牌組階層保留於 Anki 牌組名稱（父::子格式）
- 可匯出單一牌組或全部牌組

---

## 資料庫 Schema

```sql
CREATE TABLE decks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    name        TEXT NOT NULL,            -- 牌組名稱
    parent_id   INTEGER REFERENCES decks(id),  -- 父牌組（階層用）
    color       TEXT DEFAULT '#4A90E2',   -- 顏色標籤
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
    description TEXT                      -- 牌組說明
);

CREATE TABLE cards (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    deck_id         INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
    front           TEXT NOT NULL,        -- 卡片正面（問題）
    back            TEXT NOT NULL,        -- 卡片背面（答案）
    card_type       TEXT NOT NULL DEFAULT 'basic',  -- basic | cloze | image
    tags            TEXT DEFAULT '',      -- 逗號分隔標籤
    interval        INTEGER DEFAULT 1,    -- SM-2 間隔天數
    ease_factor     REAL DEFAULT 2.5,     -- SM-2 簡易係數
    repetitions     INTEGER DEFAULT 0,    -- 重複次數
    next_review     DATE DEFAULT (date('now')),  -- 下次複習日期
    ai_explanation  TEXT,                 -- AI 說明內容
    suspended       BOOLEAN DEFAULT 0,    -- 是否暫停
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE study_sessions (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    started_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    ended_at        DATETIME,             -- 課程結束時間
    cards_reviewed  INTEGER DEFAULT 0,    -- 複習張數
    avg_rating      REAL,                 -- 平均評分
    deck_id         INTEGER REFERENCES decks(id)
);

CREATE TABLE card_reviews (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    card_id     INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
    session_id  INTEGER REFERENCES study_sessions(id),
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),  -- 評分 1–5
    reviewed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    time_spent  INTEGER  -- 秒數
);
```

---

## 架構 / UI 版面

```
┌─────────────────────────────────────────────────────────────┐
│  StudyBuddy                                    [_ □ ×]      │
├──────────────┬──────────────────────────────────────────────┤
│  牌組側邊欄  │  主要內容區                                  │
│              │                                              │
│  ▼ 我的牌組  │  [立即學習]  [匯入筆記]  [統計]             │
│    ▶ 物理    │  ─────────────────────────────────────────   │
│    ▶ 歷史    │                                              │
│    ▼ Python  │   今日到期：24 張   新卡：12 張              │
│      基礎    │                                              │
│      OOP     │   ┌──────────────────────────────────┐       │
│              │   │         卡片正面                 │       │
│  [+ 新增牌組]│   │                                  │       │
│              │   │  什麼是 list comprehension？     │       │
│  ─────────── │   │                                  │       │
│  標籤：      │   └──────────────────────────────────┘       │
│  #python     │        [空格 / 點擊 翻卡]                    │
│  #basics     │                                              │
│  #oop        │   ┌──────────────────────────────────┐       │
│              │   │         卡片背面（已翻轉）        │       │
│              │   │  [答案文字]                      │       │
│              │   │                                  │       │
│              │   │  [1 再來][2 困難][3 良好]        │       │
│              │   │  [4 簡單][5 完美]                │       │
│              │   └──────────────────────────────────┘       │
│              │   [為什麼我答錯了？]（評分 1–2 後出現）      │
└──────────────┴──────────────────────────────────────────────┘

學習模式（全螢幕）：
┌─────────────────────────────────────────────────────────────┐
│  [X 離開]                       進度：████░░░ 14/20         │
│                                                             │
│                                                             │
│          二分搜尋的時間複雜度是什麼？                        │
│                                                             │
│                    ─────────────────                        │
│                    [空格 顯示答案]                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 關鍵互動

### 互動 1：匯入筆記 → 生成閃卡
```
使用者選取 .md 檔案
  → 開啟 FileImportDialog
  → pdfplumber/markdown2 萃取純文字
  → 文字切分為 500 token 的片段
  → 每個片段送至 Claude：
      提示詞：「從這段文字生成閃卡問答。
               回傳 JSON 陣列：[{question, answer, type}]」
  → Claude 回傳 JSON
  → CardPreviewDialog 在可編輯表格中顯示生成的卡片
  → 使用者編輯 / 刪除列
  → 使用者點擊「儲存至牌組 [物理]」
  → 卡片寫入資料庫，next_review = 今天
```

### 互動 2：每日學習課程流程
```
使用者點擊牌組的「立即學習」
  → 資料庫查詢：SELECT cards WHERE next_review <= today AND suspended=0
  → SM-2 排程器排序：逾期最久者優先，再依 ease_factor ASC
  → 開啟 StudyWindow（全螢幕）
  → 顯示卡片正面
  → 使用者按空格 → 卡片翻轉（類 CSS 轉場動畫）
  → 使用者按 1–5
  → SM-2 計算新 interval + ease_factor
  → 更新資料庫：card.interval、card.ease_factor、card.next_review
  → 插入 card_reviews 列
  → 若評分 <= 2 → 顯示「說明我的錯誤」按鈕
  → 顯示下一張卡片
  → 最後一張卡片後 → 顯示 SessionSummaryDialog
```

### 互動 3：AI 說明請求
```
使用者點擊「為什麼我答錯了？」
  → 呼叫 Claude API：
      提示詞：「問題：{front}\n正確答案：{back}\n
               說明學生可能答錯的原因，
               並給出帶有真實案例的有用說明。」
  → Claude 回傳說明文字
  → ExplanationPanel 從卡片下方滑入
  → 說明儲存至 cards.ai_explanation
  → 本課程 API 呼叫計數遞增（最多 10 次）
```

---

## 實作步驟

1. **專案鷹架**：建立 PyQt6 應用程式骨架，設定 SQLAlchemy 搭配 SQLite，定義所有 ORM 模型，首次啟動時執行 `Base.metadata.create_all()`。

2. **牌組管理 UI**：以 QTreeWidget 建立階層牌組側邊欄，加入右鍵選單（新增/重新命名/刪除），以及顏色選取對話框。

3. **SM-2 演算法模組**：實作 `sm2.py` — 純函式 `calculate_next_review(card, rating)`，回傳更新後的 interval、ease_factor、repetitions、next_review 日期。

4. **檔案匯入管線**：FileImportDialog + .md、.pdf、.txt 文字萃取器，分段邏輯（500 token），Claude API 呼叫含速率限制重試。

5. **卡片 CRUD UI**：CardListWidget（QTableWidget）含行內編輯、批次選取，CardEditorDialog 供單張卡片詳細資訊 / 標籤編輯。

6. **學習課程 UI**：StudyWindow（全螢幕 QWidget），透過 QPropertyAnimation 對卡片 widget 幾何 / 透明度做翻卡動畫，評分按鈕 1–5。

7. **AI 說明整合**：在學習課程中按需呼叫 Claude API，ExplanationPanel QWidget 顯示文字，課程層級呼叫計數器。

8. **統計儀表板**：StatsWidget 內嵌 matplotlib FigureCanvas，保留率計算、連續日曆、匯出 CSV 動作。

---

## 成功標準

### 功能性
- 匯入 10 頁 PDF，在 30 秒內生成 20 張以上閃卡
- SM-2 排程正確推進間隔：5 分評分的卡片：第 1 天 → 第 3 天 → 第 8 天 → 第 21 天
- 學習課程完成 50 張卡片，無 UI 凍結或資料遺失
- 點擊按鈕後 5 秒內出現 AI 說明
- Anki .apkg 可在 Anki 桌面版成功匯出並匯入

### 使用者體驗
- 在內建顯卡上翻卡動畫流暢達 60 fps
- 全螢幕學習模式無任何干擾 UI 元素
- 純鍵盤工作流：空格翻卡 + 1–5 評分 + Enter 下一張
- 牌組側邊欄載入 1,000 張以上卡片無明顯延遲

### 技術品質
- 所有資料庫寫入包裹於交易中；程式崩潰時不會有部分儲存
- Claude API 呼叫使用 `httpx` 非同步，逾時 30 秒，重試 3 次
- SM-2 單元測試涵蓋所有評分值（1–5）及邊界案例（新卡、失效卡）
- SQLAlchemy 模型具備 `__repr__` 及必要欄位輸入驗證
- 無硬編碼 API Key；Key 從 `ANTHROPIC_API_KEY` 環境變數讀取
