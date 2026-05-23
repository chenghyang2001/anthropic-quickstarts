#!/usr/bin/env python3
"""解析 claude -p --output-format stream-json 的 JSONL 輸出，印出可讀的 tool 呼叫流。

用法：
  claude -p --output-format stream-json --verbose < prompt.md | python parse_claude_stream.py

輸出範例：
  [Tool: Read] {"file_path":"app_spec.txt"}
     [OK] # Application Spec ...
  [Tool: Write] {"file_path":"feature_list.json"}
     [OK] (no output)
    > 我已經建立 feature_list.json 含 5 個 features...
  === DONE (cost: $0.0234, turns: 12) ===
"""
import json
import sys
from typing import Any

# 預覽長度上限，避免長字串塞爆 terminal
INPUT_PREVIEW = 100
RESULT_PREVIEW = 80
TEXT_PREVIEW = 150


def truncate(text: str, max_len: int) -> str:
    """截斷字串並加省略符號；同時把換行壓成空白避免破壞單行排版。"""
    text = text.replace("\n", " ").strip()
    return text if len(text) <= max_len else text[:max_len] + "..."


def extract_tool_result_content(content: Any) -> str:
    """tool_result.content 可能是 str 或 list[block]；統一轉成單一字串。

    list 形式來自 Anthropic API 規格：每個 block 可能是 {"type":"text","text":...}
    或單純字串。為了相容，逐個解開後用空白串起來。
    """
    if isinstance(content, list):
        return " ".join(
            c.get("text", "") if isinstance(c, dict) else str(c)
            for c in content
        )
    return str(content)


def handle_assistant(msg: dict) -> None:
    """處理 assistant 訊息：印出 tool_use 與 text block。"""
    for block in msg.get("message", {}).get("content", []) or []:
        btype = block.get("type")
        if btype == "tool_use":
            name = block.get("name", "?")
            # ensure_ascii=False 讓中文輸入直接顯示，不被 escape 成 \uXXXX
            inp = truncate(
                json.dumps(block.get("input", {}), ensure_ascii=False),
                INPUT_PREVIEW,
            )
            print(f"[Tool: {name}] {inp}", flush=True)
        elif btype == "text":
            text = truncate(block.get("text", ""), TEXT_PREVIEW)
            if text:
                print(f"  > {text}", flush=True)


def handle_user(msg: dict) -> None:
    """處理 user 訊息：印出 tool_result（可能含錯誤）。"""
    for block in msg.get("message", {}).get("content", []) or []:
        if block.get("type") == "tool_result":
            preview = truncate(
                extract_tool_result_content(block.get("content", "")),
                RESULT_PREVIEW,
            )
            tag = "[ERR]" if block.get("is_error") else "[OK]"
            print(f"   {tag} {preview}", flush=True)


def handle_result(msg: dict) -> None:
    """處理 result 訊息：印出收尾總結（成本/輪數/subtype）。"""
    cost = msg.get("total_cost_usd", 0)
    turns = msg.get("num_turns", "?")
    sub = msg.get("subtype", "?")
    print(f"=== DONE [{sub}] (cost: ${cost}, turns: {turns}) ===", flush=True)


def main() -> None:
    """讀 stdin JSONL 逐行解析。單行 JSON 解析錯誤改原樣印，不中斷整個 stream。"""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except json.JSONDecodeError:
            # 非 JSON 行（例如 SDK 啟動時的 banner / system 訊息）原樣印
            print(line, flush=True)
            continue

        msg_type = msg.get("type")
        if msg_type == "assistant":
            handle_assistant(msg)
        elif msg_type == "user":
            handle_user(msg)
        elif msg_type == "result":
            handle_result(msg)
        # system / 其他類型忽略（system 含 init/session info，太雜不印）


if __name__ == "__main__":
    main()
