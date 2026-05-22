# Anthropic Quickstarts — `agents` 專案導讀

> 本文件目的：讓任何人在 10 分鐘內快速理解 `agents` 這個專案在做什麼、怎麼運作、每個檔案的角色。
> 適用對象：第一次接觸這個專案、想學「如何用 Claude API 建立 AI Agent」的開發者。

---

## 一、這個專案是什麼

`agents` 是 **Anthropic 官方提供的「如何用 Claude API 建立 AI Agent」教學範例**。

它有三個關鍵定位：

1. **這不是 SDK** —— README 開宗明義寫 `This is NOT an SDK, but a reference implementation of key concepts`。它是「概念參考實作」，不是給你拿去生產環境直接用的函式庫。
2. **刻意極簡** —— 核心邏輯不到 300 行程式碼，故意不含生產級功能（重試、監控、限流等）。目的是讓你看懂「Agent 的本質」，而不是被複雜度淹沒。
3. **可移植** —— 鼓勵你把這些模式翻譯成自己的語言和技術棧。

它要證明的核心觀點是：**複雜的 AI 行為，可以從一個極簡的基礎長出來 —— 那個基礎就是「讓 LLM 在一個迴圈裡使用工具」（LLMs using tools in a loop）。**

---

## 二、核心理念：Agent = LLM + 工具 + 迴圈

一般的「單次問答」是：使用者問一句 → LLM 答一句 → 結束。

**Agent 的差別在於那個「迴圈」**：

```
使用者輸入
   │
   ▼
┌─────────────────────────────────────────┐
│  while True 迴圈                          │
│                                           │
│  1. 截斷過長的對話歷史                     │
│  2. 呼叫 Claude API（附上所有工具定義）    │
│  3. Claude 的回應裡有沒有「工具呼叫」？    │
│      ├─ 有 → 執行工具 → 把結果塞回歷史 →  │
│      │        回到步驟 1（再問 Claude）   │
│      └─ 沒有 → 這就是最終答案，跳出迴圈   │
└─────────────────────────────────────────┘
   │
   ▼
回傳最終答案
```

判斷迴圈是否結束的唯一準則：**Claude 這一輪有沒有要求呼叫工具**。有就繼續，沒有就結束。這短短一個判斷，就是 Agent 與聊天機器人的根本差別。

---

## 三、程式進入點（Entry Point）

使用這個專案只需要兩步：

**步驟 1 — 建立 Agent 物件**

```python
from agents.agent import Agent
from agents.tools.think import ThinkTool

agent = Agent(
    name="MyAgent",                       # Agent 名稱（用於日誌）
    system="You are a helpful assistant.", # 系統提示
    tools=[ThinkTool()],                   # 本地工具清單
    mcp_servers=[                          # （選用）MCP 外部工具伺服器
        {"type": "stdio", "command": "python", "args": ["-m", "mcp_server"]},
    ],
)
```

**步驟 2 — 執行**

```python
response = agent.run("買新筆電要考慮什麼？")
```

`agent.run()` 是**對外的唯一進入點**。它內部會：
- 啟動非同步事件迴圈（`asyncio.run`）
- 建立 MCP 連線（如果有設定 `mcp_servers`）
- 進入核心迴圈 `_agent_loop()` 處理對話與工具呼叫
- 回傳 Anthropic 的 `Message` 物件（需自行遍歷 `response.content` 取出文字）

程式的真正心臟是 `agent.py` 裡的 `Agent._agent_loop()` 方法。

---

## 四、檔案結構與每個檔案的功能

專案分成三大部分：**大腦（agent.py）/ 手腳（tools/）/ 記憶與連線（utils/）**。

```
agents/
├── __init__.py            套件入口，對外匯出 Agent / ModelConfig / Tool
├── agent.py               【核心】Agent 類別、ModelConfig、主迴圈
├── README.md              專案說明
├── agent_demo.ipynb       Jupyter 示範筆記本
├── test_message_params.py 測試：驗證 message_params 自訂參數行為
│
├── tools/                 工具實作
│   ├── __init__.py        匯出所有內建工具
│   ├── base.py            Tool 基底類別（所有工具的共同介面）
│   ├── think.py           ThinkTool — 讓模型「思考」的工具
│   ├── file_tools.py      FileReadTool / FileWriteTool — 本機檔案讀寫
│   ├── web_search.py      WebSearchServerTool — 網路搜尋（Server 工具）
│   ├── code_execution.py  CodeExecutionServerTool — 程式碼執行（Server 工具）
│   ├── mcp_tool.py         MCPTool — 把 MCP 伺服器的工具包成 Tool
│   └── calculator_mcp.py  範例 MCP 伺服器（計算機）
│
└── utils/                 公用工具
    ├── __init__.py        匯出 MessageHistory / execute_tools
    ├── history_util.py    MessageHistory — 對話歷史、token 計數、快取、截斷
    ├── tool_util.py       execute_tools — 平行執行工具
    └── connections.py     MCP 伺服器連線管理（stdio / SSE）
```

### 逐檔功能說明

| 檔案 | 角色 | 做什麼 |
|------|------|--------|
| `agent.py` | 大腦 | 定義 `Agent` 類別與 `ModelConfig`。`_agent_loop()` 是核心 while 迴圈：呼叫 API → 判斷工具呼叫 → 執行工具 → 回填歷史。`run()` / `run_async()` 是對外進入點。 |
| `tools/base.py` | 工具契約 | 定義 `Tool` 基底類別。每個工具必須有 `name`、`description`、`input_schema` 三個欄位，並實作 `execute()`。`to_dict()` 把工具轉成 Claude API 認得的格式。 |
| `tools/think.py` | 本地工具 | `ThinkTool`。讓模型把「思考內容」寫進日誌，不取得新資訊也不改動任何狀態。`execute()` 只回傳固定字串 `"Thinking complete!"` —— 它的價值在於「給模型一個結構化思考的空間」。 |
| `tools/file_tools.py` | 本地工具 | `FileReadTool`（讀檔 / 列目錄）與 `FileWriteTool`（寫檔 / 編輯）。讀寫都用 `asyncio.to_thread` 包成非同步、一律 UTF-8 編碼、編輯時會警告多處匹配。 |
| `tools/web_search.py` | Server 工具 | `WebSearchServerTool`。不在本機執行 —— 它只產生一段工具定義（`type: web_search_20250305`），實際搜尋由 **Anthropic 伺服器端**完成。可設 `max_uses` 限制次數。 |
| `tools/code_execution.py` | Server 工具 | `CodeExecutionServerTool`。同樣是 Server 工具（`type: code_execution_20250522`），程式碼在 Anthropic 沙箱執行。 |
| `tools/mcp_tool.py` | MCP 橋接 | `MCPTool`。把「外部 MCP 伺服器提供的工具」包裝成本專案的 `Tool` 介面。`execute()` 透過 MCP 連線呼叫遠端工具，取回文字結果。 |
| `tools/calculator_mcp.py` | 範例 MCP 伺服器 | 一個獨立的 MCP 伺服器範例，用 `FastMCP` 提供 `calculator` 工具（加減乘除、次方、開根號）。它是「另一個程序」，示範 Agent 如何連外部工具伺服器。 |
| `utils/history_util.py` | 記憶 | `MessageHistory`。管理對話歷史、累計 token、自動截斷超長歷史、為最後一則訊息加上 prompt caching 標記。 |
| `utils/tool_util.py` | 執行器 | `execute_tools()`。Claude 一次回多個工具呼叫時，用 `asyncio.gather` **平行執行**；單一工具出錯不會拖垮其他工具，錯誤會被包成 `is_error` 結果回傳。 |
| `utils/connections.py` | 連線 | MCP 伺服器連線管理。支援兩種連線：`stdio`（啟動子程序）與 `SSE`（HTTP 事件流）。`setup_mcp_connections()` 連上伺服器、列出工具、包成 `MCPTool`。 |
| `__init__.py` | 套件入口 | 對外匯出 `Agent`、`ModelConfig`、`Tool` 三個核心名稱。 |
| `test_message_params.py` | 測試 | 驗證 `message_params` 能正確覆蓋 config 的預設值、beta header 合併邏輯正確。 |
| `agent_demo.ipynb` | 示範 | Jupyter 筆記本形式的互動示範。 |

---

## 五、核心迴圈詳解（`agent.py` 的 `_agent_loop`）

這是整個專案最重要的一段。流程如下：

1. **加入使用者訊息** —— 把使用者輸入存進 `MessageHistory`。
2. **進入 `while True` 迴圈**：
   - `history.truncate()` —— 若對話歷史超過 context window（預設 18 萬 token），從最舊訊息成對刪除。
   - `_prepare_message_params()` —— 組好 API 呼叫參數（model、訊息、工具定義等）。
   - 合併 beta header —— 一律帶上 `anthropic-beta: code-execution-2025-05-22`。
   - `client.messages.create()` —— 呼叫 Claude API。
   - 從回應中挑出所有 `type == "tool_use"` 的區塊。
   - 把 assistant 回應存進歷史。
   - **分岔判斷**：
     - 有工具呼叫 → `execute_tools()` 平行執行 → 結果以 user 角色塞回歷史 → 回到迴圈開頭。
     - 沒有工具呼叫 → `return response`，迴圈結束。

`run_async()` 在迴圈外面用 `AsyncExitStack` 包住 MCP 連線的生命週期：跑完（無論成功或失敗）都會自動清理連線、還原原本的工具清單，不留殘留程序。

---

## 六、工具系統 —— 三種類型

所有工具都遵守 `Tool` 基底類別的契約（`name` / `description` / `input_schema` / `execute()`），但**執行的位置**不同：

| 類型 | 代表工具 | 執行位置 | 特性 |
|------|---------|---------|------|
| **本地工具** | `ThinkTool`、`FileReadTool`、`FileWriteTool` | 本機 Python 程序內 | `execute()` 直接在你的機器上跑 |
| **Server 工具** | `WebSearchServerTool`、`CodeExecutionServerTool` | Anthropic 伺服器端 | 本地不執行，只送出工具定義；搜尋 / 執行由 Anthropic 完成 |
| **MCP 工具** | `calculator_mcp.py` 提供的 `calculator` | 外部獨立程序 | 透過 MCP 協定（stdio / SSE）呼叫另一個程序 |

這個分類是專案的精華之一：**同一個 Agent 迴圈，可以無縫混用三種來源的工具**，因為它們都被統一成 `Tool` 介面。

---

## 七、三個值得學習的設計亮點

**1. 工具平行執行**（`utils/tool_util.py`）
Claude 一次回多個工具呼叫時，用 `asyncio.gather()` 同時跑，不是排隊一個一個跑。單一工具失敗會被 `try/except` 包成錯誤結果，不影響其他工具。

**2. 對話歷史自動截斷**（`utils/history_util.py` 的 `truncate()`）
對話太長超過 context window 時，從最舊的訊息「成對刪除」（user + assistant 一組），並在開頭插入「[Earlier history has been truncated.]」提示。讓 Agent 可以長時間對話而不會撐爆 context。

**3. Prompt Caching**（`history_util.py` 的 `format_for_api()`）
每次送出 API 前，為最後一則訊息加上 `cache_control: {"type": "ephemeral"}` 標記。讓 Claude 快取前面不變的內容，**省 token、省錢、加速回應**。

---

## 八、環境需求

- Python 3.8 以上
- Claude API 金鑰（設為環境變數 `ANTHROPIC_API_KEY`）
- `anthropic` Python 函式庫
- `mcp` Python 函式庫

> 實務踩坑提醒：若使用 Python 3.14，`anthropic` SDK 必須是夠新的版本（0.40.0 等舊版會在解析含 code execution 工具的回應時崩潰，因 Python 3.14 禁止在 `typing.Union` 物件上設定屬性）。

---

## 九、一句話總結

`agents` 用不到 300 行程式碼證明了一件事：**一個能力強大的 AI Agent，本質上就是「讓 LLM 在一個 while 迴圈裡反覆使用工具，直到它不再需要工具為止」**。理解了 `_agent_loop()`，就理解了所有 Agent 框架的共同骨架。
