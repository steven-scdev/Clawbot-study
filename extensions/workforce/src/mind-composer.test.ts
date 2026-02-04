import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";
import { composeMind, readMindFile } from "./mind-composer.js";

let tmpDir: string;

beforeEach(() => {
  tmpDir = mkdtempSync(join(tmpdir(), "mind-test-"));
});

afterEach(() => {
  rmSync(tmpDir, { recursive: true, force: true });
});

describe("readMindFile", () => {
  it("returns null for nonexistent file", () => {
    expect(readMindFile(tmpDir, "missing.md")).toBeNull();
  });

  it("returns trimmed file content", () => {
    writeFileSync(join(tmpDir, "test.md"), "  hello world  \n\n");
    expect(readMindFile(tmpDir, "test.md")).toBe("hello world");
  });
});

describe("composeMind", () => {
  it("returns empty string when directory missing", () => {
    expect(composeMind("nonexistent", tmpDir)).toBe("");
  });

  it("returns empty string when directory exists but has no mind files", () => {
    mkdirSync(join(tmpDir, "empty-emp"));
    expect(composeMind("empty-emp", tmpDir)).toBe("");
  });

  it("returns composed content with all sections", () => {
    const empDir = join(tmpDir, "test-emp");
    mkdirSync(empDir);
    writeFileSync(join(empDir, "lens.md"), "I see problems as design challenges.");
    writeFileSync(join(empDir, "standards.md"), "Quality means clarity.");
    writeFileSync(join(empDir, "principles.md"), "Ask before assuming.");

    const result = composeMind("test-emp", tmpDir);
    expect(result).toContain("I see problems as design challenges.");
    expect(result).toContain("Quality means clarity.");
    expect(result).toContain("Ask before assuming.");
  });

  it("handles partial mind files", () => {
    const empDir = join(tmpDir, "partial-emp");
    mkdirSync(empDir);
    writeFileSync(join(empDir, "lens.md"), "Only lens content.");

    const result = composeMind("partial-emp", tmpDir);
    expect(result).toContain("Only lens content.");
    expect(result).toContain("## How You See Your Work");
    expect(result).not.toContain("## Your Quality Standards");
    expect(result).not.toContain("## Your Working Principles");
  });

  it("includes correct section headings", () => {
    const empDir = join(tmpDir, "heading-emp");
    mkdirSync(empDir);
    writeFileSync(join(empDir, "lens.md"), "lens");
    writeFileSync(join(empDir, "standards.md"), "standards");
    writeFileSync(join(empDir, "principles.md"), "principles");

    const result = composeMind("heading-emp", tmpDir);
    expect(result).toContain("# Your Professional Identity");
    expect(result).toContain("## How You See Your Work");
    expect(result).toContain("## Your Quality Standards");
    expect(result).toContain("## Your Working Principles");
  });
});
