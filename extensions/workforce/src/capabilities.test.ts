import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { existsSync, rmSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  updateCapabilities,
  readCapabilities,
  addAcquiredSkill,
  addDomainExperience,
} from "./capabilities.js";

const TEST_EMPLOYEE_ID = "test-cap-employee";
const workspaceDir = join(homedir(), ".openclaw", `workspace-${TEST_EMPLOYEE_ID}`);
const capPath = join(workspaceDir, "CAPABILITIES.md");

beforeEach(() => {
  mkdirSync(workspaceDir, { recursive: true });
  // Clean up any existing CAPABILITIES.md
  if (existsSync(capPath)) {
    rmSync(capPath);
  }
});

afterEach(() => {
  try {
    if (existsSync(capPath)) {
      rmSync(capPath);
    }
  } catch { /* ignore */ }
});

describe("updateCapabilities", () => {
  it("creates new file", () => {
    updateCapabilities(TEST_EMPLOYEE_ID, {
      role: "Data Analyst",
      preInstalledSkills: ["anthropics/skills@pptx"],
    });

    expect(existsSync(capPath)).toBe(true);
    const content = readFileSync(capPath, "utf-8");
    expect(content).toContain("Data Analyst");
    expect(content).toContain("anthropics/skills@pptx");
  });

  it("preserves existing data on update", () => {
    updateCapabilities(TEST_EMPLOYEE_ID, {
      role: "Engineer",
      preInstalledSkills: ["skill-a"],
    });

    updateCapabilities(TEST_EMPLOYEE_ID, {
      preInstalledSkills: ["skill-b"],
    });

    const sections = readCapabilities(TEST_EMPLOYEE_ID);
    expect(sections.role).toBe("Engineer");
    expect(sections.preInstalledSkills).toContain("skill-a");
    expect(sections.preInstalledSkills).toContain("skill-b");
  });
});

describe("addAcquiredSkill", () => {
  it("appends to section", () => {
    updateCapabilities(TEST_EMPLOYEE_ID, { role: "Test" });

    addAcquiredSkill(TEST_EMPLOYEE_ID, "anthropics/skills@xlsx", "needed for report task");

    const sections = readCapabilities(TEST_EMPLOYEE_ID);
    expect(sections.acquiredSkills).toHaveLength(1);
    expect(sections.acquiredSkills[0].skillId).toBe("anthropics/skills@xlsx");
    expect(sections.acquiredSkills[0].context).toBe("needed for report task");
  });

  it("deduplicates", () => {
    updateCapabilities(TEST_EMPLOYEE_ID, { role: "Test" });

    addAcquiredSkill(TEST_EMPLOYEE_ID, "anthropics/skills@xlsx");
    addAcquiredSkill(TEST_EMPLOYEE_ID, "anthropics/skills@xlsx");

    const sections = readCapabilities(TEST_EMPLOYEE_ID);
    expect(sections.acquiredSkills).toHaveLength(1);
  });
});

describe("addDomainExperience", () => {
  it("increments count", () => {
    updateCapabilities(TEST_EMPLOYEE_ID, { role: "Test" });

    addDomainExperience(TEST_EMPLOYEE_ID, "presentations");
    addDomainExperience(TEST_EMPLOYEE_ID, "presentations");

    const sections = readCapabilities(TEST_EMPLOYEE_ID);
    expect(sections.domainExperience.get("presentations")).toBe(2);
  });
});

describe("readCapabilities", () => {
  it("parses all sections", () => {
    updateCapabilities(TEST_EMPLOYEE_ID, {
      role: "Senior Engineer",
      preInstalledSkills: ["skill-1", "skill-2"],
    });

    addAcquiredSkill(TEST_EMPLOYEE_ID, "skill-3", "for testing");
    addDomainExperience(TEST_EMPLOYEE_ID, "web development");

    const sections = readCapabilities(TEST_EMPLOYEE_ID);
    expect(sections.role).toBe("Senior Engineer");
    expect(sections.preInstalledSkills).toEqual(["skill-1", "skill-2"]);
    expect(sections.acquiredSkills).toHaveLength(1);
    expect(sections.domainExperience.get("web development")).toBe(1);
  });

  it("returns empty for nonexistent employee", () => {
    const sections = readCapabilities("nonexistent-cap-employee");
    expect(sections.role).toBe("");
    expect(sections.preInstalledSkills).toEqual([]);
    expect(sections.acquiredSkills).toEqual([]);
  });
});
