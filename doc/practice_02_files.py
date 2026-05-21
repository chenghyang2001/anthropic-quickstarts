"""第二關演練：替 Agent 加上檔案讀寫能力。

學習重點：
- 在第一關的基礎上加入 FileReadTool 與 FileWriteTool，讓 Agent 能操作本機檔案。
- 觀察 Agent 如何自主決定「先讀檔、再思考、最後寫檔」的多步驟工具呼叫流程。
- 理解檔案工具的相對路徑是相對於程序的工作目錄，因此需先 chdir 到 repo 根目錄。

執行方式（PowerShell）：
    $env:ANTHROPIC_API_KEY = "sk-ant-..."
    python doc/practice_02_files.py
"""

import os
import sys
from pathlib import Path

# 腳本位於 repo 的 doc/ 底下，parent.parent 即 repo 根目錄。
# 自我定位而非硬編碼路徑，使用者從任何工作目錄執行都能跑。
REPO_ROOT = Path(__file__).resolve().parent.parent
# 讓 import agents 找得到套件（套件不在 site-packages，需手動加入搜尋路徑）。
sys.path.insert(0, str(REPO_ROOT))
# 切到 repo 根目錄，檔案工具的相對路徑（agents/README.md、agents/summary.txt）才能正確解析。
os.chdir(REPO_ROOT)

from agents.agent import Agent, ModelConfig  # noqa: E402
from agents.tools.file_tools import FileReadTool, FileWriteTool  # noqa: E402
from agents.tools.think import ThinkTool  # noqa: E402


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
        name="檔案Agent",
        system="你是一個能讀寫檔案的助手，用繁體中文回答。",
        tools=[ThinkTool(), FileReadTool(), FileWriteTool()],
        # 檔案讀寫摘要任務不需強推理，沿用 Haiku 控制成本。
        config=ModelConfig(model="claude-haiku-4-5-20251001"),
        verbose=True,
    )

    user_input = (
        "請讀取 agents/README.md 的內容，然後把它的重點摘要（3點）"
        "寫入 agents/summary.txt"
    )

    try:
        response = agent.run(user_input)
    except Exception as e:
        # 不裸 except 後靜默吞掉：印出具體錯誤供使用者排查（檔案不存在、權限、認證等）。
        print(f"錯誤：Agent 執行失敗 - {e}", file=sys.stderr)
        sys.exit(1)

    print("\n=== 最終回答 ===")
    print_text_blocks(response)


if __name__ == "__main__":
    main()
