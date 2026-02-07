import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { existsSync, readFileSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import {
  addReference,
  listReferences,
  getReference,
  removeReference,
  formatReferencesForPrompt,
} from "./reference-store.js";

const TEST_EMPLOYEE_ID = "test-ref-employee";
const workspaceDir = join(homedir(), ".openclaw", `workspace-${TEST_EMPLOYEE_ID}`);
const refsDir = join(workspaceDir, "references");
const originalsDir = join(refsDir, "originals");

// Create a temp source file to use as a reference
const tmpDir = join(workspaceDir, "_test-tmp");
const tmpFile = join(tmpDir, "sample.pptx");

beforeEach(() => {
  mkdirSync(tmpDir, { recursive: true });
  writeFileSync(tmpFile, "fake pptx content for testing");
});

afterEach(() => {
  // Clean up all test artifacts
  try {
    if (existsSync(refsDir)) {
      rmSync(refsDir, { recursive: true });
    }
  } catch { /* ignore */ }
  try {
    if (existsSync(tmpDir)) {
      rmSync(tmpDir, { recursive: true });
    }
  } catch { /* ignore */ }
});

describe("addReference", () => {
  it("stores file and metadata", () => {
    const doc = addReference(TEST_EMPLOYEE_ID, tmpFile);

    expect(doc.id).toMatch(/^ref-/);
    expect(doc.originalName).toBe("sample.pptx");
    expect(doc.addedVia).toBe("chat");
    expect(doc.type).toBe("reference");
    expect(doc.fileSize).toBeGreaterThan(0);
    expect(doc.digest).toContain("PPTX");
    expect(doc.digest).toContain("sample.pptx");

    // Metadata JSON should exist
    const metadataPath = join(refsDir, `${doc.id}.json`);
    expect(existsSync(metadataPath)).toBe(true);

    // Original file should be copied
    const origPath = join(originalsDir, `${doc.id}.pptx`);
    expect(existsSync(origPath)).toBe(true);
    expect(readFileSync(origPath, "utf-8")).toBe("fake pptx content for testing");
  });

  it("generates unique IDs", () => {
    const doc1 = addReference(TEST_EMPLOYEE_ID, tmpFile);
    const doc2 = addReference(TEST_EMPLOYEE_ID, tmpFile);

    expect(doc1.id).not.toBe(doc2.id);
  });
});

describe("listReferences", () => {
  it("returns all references sorted by addedAt DESC", async () => {
    const doc1 = addReference(TEST_EMPLOYEE_ID, tmpFile, { tags: ["first"] });
    // Small delay to ensure different timestamps
    await new Promise((r) => setTimeout(r, 10));
    const doc2 = addReference(TEST_EMPLOYEE_ID, tmpFile, { tags: ["second"] });
    await new Promise((r) => setTimeout(r, 10));
    const doc3 = addReference(TEST_EMPLOYEE_ID, tmpFile, { tags: ["third"] });

    const refs = listReferences(TEST_EMPLOYEE_ID);

    expect(refs).toHaveLength(3);
    // Most recent first
    expect(refs[0].id).toBe(doc3.id);
    expect(refs[1].id).toBe(doc2.id);
    expect(refs[2].id).toBe(doc1.id);
  });

  it("returns empty array when no references", () => {
    const refs = listReferences("nonexistent-employee");
    expect(refs).toEqual([]);
  });
});

describe("getReference", () => {
  it("returns single by ID", () => {
    const doc = addReference(TEST_EMPLOYEE_ID, tmpFile, { type: "template" });
    const fetched = getReference(TEST_EMPLOYEE_ID, doc.id);

    expect(fetched).not.toBeNull();
    expect(fetched!.id).toBe(doc.id);
    expect(fetched!.type).toBe("template");
    expect(fetched!.originalName).toBe("sample.pptx");
  });

  it("returns null for unknown ID", () => {
    const fetched = getReference(TEST_EMPLOYEE_ID, "ref-nonexistent");
    expect(fetched).toBeNull();
  });
});

describe("removeReference", () => {
  it("deletes both metadata and original file", () => {
    const doc = addReference(TEST_EMPLOYEE_ID, tmpFile);
    const metadataPath = join(refsDir, `${doc.id}.json`);
    const origPath = join(originalsDir, `${doc.id}.pptx`);

    expect(existsSync(metadataPath)).toBe(true);
    expect(existsSync(origPath)).toBe(true);

    const result = removeReference(TEST_EMPLOYEE_ID, doc.id);

    expect(result).toBe(true);
    expect(existsSync(metadataPath)).toBe(false);
    expect(existsSync(origPath)).toBe(false);
  });

  it("returns false for unknown ID", () => {
    const result = removeReference(TEST_EMPLOYEE_ID, "ref-nonexistent");
    expect(result).toBe(false);
  });
});

describe("formatReferencesForPrompt", () => {
  it("builds markdown with digest text", () => {
    addReference(TEST_EMPLOYEE_ID, tmpFile, { type: "template", tags: ["design"] });

    const prompt = formatReferencesForPrompt(TEST_EMPLOYEE_ID);

    expect(prompt).toContain("## Reference Documents");
    expect(prompt).toContain("sample.pptx");
    expect(prompt).toContain("template");
    expect(prompt).toContain("PPTX");
    expect(prompt).toContain("[design]");
  });

  it("returns empty string for no references", () => {
    const prompt = formatReferencesForPrompt("nonexistent-employee");
    expect(prompt).toBe("");
  });
});
