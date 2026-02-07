import { describe, it, expect, beforeEach, afterEach, vi } from "vitest";
import { existsSync, rmSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { skillSearch, skillInstall, skillList } from "./skill-tools.js";
import { trackSkillEvent } from "./skill-tracker.js";

const TEST_EMPLOYEE_ID = "test-skilltools-employee";
const workspaceDir = join(homedir(), ".openclaw", `workspace-${TEST_EMPLOYEE_ID}`);
const skillDir = join(workspaceDir, "skill-usage");

const mockLogger = {
  info: vi.fn(),
  error: vi.fn(),
};

const ctx = {
  employeeId: TEST_EMPLOYEE_ID,
  taskId: "test-task-1",
  logger: mockLogger,
};

beforeEach(() => {
  mkdirSync(skillDir, { recursive: true });
  vi.clearAllMocks();
});

afterEach(() => {
  try {
    if (existsSync(skillDir)) {
      rmSync(skillDir, { recursive: true });
    }
  } catch { /* ignore */ }
});

describe("skillSearch", () => {
  it("returns array without throwing", () => {
    // npx skills may not be installed; either way, result should be an array
    const results = skillSearch(ctx, "nonexistent-skill-xyz");
    expect(Array.isArray(results)).toBe(true);
    // Either info (success with 0 results) or error (CLI failure) is called
    const called = mockLogger.info.mock.calls.length + mockLogger.error.mock.calls.length;
    expect(called).toBeGreaterThanOrEqual(1);
  });
});

describe("skillInstall", () => {
  it("returns failure result on CLI failure without throwing", () => {
    const result = skillInstall(ctx, "nonexistent/skill@xyz");
    expect(result.success).toBe(false);
    expect(result.message).toBeTruthy();
    expect(mockLogger.error).toHaveBeenCalled();
  });
});

describe("skillList", () => {
  it("returns empty array for fresh employee", () => {
    const skills = skillList(ctx);
    expect(Array.isArray(skills)).toBe(true);
    expect(skills).toHaveLength(0);
  });

  it("tracks installed skills from usage log", () => {
    // Manually track an install event
    trackSkillEvent(TEST_EMPLOYEE_ID, {
      skillId: "anthropics/skills@pptx",
      action: "install",
      success: true,
    });

    const skills = skillList(ctx);
    expect(skills).toContain("anthropics/skills@pptx");
  });
});
