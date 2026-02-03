import { describe, it, expect, afterEach } from "vitest";
import { unlinkSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  newTaskManifest,
  createTask,
  getTask,
  updateTask,
  listTasks,
  getActiveTaskForEmployee,
  isEmployeeBusy,
  getTaskBySessionKey,
} from "./task-store.js";

// The task store writes to ~/.openclaw/workforce/tasks/ — we accept this
// for integration-style tests and clean up test tasks.

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

describe("newTaskManifest", () => {
  it("creates a manifest with correct defaults", () => {
    const m = newTaskManifest({
      employeeId: "emma-web",
      brief: "Build a website",
      sessionKey: "workforce-emma-web-abc12345",
    });
    expect(m.id).toMatch(/^task-/);
    expect(m.employeeId).toBe("emma-web");
    expect(m.brief).toBe("Build a website");
    expect(m.status).toBe("pending");
    expect(m.stage).toBe("clarify");
    expect(m.progress).toBe(0);
    expect(m.activities).toEqual([]);
    expect(m.outputs).toEqual([]);
    expect(m.attachments).toEqual([]);
    expect(m.createdAt).toBeTruthy();
    expect(m.updatedAt).toBeTruthy();
  });

  it("accepts attachments", () => {
    const m = newTaskManifest({
      employeeId: "test",
      brief: "test",
      sessionKey: "workforce-test-xyz",
      attachments: ["/path/to/file.png"],
    });
    expect(m.attachments).toEqual(["/path/to/file.png"]);
  });
});

describe("CRUD operations", () => {
  it("creates and retrieves a task", () => {
    const m = newTaskManifest({
      employeeId: "emma-web",
      brief: "Test task",
      sessionKey: "workforce-emma-web-crud1",
    });
    testTaskIds.push(m.id);
    createTask(m);

    const retrieved = getTask(m.id);
    expect(retrieved).not.toBeNull();
    expect(retrieved!.brief).toBe("Test task");
  });

  it("updates a task", () => {
    const m = newTaskManifest({
      employeeId: "emma-web",
      brief: "Update test",
      sessionKey: "workforce-emma-web-crud2",
    });
    testTaskIds.push(m.id);
    createTask(m);

    const updated = updateTask(m.id, { status: "running", stage: "execute" });
    expect(updated).not.toBeNull();
    expect(updated!.status).toBe("running");
    expect(updated!.stage).toBe("execute");
    // updatedAt should be set (may equal createdAt if same ms)
    expect(updated!.updatedAt).toBeTruthy();
    expect(new Date(updated!.updatedAt).getTime()).toBeGreaterThanOrEqual(new Date(m.createdAt).getTime());
  });

  it("returns null for missing task", () => {
    expect(getTask("nonexistent")).toBeNull();
    expect(updateTask("nonexistent", { status: "running" })).toBeNull();
  });
});

describe("query operations", () => {
  it("finds active task for employee", () => {
    const m = newTaskManifest({
      employeeId: "query-test-emp",
      brief: "Active task",
      sessionKey: "workforce-query-test-active",
    });
    testTaskIds.push(m.id);
    createTask(m);

    // Task is "pending" so it counts as active
    const active = getActiveTaskForEmployee("query-test-emp");
    expect(active).not.toBeNull();
    expect(active!.id).toBe(m.id);
    expect(isEmployeeBusy("query-test-emp")).toBe(true);
  });

  it("finds task by session key", () => {
    const sessionKey = "workforce-test-bysession-" + crypto.randomUUID().slice(0, 8);
    const m = newTaskManifest({
      employeeId: "test",
      brief: "Session key test",
      sessionKey,
    });
    testTaskIds.push(m.id);
    createTask(m);

    const found = getTaskBySessionKey(sessionKey);
    expect(found).not.toBeNull();
    expect(found!.id).toBe(m.id);
  });
});

describe("listTasks", () => {
  it("lists tasks with pagination", () => {
    const ids: string[] = [];
    for (let i = 0; i < 3; i++) {
      const m = newTaskManifest({
        employeeId: "list-test",
        brief: `List task ${i}`,
        sessionKey: `workforce-list-test-${i}`,
      });
      testTaskIds.push(m.id);
      ids.push(m.id);
      createTask(m);
    }

    const result = listTasks({ limit: 2, offset: 0 });
    expect(result.tasks.length).toBeLessThanOrEqual(2);
    expect(result.total).toBeGreaterThanOrEqual(3);
  });
});
