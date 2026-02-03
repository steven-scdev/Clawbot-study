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
