import { describe, it, expect, afterEach } from "vitest";
import { handleAgentEvent, handleToolCall } from "./event-bridge.js";
import { newTaskManifest, createTask, getTask } from "./task-store.js";
import { join } from "node:path";
import { homedir } from "node:os";
import { unlinkSync } from "node:fs";

const testTaskIds: string[] = [];
const storeDir = join(homedir(), ".openclaw", "workforce", "tasks");

afterEach(() => {
  for (const id of testTaskIds) {
    try {
      unlinkSync(join(storeDir, `${id}.json`));
    } catch {
      // ignore
    }
  }
  testTaskIds.length = 0;
});

function createTestTask(sessionKey: string, employeeId = "emma-web") {
  const m = newTaskManifest({
    employeeId,
    brief: "Test task",
    sessionKey,
  });
  testTaskIds.push(m.id);
  createTask(m);
  return m;
}

describe("handleAgentEvent", () => {
  it("ignores events without workforce session key", () => {
    const broadcasts: Array<{ event: string; payload: unknown }> = [];
    handleAgentEvent(
      { sessionKey: "other-session", stream: "tool", event: "tool_call", data: { name: "bash" } },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );
    expect(broadcasts).toHaveLength(0);
  });

  it("ignores events with no matching task", () => {
    const broadcasts: Array<{ event: string; payload: unknown }> = [];
    handleAgentEvent(
      { sessionKey: "agent:unknown:workforce-xyz", stream: "tool", event: "tool_call", data: { name: "bash" } },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );
    expect(broadcasts).toHaveLength(0);
  });

  it("ignores old-format workforce session keys", () => {
    const broadcasts: Array<{ event: string; payload: unknown }> = [];
    handleAgentEvent(
      { sessionKey: "workforce-emma-web-abc12345", stream: "tool", event: "tool_call", data: { name: "bash" } },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );
    expect(broadcasts).toHaveLength(0);
  });

  it("processes tool_call events into activities", () => {
    const task = createTestTask("agent:emma-web:workforce-test001");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      { sessionKey: task.sessionKey, stream: "tool", event: "tool_call", data: { name: "bash" } },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const activityBroadcast = broadcasts.find((b) => b.event === "workforce.task.activity");
    expect(activityBroadcast).toBeTruthy();

    const progressBroadcast = broadcasts.find((b) => b.event === "workforce.task.progress");
    expect(progressBroadcast).toBeTruthy();

    // Verify activity was persisted
    const updated = getTask(task.id);
    expect(updated!.activities.length).toBeGreaterThan(0);
  });

  it("handles lifecycle complete", () => {
    const task = createTestTask("agent:emma-web:workforce-test002");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      { sessionKey: task.sessionKey, stream: "lifecycle", event: "complete", data: {} },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const completed = getTask(task.id);
    expect(completed!.status).toBe("completed");
    expect(completed!.stage).toBe("deliver");
    expect(completed!.progress).toBe(1.0);

    const completedBroadcast = broadcasts.find((b) => b.event === "workforce.task.completed");
    expect(completedBroadcast).toBeTruthy();
  });

  it("handles lifecycle error", () => {
    const task = createTestTask("agent:emma-web:workforce-test003");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      { sessionKey: task.sessionKey, stream: "lifecycle", event: "error", data: { message: "Something broke" } },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const failed = getTask(task.id);
    expect(failed!.status).toBe("failed");
    expect(failed!.errorMessage).toBe("Something broke");

    const failedBroadcast = broadcasts.find((b) => b.event === "workforce.task.failed");
    expect(failedBroadcast).toBeTruthy();
  });

  it("detects file output from Write tool with nested args", () => {
    const task = createTestTask("agent:emma-web:workforce-test010");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "tool",
        event: "tool_result",
        data: {
          name: "Write",
          args: { file_path: "/tmp/test-output.html" },
          result: "File written successfully",
        },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { taskId: string; output: { type: string; filePath: string; title: string } };
    expect(payload.output.type).toBe("website");
    expect(payload.output.filePath).toBe("/tmp/test-output.html");
    expect(payload.output.title).toBe("test-output.html");
  });

  it("detects file output from write_file tool with top-level path", () => {
    const task = createTestTask("agent:emma-web:workforce-test011");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "tool",
        event: "tool_call",
        data: {
          name: "write_file",
          path: "/tmp/report.md",
        },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; filePath: string } };
    expect(payload.output.type).toBe("document");
    expect(payload.output.filePath).toBe("/tmp/report.md");
  });

  it("detects localhost URL from bash tool result", () => {
    const task = createTestTask("agent:emma-web:workforce-test012");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "tool",
        event: "tool_result",
        data: {
          name: "Bash",
          result: "Server running at http://localhost:3000",
        },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; url: string } };
    expect(payload.output.type).toBe("website");
    expect(payload.output.url).toBe("http://localhost:3000");
  });

  it("detects file output from assistant text with backtick filename", () => {
    const task = createTestTask("agent:emma-web:workforce-test013");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: { text: "I've created the file and saved it as `landing-page.html` in your workspace." },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; title: string } };
    expect(payload.output.type).toBe("website");
    expect(payload.output.title).toBe("landing-page.html");
  });

  it("detects absolute file path from assistant text", () => {
    const task = createTestTask("agent:emma-web:workforce-test014");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: { text: "The report has been saved to /Users/dev/project/report.pdf" },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; filePath: string } };
    expect(payload.output.type).toBe("document");
    expect(payload.output.filePath).toBe("/Users/dev/project/report.pdf");
  });

  it("detects localhost URL from assistant text", () => {
    const task = createTestTask("agent:emma-web:workforce-test015");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: { text: "Your dev server is running at http://localhost:5173" },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; url: string } };
    expect(payload.output.type).toBe("website");
    expect(payload.output.url).toBe("http://localhost:5173");
  });

  it("does not duplicate assistant text outputs", () => {
    const task = createTestTask("agent:emma-web:workforce-test016");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    // First mention
    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: { text: "Saved as `app.html` in your workspace." },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const firstOutput = broadcasts.filter((b) => b.event === "workforce.task.output");
    expect(firstOutput).toHaveLength(1);

    broadcasts.length = 0;

    // Second mention of same file
    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: { text: "The `app.html` file is ready for you." },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const secondOutput = broadcasts.filter((b) => b.event === "workforce.task.output");
    expect(secondOutput).toHaveLength(0);
  });

  it("classifies output types correctly", () => {
    const task = createTestTask("agent:emma-web:workforce-test017");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    const testCases = [
      { path: "/tmp/slides.pptx", expectedType: "presentation" },
      { path: "/tmp/data.csv", expectedType: "spreadsheet" },
      { path: "/tmp/demo.mp4", expectedType: "video" },
      { path: "/tmp/recording.mp3", expectedType: "audio" },
      { path: "/tmp/script.py", expectedType: "code" },
      { path: "/tmp/photo.png", expectedType: "image" },
    ];

    for (const { path, expectedType } of testCases) {
      broadcasts.length = 0;
      handleAgentEvent(
        {
          sessionKey: task.sessionKey,
          stream: "tool",
          event: "tool_result",
          data: { name: "Write", args: { file_path: path }, result: "ok" },
        },
        (event, payload) => { broadcasts.push({ event, payload }); },
      );

      const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
      expect(outputBroadcast, `Expected output broadcast for ${path}`).toBeTruthy();

      const payload = outputBroadcast!.payload as { output: { type: string } };
      expect(payload.output.type, `Expected ${expectedType} for ${path}`).toBe(expectedType);
    }
  });

  it("detects bold-formatted filenames from assistant text", () => {
    const task = createTestTask("agent:emma-web:workforce-test030");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: { text: "I've created **LifeWiki_Presentation.pptx** for you." },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; title: string } };
    expect(payload.output.type).toBe("presentation");
    expect(payload.output.title).toBe("LifeWiki_Presentation.pptx");
  });

  it("detects multiple outputs from a single assistant message", () => {
    const task = createTestTask("agent:emma-web:workforce-test031");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: {
          text: "Files created:\n1. **LifeWiki_Presentation.pptx** - PowerPoint\n2. **lifewiki-presentation.html** - Web version\n3. **lifewiki-outline.md** - Outline",
        },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcasts = broadcasts.filter((b) => b.event === "workforce.task.output");
    expect(outputBroadcasts).toHaveLength(3);

    const types = outputBroadcasts.map((b) => (b.payload as { output: { type: string } }).output.type);
    expect(types).toContain("presentation");
    expect(types).toContain("website");
    expect(types).toContain("document");
  });

  it("deduplicates bold and backtick mentions of the same file", () => {
    const task = createTestTask("agent:emma-web:workforce-test032");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      {
        sessionKey: task.sessionKey,
        stream: "assistant",
        data: { text: "Created **report.pdf** — the `report.pdf` is ready." },
      },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcasts = broadcasts.filter((b) => b.event === "workforce.task.output");
    expect(outputBroadcasts).toHaveLength(1);
  });

  it("detects stage transitions from assistant text", () => {
    const task = createTestTask("agent:emma-web:workforce-test004");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleAgentEvent(
      { sessionKey: task.sessionKey, stream: "assistant", data: { text: "I'll plan the approach for this task" } },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const updated = getTask(task.id);
    expect(updated!.stage).toBe("plan");

    const stageBroadcast = broadcasts.find((b) => b.event === "workforce.task.stage");
    expect(stageBroadcast).toBeTruthy();
  });
});

describe("handleToolCall (after_tool_call hook path)", () => {
  it("detects file output from Write tool params", () => {
    const task = createTestTask("agent:emma-web:workforce-test020");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "Write",
      { file_path: "/tmp/landing-page.html" },
      "File written successfully",
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; filePath: string; title: string } };
    expect(payload.output.type).toBe("website");
    expect(payload.output.filePath).toBe("/tmp/landing-page.html");
    expect(payload.output.title).toBe("landing-page.html");

    // Verify output was persisted to task store
    const updated = getTask(task.id);
    expect(updated!.outputs.length).toBe(1);
    expect(updated!.outputs[0].filePath).toBe("/tmp/landing-page.html");
  });

  it("detects file output from write_file tool params", () => {
    const task = createTestTask("agent:emma-web:workforce-test021");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "write_file",
      { path: "/home/user/report.md" },
      undefined,
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string } };
    expect(payload.output.type).toBe("document");
  });

  it("detects localhost URL from Bash tool result", () => {
    const task = createTestTask("agent:emma-web:workforce-test022");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "Bash",
      { command: "npm start" },
      "Server running at http://localhost:8080\nReady.",
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; url: string } };
    expect(payload.output.type).toBe("website");
    expect(payload.output.url).toBe("http://localhost:8080");
  });

  it("detects file path from Bash result text", () => {
    const task = createTestTask("agent:emma-web:workforce-test023");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "bash",
      { command: "cat > /tmp/output.csv" },
      "Written to /tmp/output.csv",
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; filePath: string } };
    expect(payload.output.type).toBe("spreadsheet");
    expect(payload.output.filePath).toBe("/tmp/output.csv");
  });

  it("ignores non-write tools without URL output", () => {
    const task = createTestTask("agent:emma-web:workforce-test024");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "Read",
      { file_path: "/tmp/something.txt" },
      "file contents here",
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeUndefined();
  });

  it("detects relative file paths from Bash result", () => {
    const task = createTestTask("agent:emma-web:workforce-test026");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "Bash",
      { command: "python3 create_ppt.py" },
      "Created LifeWiki_Presentation.pptx",
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { type: string; title: string; filePath: string } };
    expect(payload.output.type).toBe("presentation");
    expect(payload.output.title).toBe("LifeWiki_Presentation.pptx");
    expect(payload.output.filePath).toContain("LifeWiki_Presentation.pptx");
  });

  it("detects multiple file paths from Bash result", () => {
    const task = createTestTask("agent:emma-web:workforce-test027");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "bash",
      { command: "python3 create_files.py" },
      "Created slides.pptx\nCreated overview.html\nCreated notes.md",
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcasts = broadcasts.filter((b) => b.event === "workforce.task.output");
    expect(outputBroadcasts).toHaveLength(3);

    const types = outputBroadcasts.map((b) => (b.payload as { output: { type: string } }).output.type);
    expect(types).toContain("presentation");
    expect(types).toContain("website");
    expect(types).toContain("document");
  });

  it("does not duplicate localhost URLs", () => {
    const task = createTestTask("agent:emma-web:workforce-test025");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];
    const broadcast = (event: string, payload: unknown) => { broadcasts.push({ event, payload }); };

    handleToolCall(task.id, "Bash", {}, "http://localhost:3000", broadcast);
    const first = broadcasts.filter((b) => b.event === "workforce.task.output");
    expect(first).toHaveLength(1);

    broadcasts.length = 0;
    handleToolCall(task.id, "Bash", {}, "http://localhost:3000", broadcast);
    const second = broadcasts.filter((b) => b.event === "workforce.task.output");
    expect(second).toHaveLength(0);
  });

  it("resolves relative paths against employee workspace", () => {
    const task = createTestTask("agent:emma-web:workforce-test040");
    const broadcasts: Array<{ event: string; payload: unknown }> = [];

    handleToolCall(
      task.id,
      "Write",
      { file_path: "output.html" },
      "File written",
      (event, payload) => { broadcasts.push({ event, payload }); },
    );

    const outputBroadcast = broadcasts.find((b) => b.event === "workforce.task.output");
    expect(outputBroadcast).toBeTruthy();

    const payload = outputBroadcast!.payload as { output: { filePath: string } };
    // Should resolve against workspace-emma-web, not workspace
    expect(payload.output.filePath).toContain("workspace-emma-web");
    expect(payload.output.filePath).toContain("output.html");
  });
});
