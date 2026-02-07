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

  // Add reference documents guidance
  sections.push(buildReferencesGuidance());

  // Add skills guidance
  sections.push(buildSkillsGuidance());

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

// After creating an Excel spreadsheet
preview(action="present", path="/path/to/report.xlsx", title="Sales Report")

// Refresh the current view after updating a file
preview(action="refresh")
\`\`\`

**IMPORTANT - When to use preview vs webview:**
- Use \`preview\` for **non-web files** (presentations, spreadsheets, PDFs, images, documents)
- Use \`webview(action="navigate")\` for **anything web/HTML** — websites, web apps, HTML files you built, landing pages, dashboards, etc.
- The preview panel is built into the app — you don't need Chrome extensions or external browsers

**Why use webview for websites you build:**
- \`preview\` renders in a static panel — the user **cannot click, scroll, or interact** with the page
- \`webview\` opens a real Chromium browser where the user can **fully interact** with the website (click links, fill forms, navigate)
- Always use \`webview\` when the output is a website or web app, even if you created the HTML files yourself

**For websites/web apps you build:**
\`\`\`
// Serve the site first (e.g. via a local dev server), then show it in the embedded browser
webview(action="navigate", url="http://localhost:3000")

// Or for a static HTML file — use file:// URL with webview, NOT preview
webview(action="navigate", url="file:///path/to/index.html")
\`\`\`

**For browser automation tasks** (interacting with external websites):
- Use \`webview(action="navigate", url="...")\` — this opens a real Chromium browser you can control
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
- Use \`webview\` for **all web content** — websites you build, web apps, HTML pages, and sites you need to interact with
- Use \`preview\` only for **non-web files** — presentations (pptx), spreadsheets (xlsx), PDFs, images
- If the user asked you to build a website or web app, always show it via \`webview(action="navigate")\` so they can interact with it
`;
}

/**
 * Build the reference documents guidance that teaches employees how to use
 * user-provided reference files for context and learning.
 */
function buildReferencesGuidance(): string {
  return `
## Reference Documents

Users can attach reference documents to teach you their preferences, styles, and requirements.

**What reference documents are:**
- Example files (PPTs, PDFs, templates) that show "make it like this"
- Style guides, brand documents, or design templates
- Previous work that should inform your approach

**Your reference storage:**
- References are stored in your workspace under \`references/\`
- Each reference has metadata (JSON) and the original file in \`references/originals/\`
- A digest summary of each reference is included in your context

**How to use references effectively:**
- Check your reference documents before starting a task — they show what the user expects
- Match the style, tone, layout, and structure of reference templates
- When creating presentations, use reference PPTs as style guides
- When writing documents, match the voice and formatting of reference docs
- If a reference is a template, follow its structure closely

**You have full access:**
- Read original files from \`references/originals/\` when you need details
- The digest in your context gives you a quick overview of each reference
- Multiple references may apply — synthesize their patterns
`;
}

/**
 * Build the skills guidance that teaches employees about the skill system:
 * pre-installed skills, dynamic discovery, and skill management.
 */
function buildSkillsGuidance(): string {
  return `
## Skills

You have pre-installed skills based on your role (listed in your CAPABILITIES.md).
These are ready to use immediately.

External skill installation is currently disabled for security.
Do not attempt to search for or install skills from external sources.
Work with your pre-installed skills and built-in capabilities.
`;
  // --- Original skills guidance (commented out for security) ---
  // return `
  // ## Skills System
  //
  // You have access to a marketplace of professional skills that extend your capabilities.
  //
  // **Pre-installed skills:**
  // - Some skills come pre-installed based on your role (check your CAPABILITIES.md)
  // - These are ready to use immediately without installation
  //
  // **Discovering new skills:**
  // - When you encounter a task that needs capabilities beyond your current skills, search for relevant skills
  // - Use the gateway method \`workforce.skills.search\` with a query to find available skills
  // - Example: if asked to create an Excel report but you don't have xlsx skills, search for "xlsx"
  //
  // **Installing skills:**
  // - Use \`workforce.skills.install\` with the skill ID to install a new skill
  // - Skills are installed globally and persist across tasks
  // - Always check what's installed first before searching — avoid redundant installs
  //
  // **Best practices:**
  // - Check your installed skills before starting a task
  // - Only search for new skills when there's a genuine capability gap
  // - After installing a skill, use it immediately — don't install skills "just in case"
  // - Skills you acquire are tracked and appear in your CAPABILITIES.md
  // `;
}
