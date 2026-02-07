import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { existsSync, rmSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { trackSkillEvent, readSkillLog } from "./skill-tracker.js";

const TEST_EMPLOYEE_ID = "test-skill-employee";
const workspaceDir = join(homedir(), ".openclaw", `workspace-${TEST_EMPLOYEE_ID}`);
const skillDir = join(workspaceDir, "skill-usage");

beforeEach(() => {
  mkdirSync(workspaceDir, { recursive: true });
});

afterEach(() => {
  try {
    if (existsSync(skillDir)) {
      rmSync(skillDir, { recursive: true });
    }
  } catch { /* ignore */ }
});

describe("trackSkillEvent", () => {
  it("appends to JSONL", () => {
    trackSkillEvent(TEST_EMPLOYEE_ID, {
      skillId: "anthropics/skills@pptx",
      action: "search",
      query: "pptx creation",
      success: true,
    });

    trackSkillEvent(TEST_EMPLOYEE_ID, {
      skillId: "anthropics/skills@xlsx",
      action: "install",
      success: true,
    });

    const records = readSkillLog(TEST_EMPLOYEE_ID);
    expect(records).toHaveLength(2);
  });

  it("creates dir if missing", () => {
    // Ensure dir doesn't exist
    if (existsSync(skillDir)) {
      rmSync(skillDir, { recursive: true });
    }

    trackSkillEvent(TEST_EMPLOYEE_ID, {
      skillId: "anthropics/skills@pdf",
      action: "use",
      success: true,
    });

    expect(existsSync(skillDir)).toBe(true);
  });
});

describe("readSkillLog", () => {
  it("parses all entries", () => {
    trackSkillEvent(TEST_EMPLOYEE_ID, {
      skillId: "skill-a",
      action: "search",
      query: "find something",
      success: true,
    });

    trackSkillEvent(TEST_EMPLOYEE_ID, {
      skillId: "skill-b",
      action: "install",
      success: true,
    });

    const records = readSkillLog(TEST_EMPLOYEE_ID);
    expect(records).toHaveLength(2);
    // Newest first
    expect(records[0].skillId).toBe("skill-b");
    expect(records[1].skillId).toBe("skill-a");
    expect(records[0].employeeId).toBe(TEST_EMPLOYEE_ID);
    expect(records[0].timestamp).toBeTruthy();
  });

  it("respects limit", () => {
    trackSkillEvent(TEST_EMPLOYEE_ID, { skillId: "a", action: "search", success: true });
    trackSkillEvent(TEST_EMPLOYEE_ID, { skillId: "b", action: "search", success: true });
    trackSkillEvent(TEST_EMPLOYEE_ID, { skillId: "c", action: "search", success: true });

    const records = readSkillLog(TEST_EMPLOYEE_ID, { limit: 1 });
    expect(records).toHaveLength(1);
    expect(records[0].skillId).toBe("c");
  });

  it("filters by action", () => {
    trackSkillEvent(TEST_EMPLOYEE_ID, { skillId: "a", action: "search", success: true });
    trackSkillEvent(TEST_EMPLOYEE_ID, { skillId: "b", action: "install", success: true });
    trackSkillEvent(TEST_EMPLOYEE_ID, { skillId: "c", action: "search", success: true });

    const records = readSkillLog(TEST_EMPLOYEE_ID, { action: "install" });
    expect(records).toHaveLength(1);
    expect(records[0].skillId).toBe("b");
  });

  it("returns empty for nonexistent employee", () => {
    const records = readSkillLog("nonexistent-employee");
    expect(records).toEqual([]);
  });
});
