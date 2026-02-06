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

  // Add browser control guidance so employees know how to control the preview WebView
  sections.push(buildBrowserControlGuidance());

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

/**
 * Build the browser control guidance that teaches employees how to control
 * the preview panel's WebView with full JavaScript execution capability.
 */
function buildBrowserControlGuidance(): string {
  return `
## Browser Control in Preview Panel

You have **full JavaScript execution capability** in the preview panel's WebView. Use the \`webview\` tool (NOT the external \`browser\` tool) to control the embedded browser programmatically.

**IMPORTANT:** The \`webview\` tool controls the browser embedded in the Workforce app. No Chrome extension needed. Do NOT ask users to connect browser extensions.

**Three primitives ("meta-keys"):**
1. **execute** — Run arbitrary JavaScript in the WebView
2. **observe** — Capture current state (DOM, screenshot, URL, title)
3. **navigate** — Load a URL

**Examples:**
\`\`\`
// Navigate to a website
webview(action="navigate", url="https://example.com")

// Click a button
webview(action="execute", script="document.querySelector('button.submit').click()")

// Fill a form field
webview(action="execute", script="document.querySelector('input[name=email]').value = 'user@example.com'")

// Get the current page state
webview(action="observe")  // Returns { dom, screenshot, url, title }

// Extract data from the page
webview(action="execute", script="document.querySelector('.price').textContent")

// Scroll to an element
webview(action="execute", script="document.querySelector('#section2').scrollIntoView()")

// Submit a form
webview(action="execute", script="document.querySelector('form').submit()")
\`\`\`

**When to use the webview tool:**
- When the user asks you to interact with a website (click, fill forms, navigate)
- When you need to extract data from a web page
- When automating multi-step web workflows (login, search, submit)
- When testing web applications or checking page states

**Key principles:**
- You have **full JavaScript execution** — any JavaScript that works in a browser console works here
- Use \`observe\` to "see" what's on the page (DOM gives you structure, screenshot gives you visual)
- Chain operations: navigate → observe → execute → observe → ...
- For complex interactions, break them into small, sequential steps
- The screenshot is base64 PNG — you can analyze it to understand the visual state
- **Never ask users to install or connect Chrome extensions** — the webview tool works directly

**This is NOT for showing outputs** — use the \`preview\` tool to display files and URLs to the user. Use \`webview\` when you need to interact with or automate web content.
`;
}
