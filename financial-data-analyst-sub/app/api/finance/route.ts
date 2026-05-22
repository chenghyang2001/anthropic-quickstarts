// app/api/finance/route.ts — Subscription edition
// 走 @anthropic-ai/claude-agent-sdk → claude CLI OAuth → Pro/Max 訂閱額度
// 不扣 API Credits，但只能本機跑（雲端沒 claude CLI + OAuth 憑證）

import { NextRequest } from "next/server";
import { query, tool, createSdkMcpServer } from "@anthropic-ai/claude-agent-sdk";
import { z } from "zod";
import type { ChartData } from "@/types/chart";

// 注意：不寫 export const runtime = "edge"
// SDK 透過 child_process spawn claude CLI 子行程，Edge runtime 沒有 Node.js child_process，
// 必須走預設 Node.js runtime。

// chart 工具回傳結構（與原版 ChartData 對齊）
interface ChartToolResponse extends ChartData {}

// pie chart 處理 + 注入 hsl color 變數，邏輯與原版 route.ts 第 353-402 行等價
function processToolResponse(
  capturedChartData: ChartToolResponse | null,
): ChartToolResponse | null {
  if (!capturedChartData) return null;

  const chartData = capturedChartData;

  if (
    !chartData.chartType ||
    !chartData.data ||
    !Array.isArray(chartData.data)
  ) {
    throw new Error("Invalid chart data structure");
  }

  // pie chart 需要重組成 { segment, value } 才能餵給前端 ChartRenderer
  if (chartData.chartType === "pie") {
    chartData.data = chartData.data.map((item: Record<string, unknown>) => {
      const valueKey = Object.keys(chartData.chartConfig)[0];
      const segmentKey = chartData.config.xAxisKey || "segment";
      return {
        segment:
          (item[segmentKey] as string) ||
          (item.segment as string) ||
          (item.category as string) ||
          (item.name as string),
        value: (item[valueKey] as number) || (item.value as number),
      };
    });

    // pie 永遠用 segment 當 xAxisKey，前端才認得
    chartData.config.xAxisKey = "segment";
  }

  // 為每個 chartConfig key 依序注入 hsl color 變數，前端從 CSS variable 取色
  const processedChartConfig = Object.entries(chartData.chartConfig).reduce(
    (acc, [key, config], index) => ({
      ...acc,
      [key]: {
        ...config,
        color: `hsl(var(--chart-${index + 1}))`,
      },
    }),
    {},
  );

  return {
    ...chartData,
    chartConfig: processedChartConfig,
  };
}

// system prompt：直接從原版 route.ts 第 222-329 行複製過來，
// 唯一改動：把工具名稱 generate_graph_data 改成 mcp__chart__generate_graph_data
// （SDK 的 MCP 工具名稱是 server name + tool name 組合）
const SYSTEM_PROMPT = `You are a financial data visualization expert. Your role is to analyze financial data and create clear, meaningful visualizations using mcp__chart__generate_graph_data tool:

Here are the chart types available and their ideal use cases:

1. LINE CHARTS ("line")
   - Time series data showing trends
   - Financial metrics over time
   - Market performance tracking

2. BAR CHARTS ("bar")
   - Single metric comparisons
   - Period-over-period analysis
   - Category performance

3. MULTI-BAR CHARTS ("multiBar")
   - Multiple metrics comparison
   - Side-by-side performance analysis
   - Cross-category insights

4. AREA CHARTS ("area")
   - Volume or quantity over time
   - Cumulative trends
   - Market size evolution

5. STACKED AREA CHARTS ("stackedArea")
   - Component breakdowns over time
   - Portfolio composition changes
   - Market share evolution

6. PIE CHARTS ("pie")
   - Distribution analysis
   - Market share breakdown
   - Portfolio allocation

When generating visualizations:
1. Structure data correctly based on the chart type
2. Use descriptive titles and clear descriptions
3. Include trend information when relevant (percentage and direction)
4. Add contextual footer notes
5. Use proper data keys that reflect the actual metrics

Data Structure Examples:

For Time-Series (Line/Bar/Area):
{
  data: [
    { period: "Q1 2024", revenue: 1250000 },
    { period: "Q2 2024", revenue: 1450000 }
  ],
  config: {
    xAxisKey: "period",
    title: "Quarterly Revenue",
    description: "Revenue growth over time"
  },
  chartConfig: {
    revenue: { label: "Revenue ($)" }
  }
}

For Comparisons (MultiBar):
{
  data: [
    { category: "Product A", sales: 450000, costs: 280000 },
    { category: "Product B", sales: 650000, costs: 420000 }
  ],
  config: {
    xAxisKey: "category",
    title: "Product Performance",
    description: "Sales vs Costs by Product"
  },
  chartConfig: {
    sales: { label: "Sales ($)" },
    costs: { label: "Costs ($)" }
  }
}

For Distributions (Pie):
{
  data: [
    { segment: "Equities", value: 5500000 },
    { segment: "Bonds", value: 3200000 }
  ],
  config: {
    xAxisKey: "segment",
    title: "Portfolio Allocation",
    description: "Current investment distribution",
    totalLabel: "Total Assets"
  },
  chartConfig: {
    equities: { label: "Equities" },
    bonds: { label: "Bonds" }
  }
}

Always:
- Generate real, contextually appropriate data
- Use proper financial formatting
- Include relevant trends and insights
- Structure data exactly as needed for the chosen chart type
- Choose the most appropriate visualization for the data

Never:
- Use placeholder or static data
- Announce the tool usage
- Include technical implementation details in responses
- NEVER SAY you are using the mcp__chart__generate_graph_data tool, just execute it when needed.

Focus on clear financial insights and let the visualization enhance understanding.`;

// 允許的模型白名單：避免 client 端塞任意 model 字串繞過扣費控管
const ALLOWED_MODELS = [
  "claude-haiku-4-5-20251001",
  "claude-sonnet-4-6",
] as const;

// zod schema：把 req.json() 出來的 raw body 收斂到型別安全的領域物件
// role 只允許 user/assistant（封掉 client 塞 system 改 prompt 的攻擊面）
const RequestSchema = z.object({
  messages: z
    .array(
      z.object({
        role: z.enum(["user", "assistant"]),
        content: z.union([z.string(), z.array(z.any())]),
      }),
    )
    .min(1),
  model: z.enum(ALLOWED_MODELS),
  fileData: z
    .object({
      base64: z.string(),
      fileName: z.string(),
      mediaType: z.string(),
      isText: z.boolean().optional(),
    })
    .optional()
    .nullable(),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = RequestSchema.safeParse(body);
    if (!parsed.success) {
      return new Response(
        JSON.stringify({
          error: "Invalid request",
          details: parsed.error.flatten(),
        }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }
    const { messages, model, fileData } = parsed.data;

    console.log("🔍 Initial Request Data:", {
      hasMessages: true,
      messageCount: messages.length,
      hasFileData: !!fileData,
      fileType: fileData?.mediaType,
      model,
    });

    // ─── 組 prompt 字串（純文字 only，圖片跳過） ─────────────────
    // SDK 的 query() 只接受字串 prompt，所以要把 messages 攤平
    const promptParts: string[] = [];
    for (const msg of messages) {
      const content =
        typeof msg.content === "string" ? msg.content : "[non-text content]";
      promptParts.push(
        `${msg.role === "user" ? "User" : "Assistant"}: ${content}`,
      );
    }

    let prompt = promptParts.join("\n\n");

    // 文字檔內嵌；圖片跳過並警告（POC 範圍）
    if (fileData) {
      const { base64, mediaType, isText, fileName } = fileData;

      if (!base64) {
        console.error("❌ No base64 data received");
        return new Response(JSON.stringify({ error: "No file data" }), {
          status: 400,
          headers: { "Content-Type": "application/json" },
        });
      }

      if (isText) {
        try {
          // base64 → utf-8 文字（與原版 escape/atob 等價，用 Buffer 比較乾淨）
          const textContent = Buffer.from(base64, "base64").toString("utf-8");
          // 插到最後一條 user 訊息前，與原版內嵌方式對齊
          const lastUserContent =
            typeof messages[messages.length - 1].content === "string"
              ? messages[messages.length - 1].content
              : "";
          // 重組 prompt：把最後一段 User: ... 換成「檔案內容 + 原訊息」
          promptParts.pop();
          promptParts.push(
            `File contents of ${fileName}:\n\n${textContent}\n\nUser: ${lastUserContent}`,
          );
          prompt = promptParts.join("\n\n");
        } catch (decodeErr) {
          console.error("❌ base64 decode failed:", decodeErr);
          return new Response(
            JSON.stringify({ error: "Failed to process file content" }),
            { status: 400, headers: { "Content-Type": "application/json" } },
          );
        }
      } else if (mediaType && mediaType.startsWith("image/")) {
        // POC 範圍不支援圖片：claude-agent-sdk 的 query() prompt 是字串，無法塞 vision input
        console.warn(
          "⚠️ Image input skipped (POC text-only). fileName=",
          fileName,
        );
      }
    }

    // ─── 在 handler 內建立 chart 工具 + MCP server ──────────────
    // 重要：必須在 POST handler 內部建立，不能放模組頂層。
    // 因為 chart 工具用 closure 變數 capturedChartData 擷取資料，
    // 模組頂層共享變數會在多個 concurrent request 之間 race condition。
    let capturedChartData: ChartToolResponse | null = null;

    const chartTool = tool(
      "generate_graph_data",
      "Generate structured JSON data for creating financial charts and graphs.",
      {
        chartType: z.enum([
          "bar",
          "multiBar",
          "line",
          "pie",
          "area",
          "stackedArea",
        ]),
        config: z.object({
          title: z.string(),
          description: z.string(),
          trend: z
            .object({
              percentage: z.number(),
              direction: z.enum(["up", "down"]),
            })
            .optional(),
          footer: z.string().optional(),
          totalLabel: z.string().optional(),
          xAxisKey: z.string().optional(),
        }),
        // zod v4 record 需要兩個泛型參數（key schema, value schema）
        data: z.array(z.record(z.string(), z.any())),
        chartConfig: z.record(
          z.string(),
          z.object({
            label: z.string(),
            stacked: z.boolean().optional(),
          }),
        ),
      },
      async (args) => {
        // 把 Claude 產生的 chart 資料寫進 closure 變數，後面組回傳用
        // SDK tool handler 必須回 { content: [...] } 格式
        capturedChartData = args as unknown as ChartToolResponse;
        console.log("✅ chart tool invoked:", {
          chartType: capturedChartData.chartType,
          dataLen: capturedChartData.data?.length,
        });
        return {
          content: [{ type: "text", text: "Chart data captured." }],
        };
      },
    );

    const chartServer = createSdkMcpServer({
      name: "chart",
      version: "1.0.0",
      tools: [chartTool],
    });

    console.log("🚀 Final Claude SDK Request:", {
      model,
      promptLen: prompt.length,
      systemPromptLen: SYSTEM_PROMPT.length,
      tools: ["mcp__chart__generate_graph_data"],
    });

    // ─── 呼叫 query() 跑 agent loop ─────────────────────────────
    let accumulatedText = "";

    for await (const message of query({
      prompt,
      options: {
        model,
        // 用字串 systemPrompt 覆寫 Claude Code 預設那包 70k tokens system prompt，
        // 只保留 financial visualization expert 的指示
        systemPrompt: SYSTEM_PROMPT,
        mcpServers: { chart: chartServer },
        // 只允許 chart 工具，禁掉所有 built-in tools（Read/Write/Bash/Glob...）
        allowedTools: ["mcp__chart__generate_graph_data"],
        tools: [],
        // 不需要多輪 tool use，分析資料 → 畫圖 → 結束 3 turn 內
        maxTurns: 3,
        permissionMode: "default",
        // request-scoped 清掉 API key，強制 SDK spawn 的 claude CLI 走 OAuth；
        // 不污染 parent process.env（避免 concurrent request 互相影響）
        env: { ...process.env, ANTHROPIC_API_KEY: undefined } as any,
      },
    })) {
      if (message.type === "assistant") {
        // assistant 訊息的 content 是 block 陣列：text / tool_use / ...
        // SDK 不同版本欄位略有差異，這裡用 cast 走寬容路徑（局部最小化 cast）
        const blocks = (message as any).message?.content ?? [];
        for (const block of blocks) {
          if (block.type === "text" && typeof block.text === "string") {
            accumulatedText += block.text;
          }
        }
      } else if (message.type === "result") {
        // result 訊息代表本次 agent loop 已結束
        console.log("✅ Claude SDK result:", {
          subtype: message.subtype,
          numTurns: (message as any).num_turns,
        });
        // 不管 success / error_max_turns / error_during_execution 都跳出，
        // 下面照樣根據 capturedChartData 組回傳
        break;
      }
      // user / system / 其他訊息類型在此 POC 忽略
    }

    console.log("✅ Final response stats:", {
      textLen: accumulatedText.length,
      hasChartData: capturedChartData !== null,
    });

    // ─── 組回傳（與原版前端契約完全對齊） ──────────────────────
    const processedChartData = processToolResponse(capturedChartData);

    return new Response(
      JSON.stringify({
        content: accumulatedText,
        hasToolUse: capturedChartData !== null,
        // 前端 toolUse.name 仍用 generate_graph_data（不含 mcp__chart__ 前綴），
        // 維持原版 API 契約，前端程式碼不用改
        toolUse: capturedChartData
          ? {
              type: "tool_use",
              name: "generate_graph_data",
              input: capturedChartData,
            }
          : null,
        chartData: processedChartData,
      }),
      {
        headers: {
          "Content-Type": "application/json",
          "Cache-Control": "no-cache",
        },
      },
    );
  } catch (error) {
    // 完整錯誤只進 server log（含 stack trace），絕對不回給前端避免洩漏 CLI 路徑 / token 訊息
    const errMsg = error instanceof Error ? error.message : String(error);
    console.error("❌ Finance API Error:", error);
    console.error(
      "Full stack:",
      error instanceof Error ? error.stack : undefined,
    );

    const lowerMsg = errMsg.toLowerCase();

    // CLI 不存在：spawn 失敗 ENOENT，或錯誤訊息提到 claude not found
    if (
      errMsg.includes("ENOENT") ||
      (lowerMsg.includes("claude") && lowerMsg.includes("not found"))
    ) {
      return new Response(
        JSON.stringify({
          error: "CLI_NOT_FOUND",
          message:
            "Claude CLI not installed. Install it from https://docs.claude.com/en/api/agent-sdk",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // OAuth 失效：CLI session 過期或被撤銷
    if (
      lowerMsg.includes("oauth") ||
      lowerMsg.includes("unauthorized") ||
      lowerMsg.includes("401")
    ) {
      return new Response(
        JSON.stringify({
          error: "OAUTH_EXPIRED",
          message:
            "Claude CLI authentication expired. Run `claude login` in your terminal.",
        }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    // 通用 fallback：不洩漏內部訊息給 client，要 debug 看 server log
    return new Response(
      JSON.stringify({
        error: "INTERNAL_ERROR",
        message:
          "An error occurred processing your request. Check server logs.",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
}
