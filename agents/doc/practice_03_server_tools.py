"""第三關演練：使用 Anthropic Server 端工具（網路搜尋 + 程式執行）。

學習重點：
- 認識 Server 工具：WebSearchServerTool 與 CodeExecutionServerTool 由 Anthropic
  伺服器端執行，不像 FileReadTool 那樣在本機跑。
- 觀察 Agent 串接「搜尋取得資料 → 寫程式運算 → 整理答案」的完整推理鏈。
- 理解此關需要較強的 Sonnet 模型來協調多種工具。

執行方式（PowerShell）：
    $env:ANTHROPIC_API_KEY = "sk-ant-..."
    python agents/doc/practice_03_server_tools.py
"""

import os
import sys
from pathlib import Path

# 腳本位於 agents/doc/ 底下，往上三層 parent 即 repo 根目錄。
# 自我定位而非硬編碼路徑，使用者從任何工作目錄執行都能跑。
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
# 讓 import agents 找得到套件（套件不在 site-packages，需手動加入搜尋路徑）。
sys.path.insert(0, str(REPO_ROOT))
# 切到 repo 根目錄，與其他關卡保持一致的工作目錄行為。
os.chdir(REPO_ROOT)

from agents.agent import Agent, ModelConfig  # noqa: E402
from agents.tools.code_execution import CodeExecutionServerTool  # noqa: E402
from agents.tools.think import ThinkTool  # noqa: E402
from agents.tools.web_search import WebSearchServerTool  # noqa: E402


def print_text_blocks(response):
    """印出 Message 物件中的所有文字內容。

    response.content 是 content block 的 list，可能混雜 tool_use 等非文字 block，
    因此需逐一過濾 type == "text" 的 block。
    """
    found_text = False
    for block in response.content:
        if block.type == "text":
            print(block.text)
            found_text = True
    if not found_text:
        # Agent 可能整輪都在呼叫工具而沒有產出文字，給使用者明確提示而非空白。
        print("（本次回應沒有文字內容）")


def main():
    # 缺少 API key 時 Anthropic client 會在呼叫階段才報錯，提前攔截給出可行動的指引。
    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("錯誤：未設定環境變數 ANTHROPIC_API_KEY", file=sys.stderr)
        print(
            "請先設定（PowerShell）：$env:ANTHROPIC_API_KEY = \"sk-ant-...\"",
            file=sys.stderr,
        )
        sys.exit(1)

    agent = Agent(
        name="搜尋+運算Agent",
        system="你是一個能搜尋網路並執行程式的助手，用繁體中文回答。",
        # 兩題演練、每題約 3 次搜尋，故設 6：避免額度共用不足又不致呼叫過多失控。
        tools=[
            ThinkTool(),
            WebSearchServerTool(max_uses=6),
            CodeExecutionServerTool(),
        ],
        # 用現行 Sonnet（claude-sonnet-4-6）：演練計畫原訂的 claude-sonnet-4-20250514
        # 是舊版可能已停用，4-6 才是現行版本，且這關協調多工具需要 Sonnet 級推理。
        config=ModelConfig(model="claude-sonnet-4-6"),
        verbose=True,
    )

    # 用 list 集中管理題目，之後要增減題目只動這裡，迴圈邏輯不必改。
    questions = [
        (
            "搜尋台灣今年的 GDP 數字，然後寫 Python 程式計算它占全球 GDP 的"
            "百分比（全球 GDP 約 105 兆美元）"
        ),
        (
            "搜尋美國上個月票房營收最高的前五部好萊塢電影，然後寫 Python 程式"
            "計算這五部電影的總票房營收，占今年（2026 年）至今全美所有上映電影"
            "總票房的百分比"
        ),
    ]

    # 兩題共用同一個 agent 實例：省去重複建立的開銷，也讓搜尋額度集中在同一工具上。
    for index, user_input in enumerate(questions, start=1):
        try:
            response = agent.run(user_input)
        except Exception as e:
            # 不裸 except 後靜默吞掉：印出具體錯誤供使用者排查（搜尋失敗、認證、API 限額等）。
            print(f"錯誤：第 {index} 題 Agent 執行失敗 - {e}", file=sys.stderr)
            sys.exit(1)

        # 標題帶上題號，多題輸出時使用者才能對應到是哪一題的答案。
        print(f"\n=== 第 {index} 題最終回答 ===")
        print_text_blocks(response)


if __name__ == "__main__":
    main()
