import { describe, it, expect, afterEach } from "vitest";
import { handleAgentEvent } from "./event-bridge.js";
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

function createTestTask(sessionKey: string) {
  const m = newTaskManifest({
    employeeId: "emma-web",
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
      { sessionKey: "workforce-unknown-xyz", stream: "tool", event: "tool_call", data: { name: "bash" } },
      (event, payload) => { broadcasts.push({ event, payload }); },
    );
    expect(broadcasts).toHaveLength(0);
  });

  it("processes tool_call events into activities", () => {
    const task = createTestTask("workforce-emma-web-test001");
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
    const task = createTestTask("workforce-emma-web-test002");
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
    const task = createTestTask("workforce-emma-web-test003");
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
    const task = createTestTask("workforce-emma-web-test010");
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
    const task = createTestTask("workforce-emma-web-test011");
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
    const task = createTestTask("workforce-emma-web-test012");
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
    const task = createTestTask("workforce-emma-web-test013");
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
    const task = createTestTask("workforce-emma-web-test014");
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
    const task = createTestTask("workforce-emma-web-test015");
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
    const task = createTestTask("workforce-emma-web-test016");
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
    const task = createTestTask("workforce-emma-web-test017");
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

  it("detects stage transitions from assistant text", () => {
    const task = createTestTask("workforce-emma-web-test004");
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
