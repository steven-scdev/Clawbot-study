# Building Skills for AI Employees: A Practitioner's Guide

> **Case Study: The Preview Tool** — Our first implemented skill that enables AI employees to present their work in the Workforce app's preview panel.

---

## Executive Summary

This document captures the complete journey of building the Preview Tool skill for AI employees. It serves as a reference architecture for engineers building future skills, tools, and capabilities for domain-expert AI employees.

**Key Insight**: AI employees are only as capable as their skills allow. The OpenClaw runtime provides a powerful foundation, but the differentiator is giving employees the right skills, tools, instructions, and experiences for their domain.

---

## The Three Pillars of Agent Skills

Every skill for an AI employee consists of three essential components:

```
┌─────────────────────────────────────────────────────────────────┐
│                     AGENT SKILL ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐   │
│   │    TOOL     │   │  GUIDANCE   │   │   INFRASTRUCTURE    │   │
│   │             │   │             │   │                     │   │
│   │ The actual  │   │ Teaching    │   │ Backend support:    │   │
│   │ capability  │   │ agents when │   │ gateway methods,    │   │
│   │ agents can  │   │ and how to  │   │ notifications,      │   │
│   │ invoke      │   │ use it      │   │ UI handlers         │   │
│   └─────────────┘   └─────────────┘   └─────────────────────┘   │
│         │                 │                     │                │
│         └─────────────────┼─────────────────────┘                │
│                           │                                      │
│                    ┌──────▼──────┐                               │
│                    │   WORKING   │                               │
│                    │    SKILL    │                               │
│                    └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

**Critical Learning**: All three pillars must be present. A tool without guidance is invisible to agents. Guidance without a tool is just documentation. Infrastructure without both is unused plumbing.

---

## Architecture Deep Dive

### How Agents Get Their Tools

Understanding the tool pipeline is essential for adding new capabilities:

```
createOpenClawCodingTools() ─── pi-tools.ts
         │
         ├── Base coding tools (read, write, edit, exec)
         │
         └── createOpenClawTools() ─── openclaw-tools.ts
                    │
                    ├── Browser, canvas, nodes, message, TTS...
                    ├── Sessions tools (list, history, send, spawn)
                    ├── Web tools (search, fetch)
                    ├── Image tool
                    └── Preview tool  ◄── NEW SKILL
```

**File**: `src/agents/openclaw-tools.ts`

```typescript
// Adding a new tool follows this pattern:
import { createPreviewTool } from "./tools/preview-tool.js";

export function createOpenClawTools(options?: {
  // ... existing options
  agentSessionKey?: string;  // Critical for workforce context
}): AnyAgentTool[] {
  const tools: AnyAgentTool[] = [
    // ... existing tools
    createPreviewTool({
      sessionKey: options?.agentSessionKey,  // Pass context!
    }),
  ];
  return tools;
}
```

### How Agents Get Their Identity (System Prompt)

The workforce plugin composes each employee's identity from markdown files:

```
~/.openclaw/workspace-{employeeId}/IDENTITY.md
         │
         └── Composed by mind-composer.ts from:
                    │
                    ├── minds/{employeeId}/lens.md        (How they see work)
                    ├── minds/{employeeId}/standards.md   (Quality bar)
                    ├── minds/{employeeId}/principles.md  (Decision framework)
                    ├── buildMemoryGuidance()             (Memory instructions)
                    └── buildPreviewGuidance()  ◄── NEW SKILL GUIDANCE
```

**File**: `extensions/workforce/src/mind-composer.ts`

```typescript
export function composeMind(employeeId: string, mindsDir: string): string {
  // ... load lens, standards, principles

  const sections: string[] = [];
  sections.push("# Your Professional Identity\n");

  if (lens) sections.push("## How You See Your Work\n", lens, "");
  if (standards) sections.push("## Your Quality Standards\n", standards, "");
  if (principles) sections.push("## Your Working Principles\n", principles, "");

  // Add skill guidance
  sections.push(buildMemoryGuidance());
  sections.push(buildPreviewGuidance());  // ◄── ADD YOUR SKILL HERE

  return sections.join("\n");
}
```

### How Gateway Methods Work

The workforce plugin registers gateway methods that the tool calls:

```
Agent calls preview tool
         │
         ▼
preview-tool.ts executes
         │
         ▼
callGatewayTool("workforce.output.present", ...)
         │
         ▼
Gateway routes to workforce plugin
         │
         ▼
Plugin handler creates output, broadcasts event
         │
         ▼
macOS app receives via WebSocket
         │
         ▼
SwiftUI notifications update UI
```

**File**: `extensions/workforce/index.ts`

```typescript
api.registerGatewayMethod("workforce.output.present", async ({ params, respond, context }) => {
  // 1. Parse and validate params
  const taskId = params.taskId as string;
  const filePath = params.filePath as string | undefined;
  const url = params.url as string | undefined;

  // 2. Create the output object
  const output = filePath
    ? createFileOutput(filePath, agentId, title)
    : createUrlOutput(url!, title);

  // 3. Add to task outputs
  appendOutput(taskId, output);

  // 4. Broadcast to UI
  context.broadcast("workforce.output.present", {
    taskId,
    output,
    present: true,  // Signal UI to switch to this output
  });

  respond(true, { outputId: output.id, output });
});
```

---

## Implementation Walkthrough: The Preview Tool

### Step 1: Create the Tool

**File**: `src/agents/tools/preview-tool.ts`

```typescript
import { Type } from "@sinclair/typebox";
import { stringEnum } from "../schema/typebox.js";
import { type AnyAgentTool, jsonResult, readStringParam } from "./common.js";
import { callGatewayTool, type GatewayCallOptions } from "./gateway.js";

const PREVIEW_ACTIONS = ["present", "refresh"] as const;

const PreviewToolSchema = Type.Object({
  action: stringEnum(PREVIEW_ACTIONS),
  taskId: Type.Optional(Type.String()),
  sessionKey: Type.Optional(Type.String()),
  path: Type.Optional(Type.String()),
  title: Type.Optional(Type.String()),
});

export function createPreviewTool(opts?: {
  taskId?: string;
  sessionKey?: string;
}): AnyAgentTool {
  return {
    label: "Preview",
    name: "preview",
    description:
      "Present outputs to the user in the Workforce app preview panel. " +
      "Use 'present' to show a file or URL after creating/updating it. " +
      "Use 'refresh' to reload the current view.",
    parameters: PreviewToolSchema,
    execute: async (_toolCallId, args) => {
      const params = args as Record<string, unknown>;
      const action = readStringParam(params, "action", { required: true });

      // Context inheritance: tool creation context → runtime params
      const taskId = readStringParam(params, "taskId") ?? opts?.taskId;
      const sessionKey = readStringParam(params, "sessionKey") ?? opts?.sessionKey;

      if (!taskId && !sessionKey) {
        throw new Error("taskId or sessionKey is required");
      }

      switch (action) {
        case "present": {
          const path = readStringParam(params, "path", { required: true });
          const title = readStringParam(params, "title");
          const isUrl = path.startsWith("http://") || path.startsWith("https://");

          await callGatewayTool("workforce.output.present", {}, {
            taskId,
            sessionKey,
            filePath: isUrl ? undefined : path,
            url: isUrl ? path : undefined,
            title,
          });

          return jsonResult({ ok: true, message: `Presented ${title ?? path}` });
        }

        case "refresh": {
          await callGatewayTool("workforce.output.refresh", {}, { taskId, sessionKey });
          return jsonResult({ ok: true, message: "Preview panel refreshed" });
        }
      }
    },
  };
}
```

### Step 2: Register the Tool

**File**: `src/agents/openclaw-tools.ts`

```typescript
import { createPreviewTool } from "./tools/preview-tool.js";

export function createOpenClawTools(options?: {
  agentSessionKey?: string;
  // ... other options
}): AnyAgentTool[] {
  const tools: AnyAgentTool[] = [
    // ... other tools
    createPreviewTool({
      sessionKey: options?.agentSessionKey,
    }),
  ];
  return tools;
}
```

### Step 3: Add Gateway Methods

**File**: `extensions/workforce/index.ts`

```typescript
// workforce.output.present — Show output in preview panel
api.registerGatewayMethod("workforce.output.present", async ({ params, respond, context }) => {
  // Accept taskId directly or derive from sessionKey
  let taskId = params.taskId as string | undefined;
  const sessionKey = params.sessionKey as string | undefined;

  if (!taskId && sessionKey) {
    const taskBySession = getTaskBySessionKey(sessionKey);
    if (taskBySession) taskId = taskBySession.id;
  }

  if (!taskId) {
    respond(false, { error: "Must provide either taskId or sessionKey" });
    return;
  }

  const filePath = params.filePath as string | undefined;
  const url = params.url as string | undefined;
  const title = params.title as string | undefined;

  const task = getTask(taskId);
  if (!task) {
    respond(false, { error: `Task not found: ${taskId}` });
    return;
  }

  const output = filePath
    ? createFileOutput(filePath, agentId, title)
    : createUrlOutput(url!, title);

  appendOutput(taskId, output);

  // Broadcast to UI with "present" flag
  context.broadcast("workforce.output.present", {
    taskId,
    output,
    present: true,
  });

  respond(true, { outputId: output.id, output });
});

// workforce.output.refresh — Reload current preview
api.registerGatewayMethod("workforce.output.refresh", async ({ params, respond, context }) => {
  // Similar pattern: accept taskId or sessionKey
  // Broadcast refresh event to UI
  context.broadcast("workforce.output.refresh", { taskId });
  respond(true, { success: true });
});
```

### Step 4: Add Agent Guidance

**File**: `extensions/workforce/src/mind-composer.ts`

```typescript
function buildPreviewGuidance(): string {
  return `
## Showing Your Work

You work within the Workforce app, which has a **preview panel** where users can see your outputs.

**Use the \`preview\` tool to show outputs:**
- After creating a file (HTML, PowerPoint, image, document), call \`preview\` with action "present" to display it
- When the user asks to "see" something, "show" something, or view something in the "output panel" or "preview", use the preview tool
- To reload content after making changes to an already-displayed file, use action "refresh"

**Examples:**
\`\`\`
// After creating a presentation
preview(action="present", path="/path/to/deck.pptx", title="Q4 Strategy Deck")

// After creating an HTML page
preview(action="present", path="/path/to/landing.html", title="Landing Page")

// Show a website URL
preview(action="present", path="https://example.com", title="Example Site")

// Refresh the current view after updating a file
preview(action="refresh")
\`\`\`

**IMPORTANT - When to use preview:**
- **Immediately** after creating or significantly updating any visual output
- When the user explicitly asks to see something, show something, or view the output
- When showing a website, URL, or web content — use the preview tool, NOT browser control
- The preview panel is built into the app — you don't need external browsers

The preview panel is the primary way users see your work. **Always use the \`preview\` tool** to show outputs.
`;
}
```

### Step 5: Handle Events in macOS App

**File**: `apps/macos/Sources/Workforce/Services/TaskService.swift`

```swift
// Add notification names
extension Notification.Name {
    static let presentOutput = Notification.Name("ai.openclaw.workforce.presentOutput")
    static let refreshOutput = Notification.Name("ai.openclaw.workforce.refreshOutput")
}

// Handle gateway push events
private func handleWorkforcePush(_ push: GatewayPush) {
    switch push.type {
    case "workforce.output.present":
        guard let payload = push.payload,
              let taskId = payload["taskId"] as? String,
              let outputData = payload["output"] as? [String: Any] else { return }

        let output = parseOutput(outputData, taskId: taskId)
        if let index = tasks.firstIndex(where: { $0.id == taskId }) {
            tasks[index].outputs.append(output)
        }

        // Notify UI to switch to this output
        NotificationCenter.default.post(
            name: .presentOutput,
            object: nil,
            userInfo: ["taskId": taskId, "outputId": output.id]
        )

    case "workforce.output.refresh":
        guard let payload = push.payload,
              let taskId = payload["taskId"] as? String else { return }
        NotificationCenter.default.post(
            name: .refreshOutput,
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }
}
```

**File**: `apps/macos/Sources/Workforce/Views/Tasks/TaskChatView.swift`

```swift
.onReceive(NotificationCenter.default.publisher(for: .presentOutput)) { notification in
    guard let userInfo = notification.userInfo,
          let notifTaskId = userInfo["taskId"] as? String,
          let outputId = userInfo["outputId"] as? String,
          notifTaskId == self.taskId else { return }

    // Switch to the presented output
    self.selectedOutputId = outputId

    // Open pane if not already showing
    if !self.showArtifactPane {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.showArtifactPane = true
        }
    }
}
```

---

## Debugging Journey & Lessons Learned

### Issue 1: Agent Didn't Understand User Intent

**Symptom**: User said "show me in the output panel" but agent asked clarifying questions or tried browser control.

**Root Cause**: Agent had no guidance about the preview tool in its system prompt.

**Solution**: Added `buildPreviewGuidance()` to mind-composer.ts with clear examples and trigger phrases.

**Lesson**: **Agents need explicit guidance for every skill.** Just having a tool isn't enough — they need to know:
- WHEN to use it (trigger phrases, situations)
- HOW to use it (examples, parameter patterns)
- WHY to use it instead of alternatives (explicit "NOT browser control")

### Issue 2: Agent Used Wrong Tools (canvas, nodes)

**Symptom**: Log showed agent calling `canvas` tool (failed) then `nodes` tool.

**Root Cause**: IDENTITY.md files hadn't been regenerated after adding preview guidance.

**Solution**: Restart gateway — `setupAgentWorkspaces()` runs on gateway start.

**Lesson**: **IDENTITY.md files are generated at gateway startup.** Changes to mind-composer.ts require a gateway restart to take effect.

### Issue 3: "Unknown Method" Errors

**Symptom**: `workforce.employees.list` and other methods showed as "unknown".

**Root Cause**: Workforce plugin wasn't enabled in config.

**Solution**: Added to `~/.openclaw/openclaw.json`:
```json
{
  "plugins": {
    "entries": {
      "workforce": {
        "enabled": true
      }
    }
  }
}
```

**Lesson**: **Plugins must be explicitly enabled.** Check `plugins.entries.{pluginId}.enabled` in config.

### Issue 4: "taskId is required" Error

**Symptom**: Preview tool was called but failed with missing context.

**Root Cause**: Gateway was running old code from before sessionKey support was added.

**Solution**: Restart gateway to load rebuilt code.

**Lesson**: **The gateway loads code at startup.** After `pnpm build`, you must restart the gateway for changes to take effect.

---

## Checklist for Building New Skills

### Pre-Implementation
- [ ] Define the user intent this skill addresses
- [ ] Identify trigger phrases users might say
- [ ] Determine if this is a workforce-wide skill or employee-specific
- [ ] Check if similar functionality exists (avoid duplication)

### Tool Implementation
- [ ] Create tool file in `src/agents/tools/{skill}-tool.ts`
- [ ] Define TypeBox schema for parameters
- [ ] Implement execute function with proper error handling
- [ ] Support context inheritance (sessionKey/taskId from tool creation)
- [ ] Add to `createOpenClawTools()` in `openclaw-tools.ts`
- [ ] Pass necessary context (agentSessionKey, etc.)

### Gateway Methods (if needed)
- [ ] Add gateway method handlers in `extensions/workforce/index.ts`
- [ ] Support both taskId and sessionKey for flexibility
- [ ] Use `context.broadcast()` for UI updates
- [ ] Return meaningful success/error responses

### Agent Guidance
- [ ] Create `build{Skill}Guidance()` function in `mind-composer.ts`
- [ ] Include clear trigger phrase examples
- [ ] Provide parameter usage examples
- [ ] Explicitly state when NOT to use alternatives
- [ ] Call the guidance function in `composeMind()`

### macOS App (if UI needed)
- [ ] Add notification names in TaskService.swift
- [ ] Handle gateway push events in `handleWorkforcePush()`
- [ ] Add notification observers in relevant SwiftUI views
- [ ] Implement UI updates (animations, state changes)

### Testing & Deployment
- [ ] Rebuild: `pnpm build`
- [ ] Restart gateway (quit/reopen OpenClaw.app)
- [ ] Verify IDENTITY.md files regenerated with new guidance
- [ ] Test with natural language prompts
- [ ] Test edge cases (missing params, errors)

---

## Design Principles for Agent Skills

### 1. Make Skills Discoverable
Agents can only use what they know about. Every skill needs:
- Clear description in tool definition
- Explicit guidance in system prompt
- Example invocations showing common patterns

### 2. Context Should Flow Automatically
Don't require agents to manually pass context they shouldn't need to know:
```typescript
// Good: sessionKey inherited from tool creation
createPreviewTool({ sessionKey: options?.agentSessionKey })

// Bad: requiring agent to somehow know the sessionKey
preview(action="present", sessionKey="workforce:phil-ppt:abc123", ...)
```

### 3. Support Multiple Identification Patterns
Gateway methods should accept multiple ways to identify resources:
```typescript
// Accept taskId directly OR derive from sessionKey
let taskId = params.taskId;
if (!taskId && sessionKey) {
  taskId = getTaskBySessionKey(sessionKey)?.id;
}
```

### 4. Fail with Helpful Messages
When things go wrong, tell the agent what to do:
```typescript
// Good
throw new Error("taskId or sessionKey is required - provide in params or via tool context");

// Bad
throw new Error("Missing parameter");
```

### 5. Guidance Should Be Prescriptive
Don't just describe what the tool does — tell agents exactly when to use it:
```markdown
**IMPORTANT - When to use preview:**
- **Immediately** after creating or significantly updating any visual output
- When the user explicitly asks to see something
- When showing a website — use the preview tool, NOT browser control
```

### 6. Test with Natural Language
The ultimate test is whether users can trigger the skill naturally:
- "Show me the presentation"
- "Open that in the preview"
- "Let me see what you made"
- "Display the output"

---

## Future Skill Ideas

Based on the patterns established with the preview tool, here are potential skills for different domain experts:

### Phil (Presentation Designer)
- **export** — Export deck to PDF, images, or web format
- **animate** — Add/modify slide animations
- **template** — Apply or create presentation templates

### David (Data Analyst)
- **chart** — Create interactive visualizations
- **dashboard** — Build live data dashboards
- **query** — Execute and visualize database queries

### Emma (Web Developer)
- **deploy** — Deploy site to hosting provider
- **lighthouse** — Run performance/accessibility audits
- **responsive** — Preview site at different screen sizes

### Sarah (Researcher)
- **cite** — Format citations in various styles
- **summarize** — Create executive summaries of research
- **compare** — Side-by-side comparison of sources

---

## Appendix: Key Files Reference

| Purpose | Location |
|---------|----------|
| Tool definitions | `src/agents/tools/*.ts` |
| Tool registration | `src/agents/openclaw-tools.ts` |
| Tool creation pipeline | `src/agents/pi-tools.ts` |
| Agent identity composition | `extensions/workforce/src/mind-composer.ts` |
| Employee mind files | `extensions/workforce/minds/{employeeId}/*.md` |
| Workforce plugin (gateway methods) | `extensions/workforce/index.ts` |
| Task/output management | `extensions/workforce/src/task-store.ts` |
| macOS event handling | `apps/macos/.../TaskService.swift` |
| macOS chat view | `apps/macos/.../TaskChatView.swift` |
| Agent workspace setup | `extensions/workforce/src/agent-workspaces.ts` |
| Plugin configuration | `~/.openclaw/openclaw.json` |
| Generated identity files | `~/.openclaw/workspace-{employeeId}/IDENTITY.md` |

---

## Conclusion

Building skills for AI employees is about creating a complete loop:
1. **Tool** gives the capability
2. **Guidance** teaches when and how
3. **Infrastructure** makes it work end-to-end

The preview tool demonstrates this pattern in practice. By following this architecture, future skills can be built confidently, knowing they'll integrate seamlessly with the existing workforce system.

Remember: **The runtime is the foundation. Skills are the differentiator.**

---

*Document created: February 5, 2026*
*First skill implemented: Preview Tool*
*Author: Claude (with guidance from the implementation journey)*
