import { readFileSync, existsSync } from "fs";
import { join } from "path";

/**
 * Read a single mind file from the employee's mind directory.
 * Returns null if the file doesn't exist.
 */
export function readMindFile(dir: string, filename: string): string | null {
  const filePath = join(dir, filename);
  if (!existsSync(filePath)) return null;
  return readFileSync(filePath, "utf-8").trim();
}

/**
 * Load and compose an employee's mind into a single prompt string.
 *
 * Reads lens.md, standards.md, and principles.md from {mindsDir}/{employeeId}/
 * and composes them into a structured prompt section. Returns empty string if
 * no mind files exist — the employee runs as a generic agent (graceful fallback).
 */
export function composeMind(employeeId: string, mindsDir: string): string {
  const mindDir = join(mindsDir, employeeId);

  const lens = readMindFile(mindDir, "lens.md");
  const standards = readMindFile(mindDir, "standards.md");
  const principles = readMindFile(mindDir, "principles.md");

  if (!lens && !standards && !principles) {
    return "";
  }

  const sections: string[] = [];
  sections.push("# Your Professional Identity\n");

  if (lens) {
    sections.push("## How You See Your Work\n", lens, "");
  }
  if (standards) {
    sections.push("## Your Quality Standards\n", standards, "");
  }
  if (principles) {
    sections.push("## Your Working Principles\n", principles, "");
  }

  return sections.join("\n");
}
