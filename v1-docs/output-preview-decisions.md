# Output Preview — Architecture Decisions

> Captures the reasoning behind every major design choice for the output preview feature. Reference this document when making implementation trade-offs or revisiting decisions.

---

## Problem Statement

### Current State

When an AI employee completes work (builds a website, writes a report, creates a spreadsheet), the Workforce app shows only:

- A list of file names with type icons
- "Open" button (launches external app)
- "Show in Finder" button (reveals in Finder)

The user never sees the actual output content inside the app. They must leave the app to inspect results.

### Goal

Show a native, interactive preview of any output type directly in the app — alongside the ongoing chat conversation — so the user can see work as it happens, provide feedback inline, and approve results without leaving the Workforce experience.

### Visual References

- `ui/webview-screen.png` — Live website preview during execution (WKWebView with localhost URL)
- `ui/assetview-screen.png` — Multiple generated assets after completion (document + chart stacked)

---

## Decision 1: Split-Pane Layout

### What

The task view becomes a **two-column layout**: chat conversation on the left, artifact preview pane on the right.

```
+-------------------------+---------------------------+
|   Chat Pane             |   Artifact Pane           |
|                         |                           |
|   [Chat bubbles]        |   [Generated Assets]      |
|   [Thinking stream]     |   [Preview card 1]        |
|                         |   [Preview card 2]        |
|                         |                           |
|   [Type a message...]   |   [Approve All Assets]    |
+-------------------------+---------------------------+
```

### Why (not inline chat cards)

We considered rendering output previews as inline cards within the chat scroll (similar to how ChatGPT shows code blocks). This was rejected because:

1. **Artifacts scroll away** — As the conversation continues, the preview disappears off-screen. Users must scroll back to find it.
2. **Limited real estate** — A chat bubble is ~50-60% of the window width. A website preview or slide deck needs dedicated space to be useful.
3. **Persistent visibility** — The artifact pane stays visible while the user types feedback or reads the agent's messages. The chat and preview are always side by side.
4. **Multiple artifacts** — When an agent produces several outputs (a document + a chart, as shown in `assetview-screen.png`), they stack cleanly in the artifact pane without cluttering the chat.

### When the artifact pane is hidden

When a task has no outputs yet (during briefing, clarification, or early execution), the chat takes the full width — same as today. The artifact pane slides in with animation when the first output is detected.

---

## Decision 2: Two Rendering Surfaces

### What

All output previews are handled by exactly two rendering components:

| Rendering Surface | Technology | Covers |
|---|---|---|
| **WKWebView** | Apple WebKit (embedded browser) | Live websites, localhost URLs, HTML content, HTML-based visualizations |
| **QLPreviewView** | Apple QuickLook | Every native file format: .pptx, .xlsx, .pdf, .docx, .png, .mp4, .key, and hundreds more |

### Why two (not one)

- **WKWebView** can load URLs and render web content, but it cannot natively preview `.pptx`, `.xlsx`, or other Office formats without conversion.
- **QLPreviewView** can preview virtually any file format macOS supports (it's the same engine behind Finder's spacebar preview), but it cannot load live localhost URLs or render dynamic web applications.

Together, they cover 100% of output types with zero custom renderers.

### Why not per-type custom Swift views

We considered building dedicated Swift views for each content type (a slide gallery component, a spreadsheet viewer, a PDF annotator, etc.). This was rejected because:

1. **Maintenance burden** — Each new output type requires a new Swift component.
2. **Reinventing the wheel** — macOS already has world-class rendering for all these formats via QuickLook.
3. **Quality gap** — A custom slide renderer will never match Keynote's fidelity; a custom spreadsheet viewer will never match Numbers.
4. **Extensibility** — When a new employee type produces a new file format (3D models, CAD files, etc.), QLPreviewView handles it automatically via system plugins. Zero code changes.

### Coverage Table

| Format | Renderer | Quality |
|---|---|---|
| Live website (localhost URL) | WKWebView | Perfect — it's a browser |
| HTML content / visualizations | WKWebView | Perfect |
| .pdf | QLPreviewView | Native PDF rendering with pages |
| .pptx / .key | QLPreviewView | Full slide rendering with navigation |
| .xlsx / .csv / .numbers | QLPreviewView | Spreadsheet with tabs |
| .docx / .rtf | QLPreviewView | Formatted document |
| .png / .jpg / .svg / .gif | QLPreviewView | Image with zoom |
| .mp4 / .mov / .webm | QLPreviewView | Video with playback controls |
| .mp3 / .wav / .aac | QLPreviewView | Audio player |
| .md / .txt | QLPreviewView (or rendered markdown) | Plain text; may use custom markdown renderer for richer formatting |
| .swift / .ts / .py (code) | QLPreviewView | Syntax-highlighted code |
| 3D models, CAD, etc. | QLPreviewView | Via system QuickLook plugins |

---

## Decision 3: Native File Output (No Forced HTML)

### What

The agent produces whatever file format the user actually needs. If the user asks for a PowerPoint, the agent creates a `.pptx`. If they ask for a spreadsheet, the agent creates an `.xlsx`. We do not instruct the agent to produce HTML versions of these files for preview convenience.

### Why

We considered instructing agents to always produce HTML output (HTML slides instead of .pptx, HTML tables instead of .xlsx) so that WKWebView could preview everything. This was rejected because:

1. **User needs come first** — If someone asks for a PowerPoint deck for a client meeting, they need an actual `.pptx` file they can email, edit in PowerPoint, and present from. An HTML slide deck doesn't serve that purpose.
2. **Fidelity loss** — HTML approximations of Office formats lose formatting, fonts, animations, and compatibility.
3. **QLPreviewView solves preview** — We don't need the agent to produce a web-friendly format because macOS already knows how to preview the native format.

### The separation of concerns

- **Agent's job**: Produce the file the user requested, in the format they need.
- **App's job**: Preview that file natively, using the OS's rendering capabilities.

---

## Decision 4: Dynamic Output Classification

### What

A simple classifier inspects each `TaskOutput` and routes it to one of two rendering surfaces:

```
output.url exists and starts with "http" → WKWebView
output.filePath exists                   → QLPreviewView
else                                     → text fallback
```

### Why this is sufficient

The classifier doesn't need to understand file types. It only needs to answer one question: **is this a URL or a file?**

- WKWebView handles all URL-based content (live sites, HTML pages).
- QLPreviewView handles all file-based content (and macOS determines the appropriate renderer internally based on the file's UTI — Uniform Type Identifier).

### Extensibility

When a new output type is added (e.g., an interactive dashboard at a URL, or a 3D model file), the same two-branch classifier routes it correctly without any code changes. URLs go to the browser. Files go to QuickLook. The system handles the rest.

---

## Decision 5: Network Client Entitlement

### What

Add `com.apple.security.network.client = true` to the app's entitlements.

### Why

WKWebView requires this entitlement to make outgoing network connections — including loading `localhost` URLs. Without it, the embedded browser shows a blank page when trying to preview a website the agent is building on localhost.

### Distribution impact

- **Direct download (DMG/notarized)**: App Sandbox is optional; localhost access works without the entitlement. But adding it now is harmless and future-proofs the app.
- **Mac App Store**: App Sandbox is mandatory. The network client entitlement is required for any WKWebView network access.

We add the entitlement now to support both distribution channels without revisiting this later.

---

## Decision 6: Multiple Stacked Artifacts

### What

The artifact pane supports multiple outputs displayed as a vertically scrollable stack of preview cards. Each card is independently expandable.

### Why

Agents often produce multiple outputs in a single task:
- A document + a chart (shown in `assetview-screen.png`)
- A website + a configuration file
- Multiple images
- A presentation + a data source spreadsheet

The artifact pane header shows the count ("2 items created for FocusFlow") and each artifact gets its own preview card with type-appropriate rendering.

---

## Decision 7: Live Preview During Execution

### What

For streamable work (Type A), the preview updates in real-time as the agent works:

- **Websites**: WKWebView reloads the localhost URL periodically (timer-based) or when the backend signals a file change.
- **Files**: QLPreviewView calls `refreshPreviewItem()` when the file on disk is modified.

A status indicator distinguishes "Building..." (during execution) from the final state (after completion).

### Why

The "wow moment" is watching your AI employee build something in real time. If the user only sees the result after completion, the experience feels like a black box. Live preview makes the agent's work visible and inspectable.

### Implementation approach

- **Timer-based refresh** is simpler and more reliable than file-system watchers.
- Refresh interval: ~2-3 seconds during active execution.
- Stops refreshing when task status changes to `.completed`.

---

## Alternatives Considered (Summary)

| Alternative | Why Rejected |
|---|---|
| Inline chat cards | Artifacts scroll away, limited width, can't show multiple outputs persistently |
| Force HTML output from agents | Users need native files (.pptx, .xlsx); HTML approximations lose fidelity |
| Per-type custom Swift renderers | Maintenance burden; QLPreviewView already handles all formats natively |
| Enhanced OutputReviewView only | Doesn't support live preview during execution; no split-pane |
| Server-side file conversion (e.g., LibreOffice) | Heavy dependency; QLPreviewView eliminates the need entirely |

---

## Open Questions for Future Iterations

1. **Annotation**: Can users annotate directly on QLPreviewView previews (e.g., mark up a slide)? QLPreviewView is read-only; annotation would require PDFKit or a custom overlay.
2. **Export controls**: Should the artifact pane offer "Download as PDF" for web previews, or "Convert to HTML" for documents?
3. **Multi-employee artifacts**: When multiple employees contribute to the same task (shown in `assetview-screen.png` with S and M avatars), how are their outputs grouped?
4. **Artifact history**: Should previous versions of an artifact be accessible (e.g., after a revision)?
