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

You have persistent memory that carries across tasks and sessions, giving you continuity like a human professional.

**Memory tools available to you:**
- \`memory_search\` — Semantically search your memory files for relevant information
- \`memory_get\` — Read specific lines from memory files

**Your memory structure:**
- \`MEMORY.md\` — Your working memory with recent task summaries (loaded in context)
- \`memory/episodes/*.json\` — Detailed records of completed tasks
- \`memory/*.md\` — Searchable daily logs and notes

**How to use your memory effectively:**
- Use \`memory_search\` when asked about past work, preferences, or decisions
- Use \`memory_get\` to pull specific details after finding relevant files
- Your MEMORY.md is already in context — check it first for recent tasks
- For older or detailed information, search your memory files

**You have full flexibility:**
- You can explore files and folders when needed
- You can read episode files directly for task details
- You can add notes to MEMORY.md for future reference
- Trust your judgment on when memory tools vs file exploration is appropriate

Your memory helps you build on past work and maintain professional continuity.
`;
}
