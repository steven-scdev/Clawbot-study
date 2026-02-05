import { describe, it, expect, afterEach, beforeEach } from "vitest";
import { unlinkSync, existsSync, readFileSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { writeTaskEpisode, updateEmployeeMemory, type TaskEpisode } from "./memory-writer.js";
import type { TaskManifest } from "./task-store.js";

// Test against a dedicated test employee workspace
const TEST_EMPLOYEE_ID = "test-memory-employee";
const workspaceDir = join(homedir(), ".openclaw", `workspace-${TEST_EMPLOYEE_ID}`);
const episodesDir = join(workspaceDir, "memory", "episodes");
const memoryPath = join(workspaceDir, "MEMORY.md");

const createdFiles: string[] = [];

function createTestTask(overrides: Partial<TaskManifest> = {}): TaskManifest {
  const id = `task-test-${crypto.randomUUID().slice(0, 8)}`;
  return {
    id,
    employeeId: TEST_EMPLOYEE_ID,
    brief: "Test task brief",
    sessionKey: `workforce-${TEST_EMPLOYEE_ID}-${crypto.randomUUID().slice(0, 8)}`,
    status: "completed",
    stage: "deliver",
    progress: 1.0,
    activities: [],
    outputs: [],
    attachments: [],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    completedAt: new Date().toISOString(),
    ...overrides,
  };
}

beforeEach(() => {
  // Ensure test workspace exists
  mkdirSync(workspaceDir, { recursive: true });
});

afterEach(() => {
  // Clean up created files
  for (const file of createdFiles) {
    try {
      if (existsSync(file)) {
        unlinkSync(file);
      }
    } catch {
      // ignore
    }
  }
  createdFiles.length = 0;

  // Clean up MEMORY.md
  try {
    if (existsSync(memoryPath)) {
      unlinkSync(memoryPath);
    }
  } catch {
    // ignore
  }

  // Clean up episodes directory
  try {
    if (existsSync(episodesDir)) {
      rmSync(episodesDir, { recursive: true });
    }
  } catch {
    // ignore
  }
});

describe("writeTaskEpisode", () => {
  it("writes episode to memory/episodes/{taskId}.json", () => {
    const task = createTestTask();
    const episodePath = join(episodesDir, `${task.id}.json`);
    createdFiles.push(episodePath);

    const episode = writeTaskEpisode(task);

    expect(existsSync(episodePath)).toBe(true);
    expect(episode.taskId).toBe(task.id);
    expect(episode.employeeId).toBe(TEST_EMPLOYEE_ID);
    expect(episode.status).toBe("completed");
  });

  it("includes outputs in episode", () => {
    const task = createTestTask({
      outputs: [
        {
          id: "out-1",
          type: "document",
          title: "report.md",
          filePath: "/path/to/report.md",
          createdAt: new Date().toISOString(),
        },
        {
          id: "out-2",
          type: "website",
          title: "Preview",
          url: "http://localhost:3000",
          createdAt: new Date().toISOString(),
        },
      ],
    });
    const episodePath = join(episodesDir, `${task.id}.json`);
    createdFiles.push(episodePath);

    const episode = writeTaskEpisode(task);

    expect(episode.outputs).toHaveLength(2);
    expect(episode.outputs[0].title).toBe("report.md");
    expect(episode.outputs[1].title).toBe("Preview");
  });

  it("truncates long briefs", () => {
    const longBrief = "x".repeat(1000);
    const task = createTestTask({ brief: longBrief });
    const episodePath = join(episodesDir, `${task.id}.json`);
    createdFiles.push(episodePath);

    const episode = writeTaskEpisode(task);

    expect(episode.brief.length).toBeLessThanOrEqual(500);
  });

  it("handles failed status", () => {
    const task = createTestTask({
      status: "failed",
      errorMessage: "Something went wrong",
    });
    const episodePath = join(episodesDir, `${task.id}.json`);
    createdFiles.push(episodePath);

    const episode = writeTaskEpisode(task);

    expect(episode.status).toBe("failed");
  });
});

describe("updateEmployeeMemory", () => {
  it("creates MEMORY.md when it does not exist", () => {
    const task = createTestTask();
    const episodePath = join(episodesDir, `${task.id}.json`);
    createdFiles.push(episodePath);

    updateEmployeeMemory(task);

    expect(existsSync(memoryPath)).toBe(true);
    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("Working Memory");
    expect(content).toContain("Recent Tasks");
    expect(content).toContain("Test task brief");
  });

  it("adds new task to existing MEMORY.md", () => {
    // Create initial memory
    const task1 = createTestTask({ brief: "First task" });
    updateEmployeeMemory(task1);

    // Add second task
    const task2 = createTestTask({ brief: "Second task" });
    updateEmployeeMemory(task2);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("First task");
    expect(content).toContain("Second task");
  });

  it("keeps only last 10 tasks", () => {
    // Add 12 tasks with unique identifiers to avoid substring matching issues
    for (let i = 1; i <= 12; i++) {
      const task = createTestTask({ brief: `Task-ID-${String(i).padStart(3, "0")}` });
      updateEmployeeMemory(task);
    }

    const content = readFileSync(memoryPath, "utf-8");

    // Newest tasks should be present (tasks 3-12)
    expect(content).toContain("Task-ID-012");
    expect(content).toContain("Task-ID-011");
    expect(content).toContain("Task-ID-003");

    // Oldest tasks should be dropped (tasks 1-2)
    expect(content).not.toContain("Task-ID-001");
    expect(content).not.toContain("Task-ID-002");
  });

  it("preserves Notes section", () => {
    // Create MEMORY.md with Notes section
    const initialContent = `# test-memory-employee Working Memory

*Last updated: 2024-01-01T00:00:00.000Z*

## Recent Tasks

*No tasks completed yet.*

## Notes

User prefers dark mode.
Always use TypeScript.
`;
    writeFileSync(memoryPath, initialContent);

    // Add a task
    const task = createTestTask({ brief: "New task" });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("## Notes");
    expect(content).toContain("User prefers dark mode");
    expect(content).toContain("Always use TypeScript");
  });

  it("preserves Preferences section", () => {
    // Create MEMORY.md with Preferences section
    const initialContent = `# test-memory-employee Working Memory

*Last updated: 2024-01-01T00:00:00.000Z*

## Recent Tasks

*No tasks completed yet.*

## Preferences

- Concise responses
- Code comments in English
`;
    writeFileSync(memoryPath, initialContent);

    // Add a task
    const task = createTestTask({ brief: "New task" });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("## Preferences");
    expect(content).toContain("Concise responses");
    expect(content).toContain("Code comments in English");
  });

  it("includes status icon for completed tasks", () => {
    const task = createTestTask({ status: "completed" });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("[done]");
  });

  it("includes status icon for failed tasks", () => {
    const task = createTestTask({ status: "failed", errorMessage: "Error!" });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("[failed]");
    expect(content).toContain("Error:");
  });

  it("includes output names in task entry", () => {
    const task = createTestTask({
      outputs: [
        {
          id: "out-1",
          type: "document",
          title: "report.md",
          createdAt: new Date().toISOString(),
        },
        {
          id: "out-2",
          type: "image",
          title: "chart.png",
          createdAt: new Date().toISOString(),
        },
      ],
    });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("Outputs: report.md, chart.png");
  });
});

describe("summary extraction from activities", () => {
  it("uses brief when it is descriptive enough", () => {
    const task = createTestTask({
      brief: "Build a landing page with React",
      activities: [
        {
          id: "act-1",
          type: "text",
          message: "I'll create a landing page using React with modern styling.",
          timestamp: new Date().toISOString(),
        },
      ],
    });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("Build a landing page with React");
  });

  it("extracts summary from activities when brief is too short", () => {
    const task = createTestTask({
      brief: "hi",
      activities: [
        {
          id: "act-1",
          type: "text",
          message: "I'll help you build an interior design app with a modern landing page.",
          timestamp: new Date().toISOString(),
        },
      ],
    });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    // Should extract from activities, not use "hi"
    expect(content).toContain("interior design app");
    expect(content).not.toMatch(/### .* \[done\] hi$/m);
  });

  it("falls back to brief when activities have no useful text", () => {
    const task = createTestTask({
      brief: "yo",
      activities: [
        {
          id: "act-1",
          type: "toolCall",
          message: "Using read",
          timestamp: new Date().toISOString(),
        },
      ],
    });
    updateEmployeeMemory(task);

    const content = readFileSync(memoryPath, "utf-8");
    expect(content).toContain("[done] yo");
  });
});

describe("memory truncation", () => {
  it("truncates MEMORY.md when content exceeds limit", () => {
    // Create many tasks with long briefs to exceed 18K limit
    for (let i = 1; i <= 10; i++) {
      const longBrief = `Task ${i}: ${"x".repeat(2000)}`;
      const task = createTestTask({ brief: longBrief });
      updateEmployeeMemory(task);
    }

    const content = readFileSync(memoryPath, "utf-8");

    // Content should be under 18K + some margin for truncation message
    expect(content.length).toBeLessThan(20000);

    // Should still have header and recent tasks section
    expect(content).toContain("Working Memory");
    expect(content).toContain("## Recent Tasks");
  });
});
