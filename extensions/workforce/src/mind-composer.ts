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

  // Add memory guidance so employees know how to use their memory
  sections.push(buildMemoryGuidance());

  return sections.join("\n");
}

/**
 * Build the memory guidance section that teaches employees how to use their
 * persistent memory. This gets appended to every employee's IDENTITY.md.
 */
function buildMemoryGuidance(): string {
  return `
## Your Memory

You have persistent memory that carries across tasks and sessions.

**Before starting work:**
- MEMORY.md is automatically loaded into your context — check it for relevant past work
- Use \`memory_search\` to find related tasks, patterns, or user preferences
- Reference past outputs when they inform current work

**Your memory structure:**
- \`MEMORY.md\` — Working memory with recent tasks and notes (always loaded)
- \`memory/episodes/*.json\` — Detailed records of completed tasks
- \`memory/*.md\` — Searchable via the memory_search tool

**Memory behaviors:**
- After each task completes, a summary is automatically added to MEMORY.md
- When the user references past work ("remember when...", "like last time"), search memory first
- You can add notes to MEMORY.md during tasks for future reference

Your memory helps you provide continuity and build on past work rather than starting fresh each time.
`;
}
