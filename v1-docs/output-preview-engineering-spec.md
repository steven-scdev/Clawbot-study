# Output Preview — Engineering Specification

> Complete implementation guide for adding output preview to the Workforce macOS app. Written for an engineer with no prior context on the codebase.

---

## Table of Contents

1. [Product Context](#1-product-context)
2. [Feature Overview](#2-feature-overview)
3. [Architecture](#3-architecture)
4. [Current Codebase State](#4-current-codebase-state)
5. [New Components](#5-new-components)
6. [Files to Modify](#6-files-to-modify)
7. [Backend Changes](#7-backend-changes)
8. [Implementation Steps](#8-implementation-steps)
9. [Design Specifications](#9-design-specifications)
10. [Testing & Verification](#10-testing--verification)

---

## 1. Product Context

### What is Workforce?

Workforce is a macOS desktop application built on [OpenClaw](https://openclaw.ai) that lets users manage AI employees. Users assign tasks to AI employees (e.g., "build me a landing page," "create a quarterly report"), and the employees execute the work using OpenClaw's agent runtime.

### App Structure

```
macOS app (SwiftUI)  ←WebSocket→  OpenClaw Gateway  →  Agent Runtime
     │                                  │
     └─ Workforce UI                    └─ workforce plugin (TypeScript)
        - Employee gallery                 - Task lifecycle management
        - Chat view (per task)             - Event broadcasting
        - Task dashboard                   - Output detection
        - Output review                    - File persistence
```

### Current Task Lifecycle

1. **Brief** — User selects an AI employee and describes what they need
2. **Execute** — The agent runs, performing tool calls (write files, run commands, browse web)
3. **Complete** — Agent finishes; task status becomes `.completed`
4. **Review** — User sees output file names with "Open" / "Show in Finder" buttons

### The Problem

The review step only shows file names and type icons. The user never sees the actual content (the website, the document, the spreadsheet) inside the app. They must open files in external apps to inspect results.

### What We're Building

A **split-pane layout** where the left side is the existing chat conversation and the right side shows live, interactive previews of the agent's output — rendered natively in the app using macOS system frameworks.

### Visual References

Two mockups define the target UI (located in `ui/` directory at repository root):

**`ui/webview-screen.png`** — During execution:
- Left pane: Chat with Emma. She says "I've shared the initial landing page design in the artifact pane."
- Right pane: Browser-chrome-styled preview showing `localhost:3000/preview` with an "Expand" button
- Bottom-right: Status pill — "SARAH IS WORKING" with progress bar (multi-employee, future scope)

**`ui/assetview-screen.png`** — After completion:
- Left pane: Ongoing conversation. Input placeholder says "Ask for changes..."
- Right pane: "Generated Assets" header with "2 items created for FocusFlow"
  - Card 1: "Launch Strategy.md" with DRAFT V1 badge, rendered markdown content, "850 words · 3 min read", "Read more →"
  - Card 2: "Engagement Projections" chart with time range toggles (1W, 1M, 1Y), bar chart visualization
- Bottom: "Approve All Assets" button
- Footer: "POWERED BY WORKFORCE AI"

---

## 2. Feature Overview

### Split-Pane Layout

```
+----------------------------+-------------------------------+
|   Chat Pane (~45%)         |   Artifact Pane (~55%)        |
|                            |                               |
|   ┌─ ChatHeaderView ─┐    |   ┌─ ArtifactHeaderView ──┐  |
|   │ WORKFORCE / CHAT  │    |   │ Generated Assets       │  |
|   │ WITH EMMA         │    |   │ 2 items created...     │  |
|   └───────────────────┘    |   └────────────────────────┘  |
|                            |                               |
|   ┌─ Chat Messages ──┐    |   ┌─ Artifact Card 1 ─────┐  |
|   │ User: "Build me   │    |   │ [WKWebView or          │  |
|   │  a landing page"  │    |   │  QLPreviewView]        │  |
|   │                   │    |   │                        │  |
|   │ Emma: "I've shared│    |   │  [Expand] button       │  |
|   │  the design..."   │    |   └────────────────────────┘  |
|   │                   │    |                               |
|   │ [Thinking stream] │    |   ┌─ Artifact Card 2 ─────┐  |
|   │ [Typing indicator]│    |   │ [Another preview]      │  |
|   └───────────────────┘    |   └────────────────────────┘  |
|                            |                               |
|   ┌─ ChatInputPill ──┐    |   ┌─ Approve All Assets ──┐  |
|   │ Type a message... │    |   │ [Blue full-width btn]  │  |
|   └───────────────────┘    |   └────────────────────────┘  |
+----------------------------+-------------------------------+
```

### Two Rendering Surfaces

Every output is rendered by one of two macOS system frameworks:

| Surface | Technology | When Used |
|---|---|---|
| **WKWebView** | Apple WebKit (Safari engine) | Output has a URL (localhost site, HTML content) |
| **QLPreviewView** | Apple QuickLook | Output is a file on disk (any format) |

### Output Classification

A single decision point routes each output to the correct renderer:

```swift
if output has a URL starting with "http" → WKWebView
else if output has a filePath            → QLPreviewView
else                                     → text/placeholder fallback
```

No per-file-type logic is needed. WKWebView handles all web content. QLPreviewView handles everything else — macOS determines the appropriate renderer internally based on the file's Uniform Type Identifier (UTI).

### Supported Formats (via QLPreviewView)

QLPreviewView natively supports hundreds of file types. Key ones for Workforce:

| Category | Extensions | What the user sees |
|---|---|---|
| Documents | .pdf, .docx, .rtf, .txt, .md | Formatted text with pages |
| Presentations | .pptx, .key, .ppt | Slides with navigation |
| Spreadsheets | .xlsx, .csv, .numbers | Tabular data with sheets |
| Images | .png, .jpg, .svg, .gif, .webp | Image with zoom/pan |
| Video | .mp4, .mov, .webm | Video player with controls |
| Audio | .mp3, .wav, .aac | Audio waveform player |
| Code | .swift, .ts, .py, .js, .html | Syntax-highlighted text |
| Archives | .zip, .tar.gz | Contents listing |

---

## 3. Architecture

### Component Hierarchy

```
TaskChatView (modified — becomes left pane)
    │
    └─ HStack (new split-pane wrapper)
         ├─ ChatContentView (extracted from current TaskChatView body)
         │    ├─ ChatHeaderView (existing)
         │    ├─ ScrollView with chat messages (existing)
         │    │    ├─ ChatBubbleView (existing)
         │    │    ├─ AgentThinkingStreamView (existing)
         │    │    └─ TypingIndicatorView (existing)
         │    └─ ChatInputPill (existing)
         │
         └─ ArtifactPaneView (NEW — right pane, visible when outputs exist)
              ├─ ArtifactHeaderView (NEW)
              │    └─ "Generated Assets" + item count + employee avatars
              ├─ ScrollView
              │    └─ ForEach(task.outputs) { output in
              │         ArtifactRendererView(output) (NEW — routes to correct surface)
              │              ├─ WebArtifactView (NEW — WKWebView wrapper)
              │              └─ FileArtifactView (NEW — QLPreviewView wrapper)
              │    }
              └─ ApproveButton (or action bar)
```

### Data Flow

Outputs already flow from the backend to the frontend. No new event types are needed:

```
Agent writes a file or starts a dev server
    ↓
event-bridge.ts detectOutput() classifies the output
    ↓
Broadcasts "workforce.task.output" event via WebSocket:
    { id, type, title, filePath?, url?, createdAt }
    ↓
TaskService.handleWorkforcePush() receives the event
    ↓
Creates TaskOutput struct, appends to task.outputs array
    ↓
@Observable triggers SwiftUI re-render
    ↓
ArtifactPaneView appears (or updates) with the new output
    ↓
ArtifactRendererView routes to WKWebView or QLPreviewView
```

### State Management

No new services or state models are needed. The feature reads from existing state:

- `task.outputs: [TaskOutput]` — Array of outputs, populated by `workforce.task.output` events
- `task.status: TaskStatus` — Used to determine if preview is live (`.running`) or final (`.completed`)
- `output.url: String?` — If present, route to WKWebView
- `output.filePath: String?` — If present, route to QLPreviewView

### Entitlements

WKWebView requires `com.apple.security.network.client` to load localhost URLs. Create an entitlements file:

**File**: `apps/macos/Sources/Workforce/Workforce.entitlements`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.network.client</key>
    <true/>
</dict>
</plist>
```

Wire this into the build by adding a `linkerSettings` or `swiftSettings` entry in `Package.swift` for the `Workforce` target, or reference it in the codesign script (`scripts/codesign-mac-app.sh`) with `--entitlements`.

---

## 4. Current Codebase State

### Key Files You Need to Understand

All paths relative to `apps/macos/Sources/Workforce/`.

#### TaskChatView.swift — The main chat view (will become the split-pane host)

```swift
struct TaskChatView: View {
    let employee: Employee
    let taskId: String
    var taskService: TaskService
    var onBack: () -> Void

    // Key computed properties:
    // - task: WorkforceTask? — fetches from taskService.tasks by ID
    // - chatMessages: [ChatMessage] — converts task.activities to chat bubbles
    // - isAgentWorking: Bool — true when agent is running
    // - recentInternalActivities — thinking/toolCall/toolResult for AgentThinkingStreamView

    var body: some View {
        ZStack {
            BlobBackgroundView(phase: blobPhase, animated: true)
            VStack(spacing: 0) {
                ChatHeaderView(...)
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatMessages) { msg in
                                ChatBubbleView(message: msg, employeeName: employee.name)
                            }
                            // AgentThinkingStreamView
                            // TypingIndicatorView
                        }
                    }
                }
                ChatInputPill(text: $messageText, onSubmit: { await sendMessage() })
            }
        }
    }
}
```

This is currently a single-column view. The change: wrap the body in an `HStack` where the existing content becomes the left pane and a new `ArtifactPaneView` becomes the right pane.

#### TaskOutput.swift — The output model

```swift
struct TaskOutput: Identifiable, Codable, Sendable {
    let id: String
    var taskId: String
    var type: OutputType        // file, website, document, image, unknown
    var title: String           // Filename or "Preview"
    var filePath: String?       // Absolute path on disk (if file-based)
    var url: String?            // URL string (if web-based, e.g., "http://localhost:3000")
    var createdAt: Date
}

enum OutputType: String, Codable, Sendable {
    case file, website, document, image, unknown
}
```

This model already has everything needed for classification: `url` for WKWebView routing, `filePath` for QLPreviewView routing.

#### TaskService.swift — How outputs arrive from the backend

The `handleWorkforcePush()` method processes `workforce.task.output` events:

```swift
case "workforce.task.output":
    if let outDict = payload["output"]?.value as? [String: ProtoAnyCodable] {
        let output = TaskOutput(
            id: outDict["id"]?.value as? String ?? UUID().uuidString,
            taskId: taskId,
            type: OutputType(rawValue: outDict["type"]?.value as? String ?? "") ?? .unknown,
            title: outDict["title"]?.value as? String ?? "Output",
            filePath: outDict["filePath"]?.value as? String,
            url: outDict["url"]?.value as? String,
            createdAt: Date())
        self.taskOutputs[taskId, default: []].append(output)
        if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
            self.tasks[index].outputs.append(output)
        }
    }
```

Outputs are appended to `task.outputs` as they arrive. SwiftUI re-renders because `TaskService` is `@Observable`.

#### MainWindowView.swift — How TaskChatView is displayed

The flow state machine routes `.chatting` to `TaskChatView`:

```swift
case let .chatting(employee, taskId):
    TaskChatView(
        employee: employee,
        taskId: taskId,
        taskService: self.taskService,
        onBack: { self.flowState = .idle })
```

When a task completes, `.onChange(of: activeTaskStatus)` auto-transitions from `.executing` → `.reviewing`, which shows `OutputReviewView`. **With the artifact pane, this transition may need revisiting** — the user should stay in `.chatting` with artifacts visible rather than switching to a separate review view.

#### event-bridge.ts — How the backend detects outputs

```typescript
function detectOutput(evt: AgentEvent): TaskOutput | null {
    // Detects file writes (write_file, Write, create_file tools)
    // Classifies by extension: html→website, png/jpg→image, md/txt/pdf→document, else→file
    // Detects localhost URLs in tool results
    // Returns: { id, type, title, filePath?, url?, createdAt }
}
```

#### WorkforceTask.swift — The task model

```swift
struct WorkforceTask: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var employeeId: String
    var description: String
    var status: TaskStatus       // pending, running, completed, failed, cancelled
    var stage: TaskStage         // clarify, plan, execute, review, deliver
    var progress: Double         // 0.0 - 1.0
    var activities: [TaskActivity]
    var outputs: [TaskOutput]    // ← This is what the artifact pane reads
    // ...
}
```

#### Employee.swift — The employee model

```swift
struct Employee: Identifiable, Codable, Sendable, Equatable {
    let id: String
    var name: String
    var title: String
    var emoji: String
    var description: String
    var status: EmployeeStatus
    var capabilities: [String]
    var avatarSystemName: String
    var currentTaskId: String?
}
```

No `contentType` field exists yet. For this feature, we don't need one — output classification is based on the output's URL/filePath, not the employee type.

### Directory Structure

```
Sources/Workforce/
├── WorkforceApp.swift              # App entry point
├── MainWindowView.swift            # Flow state machine
├── Models/
│   ├── Employee.swift
│   ├── TaskFlowModels.swift        # TaskFlowState enum, ClarificationPayload, PlanPayload
│   ├── TaskOutput.swift            # TaskOutput, OutputType
│   └── WorkforceTask.swift         # WorkforceTask, TaskStatus, TaskStage, TaskActivity
├── Services/
│   ├── TaskService.swift           # Core task orchestration, event handling
│   ├── EmployeeService.swift
│   ├── WorkforceGateway.swift      # WebSocket actor
│   └── WorkforceGatewayService.swift
├── Views/
│   └── Tasks/
│       ├── TaskChatView.swift      # ← PRIMARY FILE TO MODIFY
│       ├── ChatHeaderView.swift
│       ├── OutputReviewView.swift  # ← May become redundant
│       ├── TaskProgressView.swift
│       ├── ActivityLogView.swift
│       └── AgentThinkingStreamView.swift
├── Components/
│   ├── ChatBubbleView.swift
│   ├── ChatInputPill.swift
│   ├── BlobBackgroundView.swift
│   ├── GlassEffect.swift
│   └── ... (UI effects and utilities)
└── Mock/
    └── MockData.swift
```

---

## 5. New Components

All new files go in `Components/Artifacts/`.

### 5.1 ArtifactPaneView.swift

**Purpose**: The right-pane container. Shows a header, scrollable stack of artifact cards, and an action bar.

```swift
import SwiftUI

struct ArtifactPaneView: View {
    let task: WorkforceTask
    let employee: Employee
    var onApproveAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header: "Generated Assets", item count, employee avatar(s)
            ArtifactHeaderView(
                itemCount: task.outputs.count,
                taskDescription: task.description,
                employee: employee)

            Divider()

            // Scrollable artifact cards
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(task.outputs) { output in
                        ArtifactRendererView(
                            output: output,
                            isLive: task.status == .running)
                    }
                }
                .padding(16)
            }

            Divider()

            // Action bar
            if task.status == .completed {
                Button(action: onApproveAll) {
                    Label("Approve All Assets", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(16)
            }
        }
        .background(.ultraThinMaterial)
    }
}
```

**Key behaviors**:
- Shows only when `task.outputs` is non-empty
- "Approve All Assets" button appears only when task is completed
- During execution, artifacts update live (no approve button yet)

### 5.2 ArtifactRendererView.swift

**Purpose**: Routes a `TaskOutput` to the correct rendering surface.

```swift
import SwiftUI

/// Determines which rendering surface to use for a given output.
enum ArtifactType {
    case web    // URL-based content → WKWebView
    case file   // File on disk → QLPreviewView
}

struct ArtifactRendererView: View {
    let output: TaskOutput
    let isLive: Bool // true during execution, false after completion

    var body: some View {
        VStack(spacing: 0) {
            switch classifyArtifact(output) {
            case .web:
                WebArtifactView(
                    url: output.url ?? "",
                    title: output.title,
                    isLive: isLive)

            case .file:
                FileArtifactView(
                    filePath: output.filePath ?? "",
                    title: output.title,
                    outputType: output.type,
                    isLive: isLive)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    /// Classify the output to determine the rendering surface.
    /// URL present → web (WKWebView). File path present → file (QLPreviewView).
    private func classifyArtifact(_ output: TaskOutput) -> ArtifactType {
        if let url = output.url, url.hasPrefix("http") {
            return .web
        }
        return .file
    }
}
```

### 5.3 WebArtifactView.swift

**Purpose**: WKWebView wrapper for rendering live websites and HTML content.

```swift
import SwiftUI
import WebKit

struct WebArtifactView: View {
    let url: String
    let title: String
    let isLive: Bool
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Browser chrome header
            browserChrome

            // WKWebView
            WebViewRepresentable(url: url, isLive: isLive)
                .frame(
                    minHeight: isExpanded ? 500 : 250,
                    maxHeight: isExpanded ? .infinity : 350)

            // Status footer
            if isLive {
                statusFooter
            }
        }
        .background(Color.white)
    }

    private var browserChrome: some View {
        HStack(spacing: 8) {
            // Traffic light dots (decorative)
            HStack(spacing: 6) {
                Circle().fill(.red.opacity(0.8)).frame(width: 10, height: 10)
                Circle().fill(.yellow.opacity(0.8)).frame(width: 10, height: 10)
                Circle().fill(.green.opacity(0.8)).frame(width: 10, height: 10)
            }

            Spacer()

            // URL bar
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(url)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())

            Spacer()

            // Expand button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                Label("Expand", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.05))
    }

    private var statusFooter: some View {
        HStack {
            Circle().fill(.green).frame(width: 6, height: 6)
            Text("Live preview")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.03))
    }
}

/// NSViewRepresentable wrapper for WKWebView.
struct WebViewRepresentable: NSViewRepresentable {
    let url: String
    let isLive: Bool

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Allow localhost access
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        loadURL(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Reload if URL changed
        if let current = webView.url?.absoluteString, current != url {
            loadURL(in: webView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLive: isLive)
    }

    private func loadURL(in webView: WKWebView) {
        guard let parsedURL = URL(string: url) else { return }
        webView.load(URLRequest(url: parsedURL))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let isLive: Bool
        private var refreshTimer: Timer?

        init(isLive: Bool) {
            self.isLive = isLive
            super.init()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Start periodic refresh during live execution
            if isLive && refreshTimer == nil {
                refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                    webView.reload()
                }
            }
        }

        deinit {
            refreshTimer?.invalidate()
        }
    }
}
```

**Key details**:
- Browser chrome with traffic lights matches `ui/webview-screen.png` mockup
- URL bar shows localhost address (read-only)
- Expand button toggles between compact (250-350pt) and expanded (500pt+) heights
- Timer-based reload every 3 seconds during live execution
- Timer stops when `isLive` becomes false (view is recreated by SwiftUI)

### 5.4 FileArtifactView.swift

**Purpose**: QLPreviewView wrapper for rendering any file format macOS supports.

```swift
import SwiftUI
import QuickLookUI

struct FileArtifactView: View {
    let filePath: String
    let title: String
    let outputType: OutputType
    let isLive: Bool
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // File header
            fileHeader

            // QLPreviewView
            if FileManager.default.fileExists(atPath: filePath) {
                QuickLookPreview(filePath: filePath, isLive: isLive)
                    .frame(
                        minHeight: isExpanded ? 400 : 200,
                        maxHeight: isExpanded ? .infinity : 300)
            } else {
                // File not yet written or path invalid
                placeholder
            }

            // Footer with metadata
            fileFooter
        }
        .background(Color.white)
    }

    private var fileHeader: some View {
        HStack(spacing: 10) {
            // File type icon
            Image(systemName: outputType.icon)
                .font(.system(size: 16))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if isLive {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text("DRAFT")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            // Expand button
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.03))
    }

    private var fileFooter: some View {
        HStack {
            // File type label
            Text(outputType.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            // "Read more" link for documents (matches mockup)
            if outputType == .document {
                Button("Read more") {
                    withAnimation { isExpanded = true }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.03))
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.clock")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("Generating...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color.secondary.opacity(0.03))
    }
}

/// NSViewRepresentable wrapper for QLPreviewView.
struct QuickLookPreview: NSViewRepresentable {
    let filePath: String
    let isLive: Bool

    func makeNSView(context: Context) -> QLPreviewView {
        let preview = QLPreviewView(frame: .zero, style: .compact)!
        preview.previewItem = FilePreviewItem(path: filePath)
        return preview
    }

    func updateNSView(_ preview: QLPreviewView, context: Context) {
        let newItem = FilePreviewItem(path: filePath)
        if preview.previewItem?.previewItemURL != newItem.previewItemURL {
            preview.previewItem = newItem
        }
        // Refresh during live execution (file may have changed on disk)
        if isLive {
            preview.refreshPreviewItem()
        }
    }
}

/// QLPreviewItem conformance for a file path.
class FilePreviewItem: NSObject, QLPreviewItem {
    let path: String

    init(path: String) {
        self.path = path
        super.init()
    }

    var previewItemURL: URL? {
        URL(fileURLWithPath: path)
    }

    var previewItemTitle: String? {
        URL(fileURLWithPath: path).lastPathComponent
    }
}
```

**Key details**:
- QLPreviewView automatically renders any file format macOS supports
- File header shows icon, title, and "DRAFT" badge during live execution (matches `assetview-screen.png`)
- `refreshPreviewItem()` called on `updateNSView` during live execution to reflect file changes
- Placeholder shown when file doesn't exist yet (agent still writing it)
- "Read more" link for documents (expands the preview, matching mockup)
- Expand button toggles height

### 5.5 ArtifactHeaderView.swift

**Purpose**: Header bar for the artifact pane showing title, item count, and employee avatar(s).

```swift
import SwiftUI

struct ArtifactHeaderView: View {
    let itemCount: Int
    let taskDescription: String
    let employee: Employee

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Generated Assets")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                // Employee avatar circle
                Text(employee.emoji)
                    .font(.system(size: 14))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing))
                    )
                    .clipShape(Circle())
            }

            Text("\(itemCount) item\(itemCount == 1 ? "" : "s") created for \(taskDescription)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
```

---

## 6. Files to Modify

### 6.1 TaskChatView.swift — Split-pane integration

**What changes**: The view body wraps existing chat content in an `HStack` with the artifact pane as the right column.

**Before** (simplified):
```swift
var body: some View {
    ZStack {
        BlobBackgroundView(...)
        VStack(spacing: 0) {
            ChatHeaderView(...)
            ScrollView { /* chat messages */ }
            ChatInputPill(...)
        }
    }
}
```

**After** (simplified):
```swift
var body: some View {
    ZStack {
        BlobBackgroundView(...)
        HStack(spacing: 0) {
            // Left pane: Chat
            VStack(spacing: 0) {
                ChatHeaderView(...)
                ScrollView { /* chat messages */ }
                ChatInputPill(...)
            }
            .frame(maxWidth: .infinity)

            // Right pane: Artifacts (visible when outputs exist)
            if let task, !task.outputs.isEmpty {
                Divider()
                ArtifactPaneView(
                    task: task,
                    employee: employee,
                    onApproveAll: { /* handle approval */ })
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }
}
```

**Key considerations**:
- The artifact pane slides in with animation when the first output arrives
- Both panes share the window width roughly 45/55 (chat/artifacts)
- When no outputs exist, chat takes full width (unchanged from current behavior)
- The `BlobBackgroundView` continues to fill the entire ZStack behind both panes

### 6.2 MainWindowView.swift — Flow state adjustments

Currently, when a task completes, `.onChange(of: activeTaskStatus)` transitions from `.executing` → `.reviewing`, which shows `OutputReviewView` (a separate full-screen view).

With the artifact pane, the user should **stay in `.chatting`** even after completion — the artifacts are already visible in the split pane. The `.reviewing` state and `OutputReviewView` may become redundant.

**Option A (recommended)**: Remove the auto-transition to `.reviewing`. The `.chatting` state with the artifact pane IS the review experience. The "Approve All Assets" button in the artifact pane replaces the approval flow in `OutputReviewView`.

**Option B**: Keep `.reviewing` but have it show the same split-pane layout with the "Approve" button enabled.

### 6.3 OutputReviewView.swift — Potentially redundant

If the artifact pane replaces the review experience (Option A above), this view is no longer needed for the primary flow. It could remain as a fallback for tasks viewed from the Task Dashboard (historical tasks).

### 6.4 TaskOutput.swift — Optional extensions

The current `OutputType` enum is sufficient for classification. Optionally expand it for richer metadata in artifact headers:

```swift
enum OutputType: String, Codable, Sendable {
    case file
    case website
    case document
    case image
    case unknown
    // Optional additions:
    case presentation
    case spreadsheet
    case video
    case audio
    case code
}
```

This is **not required** for rendering (QLPreviewView handles all types automatically) but improves the artifact card headers (showing "Presentation" instead of "File" for a .pptx).

### 6.5 Package.swift — No changes needed

WKWebView (WebKit) and QLPreviewView (QuickLookUI) are system frameworks — no new dependencies to add.

---

## 7. Backend Changes

### 7.1 Enhanced Output Classification

**File**: `extensions/workforce/src/event-bridge.ts`

The `classifyOutputType()` function currently handles: html→website, png/jpg→image, md/txt/pdf→document, default→file.

Expand to provide richer type information:

```typescript
function classifyOutputType(filePath: string): string {
    const ext = filePath.split('.').pop()?.toLowerCase() ?? '';

    // Web
    if (['html', 'htm'].includes(ext)) return 'website';

    // Documents
    if (['md', 'txt', 'pdf', 'doc', 'docx', 'rtf'].includes(ext)) return 'document';

    // Presentations
    if (['pptx', 'ppt', 'key'].includes(ext)) return 'presentation';

    // Spreadsheets
    if (['xlsx', 'xls', 'csv', 'numbers'].includes(ext)) return 'spreadsheet';

    // Images
    if (['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'bmp', 'ico'].includes(ext)) return 'image';

    // Video
    if (['mp4', 'mov', 'webm', 'avi', 'mkv'].includes(ext)) return 'video';

    // Audio
    if (['mp3', 'wav', 'aac', 'ogg', 'flac', 'm4a'].includes(ext)) return 'audio';

    // Code
    if (['swift', 'ts', 'js', 'py', 'go', 'rs', 'java', 'c', 'cpp', 'rb'].includes(ext)) return 'code';

    return 'file';
}
```

### 7.2 Enhanced Output Payload (optional)

Add metadata to output events for richer artifact cards:

```typescript
// In detectOutput(), after creating the output:
const output: TaskOutput = {
    id: generateId('out'),
    type: classifyOutputType(filePath),
    title: path.basename(filePath),
    filePath: filePath,
    url: undefined,
    createdAt: new Date().toISOString(),
    // New optional fields:
    fileSize: fs.existsSync(filePath) ? fs.statSync(filePath).size : undefined,
    contentPreview: isTextFile(filePath) ? readFirstNChars(filePath, 500) : undefined,
};
```

This is **nice-to-have** — the frontend can display word counts and text previews in artifact headers. Not required for the core rendering feature.

### 7.3 Swift-Side OutputType Decoding

If you add new output types in the backend (`presentation`, `spreadsheet`, `video`, `audio`, `code`), update `OutputType` in Swift to match. Use `unknown` as fallback for unrecognized types — this is already handled by the current decoder.

---

## 8. Implementation Steps

Execute these in order. Build and verify after each step.

### Step 1: Entitlements

1. Create `apps/macos/Sources/Workforce/Workforce.entitlements` with `com.apple.security.network.client = true`
2. Reference in build script or Package.swift
3. **Verify**: `swift build` compiles clean

### Step 2: ArtifactRendererView + ArtifactType classification

1. Create `Components/Artifacts/ArtifactRendererView.swift`
2. Define `ArtifactType` enum (`.web`, `.file`)
3. Implement `classifyArtifact()` function
4. Stub out `WebArtifactView` and `FileArtifactView` as placeholder views
5. **Verify**: `swift build` compiles clean

### Step 3: WebArtifactView

1. Create `Components/Artifacts/WebArtifactView.swift`
2. Implement `WebViewRepresentable` (NSViewRepresentable for WKWebView)
3. Add browser chrome (traffic lights, URL bar, expand button)
4. Add timer-based auto-refresh for live execution
5. **Verify**: `swift build` compiles clean

### Step 4: FileArtifactView

1. Create `Components/Artifacts/FileArtifactView.swift`
2. Implement `QuickLookPreview` (NSViewRepresentable for QLPreviewView)
3. Implement `FilePreviewItem` (QLPreviewItem conformance)
4. Add file header (icon, title, DRAFT badge)
5. Add expand toggle and footer
6. Add placeholder for files not yet written
7. **Verify**: `swift build` compiles clean

### Step 5: ArtifactHeaderView + ArtifactPaneView

1. Create `Components/Artifacts/ArtifactHeaderView.swift`
2. Create `Components/Artifacts/ArtifactPaneView.swift`
3. Wire together: header, scrollable artifact list, approve button
4. **Verify**: `swift build` compiles clean

### Step 6: Split-pane integration in TaskChatView

1. Modify `TaskChatView.swift` body to use HStack
2. Existing chat content becomes left pane
3. `ArtifactPaneView` becomes right pane (conditional on `task.outputs.isEmpty`)
4. Add slide-in animation with `.transition(.move(edge: .trailing).combined(with: .opacity))`
5. **Verify**: `swift build` compiles clean

### Step 7: Flow state adjustments

1. Review `MainWindowView.swift` auto-transition from `.executing` → `.reviewing`
2. Decide whether to keep `.reviewing` or let `.chatting` with artifacts serve as the review
3. Wire "Approve All Assets" button action (calls `onDone` or equivalent)
4. Adjust `ChatInputPill` placeholder to "Ask for changes..." when task is completed (matches mockup)
5. **Verify**: `swift build` compiles clean

### Step 8: Backend output classification enhancement

1. Expand `classifyOutputType()` in `event-bridge.ts` with more extensions
2. Update `OutputType` enum in Swift `TaskOutput.swift` to match new types
3. **Verify**: `swift build` compiles clean, backend lints clean

### Step 9: Live preview refinement

1. Tune WKWebView refresh interval (start with 3 seconds, adjust based on testing)
2. Tune QLPreviewView `refreshPreviewItem()` triggers
3. Add "Building..." vs final status indicators on artifact cards
4. Stop refresh timers when task status is no longer `.running`
5. **Verify**: Full manual test cycle

---

## 9. Design Specifications

### Glass-morphism consistency

The app uses a consistent glass-morphism style. Match it in the artifact pane:
- Background: `.ultraThinMaterial` or `Color.white.opacity(0.55)` + `.ultraThinMaterial`
- Card shadows: `color: .black.opacity(0.08), radius: 8, y: 2`
- Corner radius: 12pt for cards, 14pt for the pane container
- Dividers: `Color.white.opacity(0.15)`, 0.5pt height

### Color Palette (from existing views)

- Primary accent: Blue (system `.blue`)
- Gradient accents: Blue → Purple (for avatars, buttons)
- Background: Warm gradient (cream → sage → sky blue) — already in `WorkforceApp.swift`
- Text: Primary at 0.85-1.0 opacity, secondary at 0.4-0.6 opacity

### Typography

- Header: `.title3` with `.bold` weight
- Subheader: `.subheadline` with `.secondary` foreground
- Body: `.system(size: 13)`
- Captions: `.caption` or `.caption2`
- Monospaced (URL bar): `.system(size: 11, design: .monospaced)`

### Spacing

- Pane padding: 16pt
- Card spacing: 16pt between cards
- Internal card padding: 12pt horizontal, 10pt vertical
- Header padding: 16pt horizontal, 12pt vertical

### Transitions & Animations

- Artifact pane entrance: `.move(edge: .trailing).combined(with: .opacity)` with `.easeInOut(duration: 0.3)`
- Expand/collapse: `.easeInOut(duration: 0.25)`
- Status indicators: subtle pulse animation on "Live preview" dot

---

## 10. Testing & Verification

### Build Verification

Run after every implementation step:
```bash
cd apps/macos && swift build
```

Must compile clean with zero warnings related to new code.

### Unit Tests

Add to the existing test suite:

1. **ArtifactType classification**:
   - Output with `url: "http://localhost:3000"` → `.web`
   - Output with `url: "https://example.com"` → `.web`
   - Output with `filePath: "/path/to/file.pptx"` → `.file`
   - Output with both `url` and `filePath` → `.web` (URL takes precedence)
   - Output with neither → `.file` (fallback)

2. **OutputType expansion** (if implemented):
   - Verify `.presentation`, `.spreadsheet`, `.video`, `.audio`, `.code` decode correctly
   - Verify unknown types fall back to `.unknown`

### Manual Test Scenarios

These tests require the full app running with a connected OpenClaw gateway:

1. **Website output**: Submit a task like "Create a simple HTML landing page with a hello world message"
   - Expected: Agent creates HTML files, possibly starts dev server
   - If localhost URL detected → WKWebView shows live site in artifact pane
   - If only HTML file written → QLPreviewView shows the HTML file

2. **Document output**: Submit "Write a brief report about the benefits of remote work"
   - Expected: Agent writes a `.md` or `.txt` file
   - QLPreviewView renders the document in the artifact pane
   - File header shows title and "DRAFT" badge during execution

3. **Multiple outputs**: Submit "Create a project README and a simple landing page"
   - Expected: Agent produces multiple files
   - Artifact pane stacks them vertically
   - Each gets its own preview card

4. **Expand/collapse**: Click the expand button on an artifact card
   - Expected: Card height increases smoothly; click again to collapse

5. **Live refresh**: During execution, watch the artifact pane
   - Expected: WKWebView reloads periodically; QLPreviewView reflects file changes

6. **No outputs**: Submit a conversational task (no file output expected)
   - Expected: Chat takes full width; no artifact pane appears

7. **Pane appearance animation**: Watch when the first output arrives
   - Expected: Artifact pane slides in from the right with a smooth transition

### Backend Tests

```bash
cd extensions/workforce && npx vitest run
```

- Verify `classifyOutputType()` returns correct types for all new extensions
- Existing tests continue to pass

### Edge Cases to Verify

- Agent writes a file then deletes it → FileArtifactView shows placeholder
- Extremely large file (100MB+) → QLPreviewView handles gracefully (it does)
- Invalid/corrupted file → QLPreviewView shows error state (it does)
- Agent starts a dev server but it crashes → WKWebView shows connection error page
- Window resize → split pane proportions adjust fluidly
- Multiple rapid outputs → artifact list updates without UI jank

---

## Appendix: File Inventory

### New Files

| File | Purpose |
|------|---------|
| `Components/Artifacts/ArtifactPaneView.swift` | Right-pane container with header, artifact list, approve button |
| `Components/Artifacts/ArtifactRendererView.swift` | Routes output to WKWebView or QLPreviewView |
| `Components/Artifacts/WebArtifactView.swift` | WKWebView wrapper with browser chrome |
| `Components/Artifacts/FileArtifactView.swift` | QLPreviewView wrapper with file header |
| `Components/Artifacts/ArtifactHeaderView.swift` | "Generated Assets" header bar |
| `Workforce.entitlements` | Network client entitlement for WKWebView |

### Modified Files

| File | Change |
|------|--------|
| `Views/Tasks/TaskChatView.swift` | Wrap body in HStack; add ArtifactPaneView as right pane |
| `MainWindowView.swift` | Adjust auto-transition logic (`.reviewing` may become redundant) |
| `Models/TaskOutput.swift` | Optionally expand OutputType enum |
| `extensions/workforce/src/event-bridge.ts` | Expand classifyOutputType() with more extensions |

### Unchanged Files (but important to understand)

| File | Why |
|------|-----|
| `Services/TaskService.swift` | Existing output event handling works as-is |
| `Components/ChatBubbleView.swift` | No changes needed |
| `Components/ChatInputPill.swift` | Placeholder text change only |
| `Views/Tasks/OutputReviewView.swift` | May become redundant but left intact |
