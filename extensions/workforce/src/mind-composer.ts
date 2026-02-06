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

// Refresh the current view after updating a file
preview(action="refresh")
\`\`\`

**IMPORTANT - When to use preview vs webview:**
- Use \`preview\` for **files you created** (presentations, HTML, images, documents)
- Use \`webview(action="navigate")\` for **websites you need to interact with** (login, click, fill forms, scrape data)
- The preview panel is built into the app — you don't need Chrome extensions or external browsers

**For browser automation tasks** (interacting with websites):
- Do NOT use \`preview\` — it cannot interact with pages
- Use \`webview(action="navigate", url="...")\` instead — this opens a real Chromium browser you can control
- See "Browser Control" section below for how to interact with the page after navigating
`;
}

/**
 * Build the browser control guidance that teaches employees how to control
 * the embedded browser in the preview panel using the standard browser() tool.
 */
function buildBrowserControlGuidance(): string {
  return `
## Browser Control in Preview Panel

**For any task that requires interacting with a website** (login, click buttons, fill forms, scrape data), use the embedded browser:

**Step 1: Open the embedded browser with webview:**
\`\`\`
webview(action="navigate", url="https://x.com")
// Returns: { targetId: "abc123", profile: "openclaw" }
\`\`\`
This opens a real Chromium browser in the preview panel that you can control.

**Step 2: Control the browser with the browser tool:**
Use the \`targetId\` and \`profile\` from Step 1 for all subsequent browser operations.

**Key actions:**

1. **snapshot** — See the page structure (accessibility tree with refs)
\`\`\`
browser(action="snapshot", targetId="<id>", profile="openclaw")
// Returns: { snapshot: "- button 'Submit' [ref=e1]\\n- textbox 'Email' [ref=e2]...", refs: {...} }
\`\`\`

2. **act** — Interact with elements using stable refs
\`\`\`
// Click an element
browser(action="act", kind="click", ref="e1", targetId="<id>", profile="openclaw")

// Type text into an input
browser(action="act", kind="type", text="hello@example.com", ref="e2", targetId="<id>", profile="openclaw")

// Press a key
browser(action="act", kind="press", key="Enter", targetId="<id>", profile="openclaw")

// Fill a form field (faster than type)
browser(action="act", kind="fill", value="mypassword", ref="e3", targetId="<id>", profile="openclaw")
\`\`\`

3. **navigate** — Go to a URL
\`\`\`
browser(action="navigate", url="https://example.com", targetId="<id>", profile="openclaw")
\`\`\`

4. **screenshot** — Take a screenshot (returns file path, not inline data)
\`\`\`
browser(action="screenshot", targetId="<id>", profile="openclaw")
// Returns: { path: "/tmp/screenshot-xxx.jpeg" }
\`\`\`

**Complete workflow:**
1. \`webview(action="navigate", url="...")\` → get targetId from response
2. \`browser(action="snapshot", targetId=X, profile="openclaw")\` → see the page structure
3. Find the element you need by its ref (e.g., \`[ref=e3]\`)
4. \`browser(action="act", kind="click", ref="e3", targetId=X, profile="openclaw")\` → interact
5. \`browser(action="snapshot", ...)\` again to see the result
6. Repeat steps 3-5 as needed

**Why refs instead of selectors:**
- Refs like \`e1\`, \`e2\`, \`e3\` are stable — they survive page updates
- The accessibility tree shows element roles: \`button "Submit" [ref=e1]\`
- You interact using refs, not CSS selectors or coordinates

**Key principles:**
- Always call \`snapshot\` first to see what's on the page
- Use the returned refs to interact with elements
- Chain operations: navigate → snapshot → act → snapshot → ...
- The accessibility tree tells you element types (button, link, textbox, etc.)
- **Never ask users to install Chrome extensions** — the embedded browser works directly

**When to use browser control vs preview:**
- Use \`webview\` + \`browser\` when you need to **interact** with a website (click, type, scrape)
- Use \`preview\` when you just need to **show** a file you created (presentations, HTML, documents)
`;
}
