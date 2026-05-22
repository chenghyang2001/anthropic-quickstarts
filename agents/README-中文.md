# Agents（代理）

使用 Claude API 實作的極簡教學版 LLM 代理（agent）。

> **注意：** 這並不是一套 SDK，而是核心概念的參考實作（reference implementation）。

## 概觀與核心元件

本儲存庫示範如何使用 Claude API [打造高效能的代理](https://www.anthropic.com/engineering/building-effective-agents)。它展示了複雜的 AI 行為如何從一個簡單的基礎中浮現：讓 LLM 在迴圈中使用工具。本實作不具規範性（not prescriptive）—— 核心邏輯不到 300 行程式碼，並且刻意省略了生產環境所需的功能。歡迎將這些模式轉譯成你自己的語言與生產技術堆疊（[Claude Code](https://docs.claude.com/en/docs/agents-and-tools/claude-code/overview) 可以幫上忙！）。

它包含三個元件：

- `agent.py`：管理 Claude API 的互動與工具執行
- `tools/`：工具實作（同時包含原生工具與 MCP 工具）
- `utils/`：訊息歷史與 MCP 伺服器連線的工具函式

## 使用方式

```python
from agents.agent import Agent
from agents.tools.think import ThinkTool

# 建立一個同時具備本地工具與 MCP 伺服器工具的代理
agent = Agent(
    name="MyAgent",
    system="You are a helpful assistant.",
    tools=[ThinkTool()],  # 本地工具
    mcp_servers=[
        {
            "type": "stdio",
            "command": "python",
            "args": ["-m", "mcp_server"],
        },
    ]
)

# 執行代理
response = agent.run("What should I consider when buying a new laptop?")
```

從這個基礎出發，你可以加入特定領域的工具、優化效能，或實作自訂的回應處理。我們刻意保持不帶立場（unopinionated）—— 這個骨架只是讓你掌握基本原理、踏出第一步。

## 系統需求

- Python 3.8 以上
- Claude API 金鑰（設定為 `ANTHROPIC_API_KEY` 環境變數）
- `anthropic` Python 函式庫
- `mcp` Python 函式庫
