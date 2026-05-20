# Anthropic Quickstarts 演練計畫

> 建立日期：2026-05-21
> 目的：從最簡單到最困難，逐一演練所有 quickstart 專案

---

## 專案難度排序（由簡到難）

| 難度 | 專案名稱 | 難度說明 | 目的 | 主要架構與技術內容 |
|:---:|---|---|---|---|
| ⭐ 最簡單 | **agents** | 純 Python、無框架、~300 行核心碼 | 理解 LLM Agent 最底層運作原理：API 呼叫 → 工具執行 → 訊息歷史管理的完整循環 | Python + Anthropic SDK + MCP；包含 `agent.py`（主循環）、`tools/`（計算機/網路搜尋/檔案/程式執行）、`utils/`（歷史管理、MCP 連線）；附 Jupyter Notebook 示範 |
| ⭐⭐ 簡單 | **financial-data-analyst** | Next.js 全端，邏輯單純：上傳→分析→畫圖 | 用 Claude 分析財務資料並即時生成互動圖表（折線圖、柱狀圖、圓餅圖等） | Next.js 14 + React + TailwindCSS + Recharts；`api/finance/route.ts`（分析 API）、`ChartRenderer.tsx`（圖表）、`FilePreview.tsx`（預覽）；支援 CSV / PDF / 圖片上傳 |
| ⭐⭐⭐ 中等 | **customer-support-agent** | Next.js 全端，額外整合 AWS Bedrock 知識庫與多 UI 變體 | 建立企業級 AI 客服系統，含知識庫查詢（RAG）、情緒偵測、即時思考過程顯示 | Next.js 14 + Shadcn/ui + AWS Bedrock Agent Runtime；`api/chat/route.ts`（串接 Bedrock）、`ChatArea.tsx`、`LeftSidebar / RightSidebar`、`FullSourceModal.tsx`（RAG 來源顯示）；支援 4 種 UI 佈局變體 |
| ⭐⭐⭐⭐ 中難 | **autonomous-coding** | 純 Python CLI，但涉及雙 Agent 協作、多 Session 持久化、OS 沙箱安全模型 | 示範跨多個 Session 持續運作的自主編碼代理：先由初始化代理生成 200 個測試案例，再由編碼代理分批實作功能 | Python + claude-code-sdk；`agent.py`（Agent 邏輯）、`security.py`（OS 級沙箱 + 白名單）、`progress.py`（進度持久化）、`prompts/`（初始化 / 編碼提示詞）；雙 Agent 模式 + git 進度追蹤 |
| ⭐⭐⭐⭐ 中難 | **computer-use-demo** | 需建置 Docker + X11 + VNC 桌面環境，工具鏈較複雜 | 示範 Claude 直接操控虛擬桌面（滑鼠、鍵盤、截圖）的最小可執行容器 | Python + Streamlit + Docker + X11/VNC；`loop.py`（Agent 循環）、`tools/`（bash / computer / edit 三大工具）、`streamlit.py`（UI）；支援 Claude API / Bedrock / Vertex 三種後端 |
| ⭐⭐⭐⭐⭐ 困難 | **browser-use-demo** | Docker Compose + Playwright + DOM 操作腳本 + VNC，整合層次多 | 示範以 DOM 為基礎（非座標）的瀏覽器自動化：導航、表單填寫、內容擷取、智慧滾動、截圖 | Python + Playwright + Streamlit + Docker Compose + NoVNC；`loop.py`（瀏覽器自動化循環）、`browser_tool_utils/`（DOM 提取 / 元素操作 / 表單操作 JS 腳本）、`tools/browser.py`；含整合測試套件 |
| ⭐⭐⭐⭐⭐⭐ 最困難 | **computer-use-best-practices** | macOS 原生執行、整合最多工具鏈、要求在 VM 中運行，含軌跡記錄與沙箱設計 | 生產等級的電腦 + 瀏覽器操控參考實作，涵蓋最佳實踐：明確工具定義、圖片縮放優化、Prompt Caching、批次工具呼叫、沙箱 Shell、軌跡錄製 | Python + Playwright + FastAPI + Streamlit + PyAutoGUI + Pillow；`loop.py`（核心）、`image.py`（圖片尺寸優化）、`tools/`（computer / browser / shell / editor / batch）、`trajectory.py`（軌跡記錄）、`dev_ui/`（軌跡檢視器 + 工具面板）；需 Python 3.11+ |

---

## 建議演練順序

```
agents → financial-data-analyst → customer-support-agent
       → autonomous-coding → computer-use-demo
       → browser-use-demo → computer-use-best-practices
```

---

## 第一站：agents 演練詳細計畫

### 環境準備

```bash
# 安裝套件（已完成，2026-05-21）
python -m pip install anthropic mcp

# 設定 API Key（每次 session 臨時設定，不要用 setx）
# PowerShell:
$env:ANTHROPIC_API_KEY = "sk-ant-你的key..."
# Git Bash:
export ANTHROPIC_API_KEY="sk-ant-你的key..."
```

> ⚠️ 注意：agents 專案直接呼叫 Anthropic API，會用 API Credits（非 Max 訂閱）
> 建議用 `claude-haiku-4-5-20251001` 降低費用

---

### agents 架構圖解

```
你的問題
   │
   ▼
Agent._agent_loop()          ← 核心：while 迴圈
   │
   ├─ 1. 把問題加入 MessageHistory
   ├─ 2. 呼叫 Claude API（帶所有 tools 定義）
   ├─ 3. Claude 回傳 → 有 tool_use？
   │      ├─ YES → execute_tools()（可平行執行）
   │      │        結果加回 history → 繼續迴圈
   │      └─ NO  → 回傳最終答案，結束
   │
   └─ MessageHistory.truncate() ← 自動截斷超出 context window 的舊訊息
```

**5 種工具分兩類：**

| 類型 | 工具 | 說明 |
|---|---|---|
| 本地工具（Python 直接執行） | `ThinkTool` | Claude 的內部思考，不呼叫外部 |
| 本地工具 | `FileReadTool` / `FileWriteTool` | 讀寫本機檔案 |
| Anthropic Server 工具 | `WebSearchServerTool` | Anthropic 代管的網路搜尋 |
| Anthropic Server 工具 | `CodeExecutionServerTool` | Anthropic 代管的 Python 執行環境 |
| MCP 工具（外部 Process） | `calculator_mcp.py` | 透過 MCP 協定連接的計算機 |

---

### 🟢 第一關：最小 Agent（只用 ThinkTool，無外部依賴）

存成 `doc/practice_01_think.py`，在 `anthropic-quickstarts/` 根目錄執行：

```python
import sys
sys.path.insert(0, ".")

from agents.agent import Agent, ModelConfig
from agents.tools.think import ThinkTool

agent = Agent(
    name="第一關Agent",
    system="你是一個有幫助的助手，用繁體中文回答。",
    tools=[ThinkTool()],
    config=ModelConfig(model="claude-haiku-4-5-20251001"),  # 最便宜
    verbose=True   # 看到每一步 tool call 的過程
)

response = agent.run("請告訴我台灣最高的山是哪座，以及它的高度？")

for block in response.content:
    if block.type == "text":
        print("\n=== 最終回答 ===")
        print(block.text)
```

**執行指令：**
```bash
cd C:/Users/user/workspace/anthropic-quickstarts
PYTHONUTF8=1 python doc/practice_01_think.py
```

**預期輸出（verbose=True 的過程）：**
```
[第一關Agent] Agent initialized
[第一關Agent] Received: 請告訴我...
[第一關Agent] Tool call: think(thought=...)
[第一關Agent] Tool result: Thinking complete!
[第一關Agent] Output: 台灣最高的山是...

=== 最終回答 ===
台灣最高的山是玉山（Jade Mountain）...
```

---

### 🟡 第二關：加入 FileRead/FileWrite（本地 I/O）

存成 `doc/practice_02_files.py`：

```python
import sys
sys.path.insert(0, ".")

from agents.agent import Agent, ModelConfig
from agents.tools.think import ThinkTool
from agents.tools.file_tools import FileReadTool, FileWriteTool

agent = Agent(
    name="檔案Agent",
    system="你是一個能讀寫檔案的助手，用繁體中文回答。",
    tools=[ThinkTool(), FileReadTool(), FileWriteTool()],
    config=ModelConfig(model="claude-haiku-4-5-20251001"),
    verbose=True
)

response = agent.run(
    "請讀取 agents/README.md 的內容，"
    "然後把它的重點摘要（3點）寫入 agents/summary.txt"
)

for block in response.content:
    if block.type == "text":
        print("\n=== 最終回答 ===")
        print(block.text)
```

**執行指令：**
```bash
PYTHONUTF8=1 python doc/practice_02_files.py
```

**學到的概念：** Agent 自動決定先呼叫 `file_read`，讀完後再呼叫 `file_write`，全程不需要你指揮順序。

---

### 🔴 第三關：Anthropic Server 工具（網路搜尋 + 程式執行）

存成 `doc/practice_03_server_tools.py`：

```python
import sys
sys.path.insert(0, ".")

from agents.agent import Agent, ModelConfig
from agents.tools.think import ThinkTool
from agents.tools.web_search import WebSearchServerTool
from agents.tools.code_execution import CodeExecutionServerTool

agent = Agent(
    name="搜尋+運算Agent",
    system="你是一個能搜尋網路並執行程式的助手，用繁體中文回答。",
    tools=[
        ThinkTool(),
        WebSearchServerTool(max_uses=3),
        CodeExecutionServerTool(),
    ],
    config=ModelConfig(model="claude-sonnet-4-20250514"),  # 這關需要 Sonnet
    verbose=True
)

response = agent.run(
    "搜尋台灣今年的 GDP 數字，"
    "然後寫 Python 程式計算它占全球 GDP 的百分比（全球 GDP 約 105 兆美元）"
)

for block in response.content:
    if block.type == "text":
        print("\n=== 最終回答 ===")
        print(block.text)
```

**執行指令：**
```bash
PYTHONUTF8=1 python doc/practice_03_server_tools.py
```

**學到的概念：** `web_search` → `code_execution` → 最終計算結果，完整的「搜尋 + 計算」流水線。

---

### 關鍵程式碼理解清單

| 檔案 | 核心概念 | 重點行數 |
|---|---|---|
| `agent.py:96-155` | `_agent_loop()` while 迴圈 | Agent 的心臟 |
| `agent.py:104-105` | `history.truncate()` + `prepare_message_params()` | 每輪開始都截斷 + 準備參數 |
| `agent.py:117-119` | `client.messages.create()` | 實際呼叫 Claude API |
| `agent.py:121-123` | 過濾 `tool_use` blocks | 判斷是否要繼續循環 |
| `agent.py:142-153` | `execute_tools()` | 平行執行所有工具 |
| `utils/history_util.py:69-108` | `truncate()` | 智慧截斷舊訊息保留 context window |
| `utils/history_util.py:113-124` | `format_for_api()` | 加上 `cache_control` 做 prompt caching |
| `utils/tool_util.py:27-36` | `asyncio.gather()` | 平行執行多個工具 |
| `tools/base.py` | `Tool` 抽象基類 | 所有工具的合約 |

---

## 下一站預告：financial-data-analyst

**前置條件：**
- Node.js 18+
- `npm install`
- 設定 `ANTHROPIC_API_KEY`（可放 `.env.local`）

**核心差異：** 這是 Web App，API 在 Next.js Route Handler，前端用 Recharts 畫圖，重點是看 `app/api/finance/route.ts` 如何用 streaming 即時回傳圖表資料。
