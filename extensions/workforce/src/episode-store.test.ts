import { describe, it, expect, afterEach, beforeEach } from "vitest";
import { existsSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  listEmployeeEpisodes,
  getEmployeeEpisode,
  countEmployeeEpisodes,
  type TaskEpisode,
} from "./episode-store.js";

// Test against a dedicated test employee workspace
const TEST_EMPLOYEE_ID = "test-episode-employee";
const workspaceDir = join(homedir(), ".openclaw", `workspace-${TEST_EMPLOYEE_ID}`);
const episodesDir = join(workspaceDir, "memory", "episodes");

function createTestEpisode(overrides: Partial<TaskEpisode> = {}): TaskEpisode {
  const id = `task-${crypto.randomUUID().slice(0, 8)}`;
  return {
    taskId: id,
    employeeId: TEST_EMPLOYEE_ID,
    brief: "Test episode brief",
    status: "completed",
    startedAt: new Date().toISOString(),
    completedAt: new Date().toISOString(),
    outputs: [],
    ...overrides,
  };
}

function writeEpisode(episode: TaskEpisode): void {
  mkdirSync(episodesDir, { recursive: true });
  const path = join(episodesDir, `${episode.taskId}.json`);
  writeFileSync(path, JSON.stringify(episode, null, 2));
}

beforeEach(() => {
  // Ensure test workspace exists
  mkdirSync(workspaceDir, { recursive: true });
});

afterEach(() => {
  // Clean up episodes directory
  try {
    if (existsSync(episodesDir)) {
      rmSync(episodesDir, { recursive: true });
    }
  } catch {
    // ignore
  }
});

describe("listEmployeeEpisodes", () => {
  it("returns empty array when no episodes exist", () => {
    const episodes = listEmployeeEpisodes(TEST_EMPLOYEE_ID);
    expect(episodes).toEqual([]);
  });

  it("returns episodes sorted by completion time (newest first)", () => {
    // Create episodes with different completion times
    const episode1 = createTestEpisode({
      taskId: "task-001",
      completedAt: "2024-01-01T10:00:00.000Z",
    });
    const episode2 = createTestEpisode({
      taskId: "task-002",
      completedAt: "2024-01-02T10:00:00.000Z",
    });
    const episode3 = createTestEpisode({
      taskId: "task-003",
      completedAt: "2024-01-03T10:00:00.000Z",
    });

    writeEpisode(episode1);
    writeEpisode(episode2);
    writeEpisode(episode3);

    const episodes = listEmployeeEpisodes(TEST_EMPLOYEE_ID);

    expect(episodes).toHaveLength(3);
    expect(episodes[0].taskId).toBe("task-003"); // newest
    expect(episodes[1].taskId).toBe("task-002");
    expect(episodes[2].taskId).toBe("task-001"); // oldest
  });

  it("respects limit option", () => {
    for (let i = 1; i <= 5; i++) {
      writeEpisode(createTestEpisode({ taskId: `task-${i}` }));
    }

    const episodes = listEmployeeEpisodes(TEST_EMPLOYEE_ID, { limit: 3 });
    expect(episodes).toHaveLength(3);
  });

  it("filters by status", () => {
    writeEpisode(createTestEpisode({ taskId: "task-c1", status: "completed" }));
    writeEpisode(createTestEpisode({ taskId: "task-c2", status: "completed" }));
    writeEpisode(createTestEpisode({ taskId: "task-f1", status: "failed" }));
    writeEpisode(createTestEpisode({ taskId: "task-x1", status: "cancelled" }));

    const completed = listEmployeeEpisodes(TEST_EMPLOYEE_ID, { status: "completed" });
    const failed = listEmployeeEpisodes(TEST_EMPLOYEE_ID, { status: "failed" });
    const cancelled = listEmployeeEpisodes(TEST_EMPLOYEE_ID, { status: "cancelled" });

    expect(completed).toHaveLength(2);
    expect(failed).toHaveLength(1);
    expect(cancelled).toHaveLength(1);
  });

  it("handles malformed JSON files gracefully", () => {
    // Write a valid episode
    writeEpisode(createTestEpisode({ taskId: "task-valid" }));

    // Write an invalid JSON file
    mkdirSync(episodesDir, { recursive: true });
    writeFileSync(join(episodesDir, "task-invalid.json"), "{ invalid json }");

    const episodes = listEmployeeEpisodes(TEST_EMPLOYEE_ID);

    // Should return only the valid episode
    expect(episodes).toHaveLength(1);
    expect(episodes[0].taskId).toBe("task-valid");
  });
});

describe("getEmployeeEpisode", () => {
  it("returns null when episode does not exist", () => {
    const episode = getEmployeeEpisode(TEST_EMPLOYEE_ID, "nonexistent");
    expect(episode).toBeNull();
  });

  it("retrieves a specific episode by task ID", () => {
    const testEpisode = createTestEpisode({
      taskId: "task-specific",
      brief: "Specific task brief",
    });
    writeEpisode(testEpisode);

    const episode = getEmployeeEpisode(TEST_EMPLOYEE_ID, "task-specific");

    expect(episode).not.toBeNull();
    expect(episode!.taskId).toBe("task-specific");
    expect(episode!.brief).toBe("Specific task brief");
  });

  it("returns null for malformed JSON", () => {
    mkdirSync(episodesDir, { recursive: true });
    writeFileSync(join(episodesDir, "task-bad.json"), "not json");

    const episode = getEmployeeEpisode(TEST_EMPLOYEE_ID, "task-bad");
    expect(episode).toBeNull();
  });
});

describe("countEmployeeEpisodes", () => {
  it("returns 0 when no episodes exist", () => {
    const count = countEmployeeEpisodes(TEST_EMPLOYEE_ID);
    expect(count).toBe(0);
  });

  it("counts all episode files", () => {
    writeEpisode(createTestEpisode({ taskId: "task-1" }));
    writeEpisode(createTestEpisode({ taskId: "task-2" }));
    writeEpisode(createTestEpisode({ taskId: "task-3" }));

    const count = countEmployeeEpisodes(TEST_EMPLOYEE_ID);
    expect(count).toBe(3);
  });

  it("ignores non-JSON files", () => {
    writeEpisode(createTestEpisode({ taskId: "task-1" }));
    mkdirSync(episodesDir, { recursive: true });
    writeFileSync(join(episodesDir, "not-an-episode.txt"), "text file");

    const count = countEmployeeEpisodes(TEST_EMPLOYEE_ID);
    expect(count).toBe(1);
  });
});
