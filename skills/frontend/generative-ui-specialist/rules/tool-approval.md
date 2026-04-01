# GEN-06: Tool Approval & Human-in-the-Loop (HIGH)

AI SDK 6 introduces built-in tool approval via `needsApproval`.

## Defining tools with approval

```typescript
import { tool } from "ai";
import { z } from "zod";

const dangerousTool = tool({
  description: "Run a shell command",
  inputSchema: z.object({ command: z.string() }),
  needsApproval: true, // requires human approval before execution
  execute: async ({ command }) => { /* ... */ },
});

// Dynamic approval based on input:
const paymentTool = tool({
  description: "Process a payment",
  inputSchema: z.object({ amount: z.number() }),
  needsApproval: async ({ input }) => input.amount > 100,
  execute: async ({ amount }) => { /* ... */ },
});
```

## Handling approval in messages

```typescript
import { type ModelMessage, generateText, type ToolApprovalResponse } from "ai";

const result = await generateText({ model, tools: { dangerousTool }, messages });
messages.push(...result.response.messages);

const approvals: ToolApprovalResponse[] = [];
for (const part of result.content) {
  if (part.type === "tool-approval-request") {
    approvals.push({
      type: "tool-approval-response",
      approvalId: part.approvalId,
      approved: true, // or false
      reason: "User confirmed",
    });
  }
}
messages.push({ role: "tool", content: approvals });
const followUp = await generateText({ model, tools: { dangerousTool }, messages });
```
