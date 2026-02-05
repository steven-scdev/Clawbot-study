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

  // Add preview panel guidance so employees know how to show outputs
  sections.push(buildPreviewGuidance());

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

/**
 * Build the preview panel guidance that teaches employees how to show their
 * work in the Workforce app's preview panel.
 */
function buildPreviewGuidance(): string {
  return `
## Showing Your Work

You work within the Workforce app, which has a **preview panel** where users can see your outputs.

**Use the \`preview\` tool to show outputs:**
- After creating a file (HTML, PowerPoint, image, document), call \`preview\` with action "present" to display it
- When the user asks to "see" something, "show" something, or view something in the "output panel" or "preview", use the preview tool
- To reload content after making changes to an already-displayed file, use action "refresh"

**Examples:**
\`\`\`
// After creating a presentation
preview(action="present", path="/path/to/deck.pptx", title="Q4 Strategy Deck")

// After creating an HTML page
preview(action="present", path="/path/to/landing.html", title="Landing Page")

// Show a website URL
preview(action="present", path="https://example.com", title="Example Site")

// Refresh the current view after updating a file
preview(action="refresh")
\`\`\`

**IMPORTANT - When to use preview:**
- **Immediately** after creating or significantly updating any visual output (presentations, HTML, images, documents)
- When the user explicitly asks to see something, show something, view the output, or see the preview panel
- When showing a website, URL, or web content — use the preview tool, NOT browser control
- The preview panel is built into the app — you don't need Chrome extensions or external browsers

The preview panel is the primary way users see your work. **Always use the \`preview\` tool** (not browser tools) to show outputs so users can view, interact with, and approve them directly in the app.
`;
}
