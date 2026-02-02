# Workforce Engineering Roadmap: Ticket-Ready Implementation Plan

**Date**: February 2, 2026
**Role**: Technical Lead
**Approach**: Frontend-first, product-driven. Build the desktop app first, test each backend feature visually before moving on.

---

## Guiding Principle: Product-Driven Development

Every feature is a **vertical slice** — we build what the user sees first, connect it to the backend, and verify it works in the app before moving to the next feature.

**Why frontend-first?**
1. We catch UX problems early, before investing in backend plumbing
2. We can demo progress to stakeholders at every stage
3. The engineer gets fast feedback loops — see the change, not just log it
4. Mock data → real data is a smooth transition, not a risky "big bang" integration

**Existing assets we reuse (not rebuild)**:
- `OpenClawKit` shared framework — `GatewayConnection` actor, `GatewayChannelActor`, `ControlChannel` event streaming, authentication, auto-reconnect
- Existing gateway methods: `agents.list`, `chat.send`, `chat.history`, `sessions.list`, `exec.approval.*`, `config.get/set`
- Existing macOS menu bar app (`apps/macos/Sources/OpenClaw/`) — reference for patterns, not copy-paste

**What already works with ZERO new backend**:
- Gateway WebSocket connection + auth (via `OpenClawKit`)
- Listing available AI agents (`agents.list`)
- Sending a message to an agent (`chat.send` with streaming response)
- Getting chat history (`chat.history`)
- Session management (`sessions.list`, `sessions.preview`)
- Execution approvals (`exec.approval.request/resolve`)

**What needs the new workforce plugin**:
- Employee metadata (name, emoji, title → beyond raw agent config)
- Task manifest persistence (structured task state beyond session transcripts)
- Employee personality injection (system prompt hook)
- Output tracking and previews
- Feedback/rating system
- Stage heuristics

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  Workforce Desktop App (SwiftUI + AppKit)               │
│                                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Employee  │ │   Task   │ │  Output  │ │ Settings │  │
│  │ Gallery   │ │  Panel   │ │  Viewer  │ │  Panel   │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │ OpenClawKit (REUSE — already built)               │   │
│  │ GatewayConnection · ControlChannel · Auth         │   │
│  └──────────────────────────────────────────────────┘   │
│                        │ WebSocket + HTTP                │
└────────────────────────┼────────────────────────────────┘
                         ▼
┌─────────────────────────────────────────────────────────┐
│  OpenClaw Gateway                                        │
│                                                          │
│  extensions/workforce/ (NEW)    Existing Core:           │
│  ├── Employee Registry          ├── Agent Runtime        │
│  ├── Task Store                 ├── Session Manager      │
│  ├── Task Runner                ├── Tool Execution       │
│  ├── Event Bridge               ├── Browser Control      │
│  └── RPC Methods                └── Hook System          │
└─────────────────────────────────────────────────────────┘
```

---

## Phase A: Desktop App Foundation (Frontend Only)

**Goal**: Build the full desktop app UI using existing gateway capabilities + mock data. User can open the app, see employees, assign a task, and see progress. No new backend code needed.

**Who**: Frontend Engineer (Swift)
**Backend**: Uses existing OpenClaw gateway as-is

---

### A-1: Xcode Project + Desktop Window

**What the user sees**: A real desktop app window (not just a menu bar dropdown). A proper macOS app with a sidebar, content area, and window chrome.

**Frontend Engineer**:

Create a new Xcode project target for the Workforce desktop app alongside the existing menu bar app. This is a **window-based app**, not a menu bar app.

**Files to create**:
```
apps/macos/Sources/Workforce/
├── WorkforceApp.swift             # @main entry, WindowGroup scene
├── AppDelegate.swift              # App lifecycle, menu bar integration
├── MainWindowView.swift           # NavigationSplitView container
├── SidebarView.swift              # Left sidebar: Employees, Tasks, Settings
└── ContentPlaceholderView.swift   # Placeholder for content area
```

**Reference from existing app**:
- `apps/macos/Sources/OpenClaw/MenuBar.swift` — app entry point pattern
- `apps/macos/Sources/OpenClaw/App/AppDelegate.swift` — lifecycle management
- `apps/macos/Sources/OpenClaw/App/AppState.swift` — `@Observable` state pattern

**Technical decisions**:
- Use `WindowGroup` (not `MenuBarExtra`) for a proper window
- `NavigationSplitView` with three-column layout: sidebar, list, detail
- Sidebar items: Employees (gallery), Tasks (dashboard), Settings
- Window minimum size: 900x600, default: 1200x800
- macOS 15+ (Sequoia) target to match existing app
- Use `@Observable` (not `ObservableObject`) per existing codebase convention

**Acceptance criteria**:
- [ ] App launches as a desktop window (not menu bar)
- [ ] Sidebar shows navigation items: Employees, Tasks, Settings
- [ ] Clicking sidebar items changes content area
- [ ] Window respects macOS conventions (Cmd+Q, Cmd+W, Cmd+,)
- [ ] App icon appears in Dock when running

**Backend Engineer**: No work needed.

**Test**: Launch app, verify window appears with sidebar navigation.

---

### A-2: Gateway Connection (Reuse OpenClawKit)

**What the user sees**: A status indicator showing "Connected" with a green dot, or "Gateway Not Running" with a "Start" button. Connection is seamless — the app just works.

**Frontend Engineer**:

Wire up the existing `OpenClawKit` networking stack to the Workforce app. The heavy lifting is already done — `GatewayConnection`, `GatewayChannelActor`, and `ControlChannel` handle WebSocket, auth, reconnection, and events.

**Files to create**:
```
apps/macos/Sources/Workforce/
├── Services/
│   └── WorkforceGatewayService.swift   # Thin wrapper around GatewayConnection
├── Views/
│   ├── ConnectionStatusView.swift      # Status bar indicator
│   └── GatewayNotRunningView.swift     # Full-screen "start gateway" prompt
```

**Reference from existing app**:
- `apps/shared/OpenClawKit/Sources/GatewayChannel.swift` — WebSocket transport
- `apps/macos/Sources/OpenClaw/GatewayConnection.swift` — RPC call wrapper
- `apps/macos/Sources/OpenClaw/ControlChannel.swift` — event streaming
- `apps/macos/Sources/OpenClaw/Connection/GatewayConnectivityCoordinator.swift` — connection state machine

**Implementation**:
```swift
@Observable
@MainActor
final class WorkforceGatewayService {
    var connectionState: ConnectionState = .disconnected

    private let gateway: GatewayConnection  // Reuse existing actor

    func connect() async throws {
        // Same connect flow as menu bar app
        // Token auth with operator.admin scope
    }

    func call<T: Decodable>(method: String, params: [String: AnyCodable]?) async throws -> T {
        try await gateway.requestDecoded(method: method, params: params)
    }

    func subscribe() -> AsyncStream<GatewayPush> {
        gateway.subscribe()
    }
}
```

**Connection states**:
- `.disconnected` → show `GatewayNotRunningView` with "Start Gateway" button
- `.connecting` → show spinner in status bar
- `.connected(version)` → green dot + version in status bar
- `.error(message)` → red dot + error + "Retry" button

**Acceptance criteria**:
- [ ] App connects to running gateway on launch
- [ ] Green dot shows when connected
- [ ] "Gateway Not Running" screen appears when gateway is offline
- [ ] Auto-reconnects after disconnect
- [ ] Connection state visible in status bar at all times

**Backend Engineer**: No work needed — uses existing gateway.

**Test**: Start gateway, launch app, verify green dot. Stop gateway, verify error state. Restart gateway, verify auto-reconnect.

---

### A-3: Swift Data Models + Mock Data

**What the user sees**: Nothing yet — this is the data layer that makes everything else work. But it includes mock employees so the gallery has something to show immediately.

**Frontend Engineer**:

Define all Swift models + create a mock data layer for development. Mock data lets us build and test all UI views before the backend is ready.

**Files to create**:
```
apps/macos/Sources/Workforce/
├── Models/
│   ├── Employee.swift              # Employee, EmployeeStatus
│   ├── WorkforceTask.swift         # Task, TaskStatus, TaskStage, TaskActivity
│   ├── TaskOutput.swift            # TaskOutput, OutputType
│   ├── GatewayModels.swift         # Request/Response/Event frame types
│   └── Settings.swift              # App settings
├── Mock/
│   └── MockData.swift              # Hardcoded employees + sample tasks
```

**Mock employees** (used in Phase A, replaced by real data in Phase B):
```swift
extension Employee {
    static let mockEmployees: [Employee] = [
        Employee(id: "emma-web", name: "Emma", title: "Web Builder",
                 emoji: "🌐", description: "Creates professional websites and landing pages",
                 status: .online, capabilities: ["websites", "React", "Tailwind"]),
        Employee(id: "david-decks", name: "David", title: "Deck Maker",
                 emoji: "📊", description: "Creates professional presentation decks",
                 status: .online, capabilities: ["presentations", "data-viz"]),
        Employee(id: "sarah-research", name: "Sarah", title: "Research Analyst",
                 emoji: "🔍", description: "Deep research and competitive analysis",
                 status: .online, capabilities: ["research", "analysis", "reports"]),
    ]
}
```

**Key model decisions**:
- `WorkforceTask` (not `Task` — avoids collision with Swift's `Task` type)
- All enums use `String` raw values with `Codable` conformance
- Unknown enum values handled gracefully (`.unknown` case) so app doesn't crash on new backend states
- All models are `Sendable` for `async` contexts
- Date coding uses ISO 8601 strategy

**Acceptance criteria**:
- [ ] All models compile and conform to `Codable`, `Identifiable`, `Sendable`
- [ ] Mock data available for all model types
- [ ] JSON decode/encode round-trips correctly (unit test)
- [ ] Unknown enum values don't crash (unit test)

**Backend Engineer**: No work needed.

**Test**: Unit tests for model encoding/decoding.

---

### A-4: Employee Gallery View

**What the user sees**: A beautiful gallery of AI employee cards — each with an emoji, name, title, and status dot. Clicking an employee opens the task assignment panel. This is the "meet your team" moment.

**Frontend Engineer**:

Build the employee gallery as a grid of cards. Uses mock data initially, swapped for real data later.

**Files to create**:
```
apps/macos/Sources/Workforce/
├── Services/
│   └── EmployeeService.swift          # Employee state management
├── Views/Employees/
│   ├── EmployeeGalleryView.swift      # Grid of cards
│   ├── EmployeeCardView.swift         # Single employee card
│   └── EmployeeDetailPopover.swift    # Hover/click detail
```

**EmployeeService**:
```swift
@Observable
@MainActor
final class EmployeeService {
    var employees: [Employee] = Employee.mockEmployees  // Start with mock
    var isLoading = false

    // Phase A: returns mock data
    // Phase B: calls workforce.employees.list via gateway
    func fetchEmployees() async {
        // Will be wired to gateway in B-2
        employees = Employee.mockEmployees
    }
}
```

**EmployeeGalleryView layout**:
- `LazyVGrid` with `GridItem(.adaptive(minimum: 160, maximum: 220))`
- Each card: emoji (large), name, title, status indicator
- Status: green dot = online, yellow dot = busy (with task name), gray = offline
- Hover: subtle scale + shadow
- Click: navigates to task input for that employee
- Empty state: "No employees configured. Check settings."

**Acceptance criteria**:
- [ ] Gallery shows 3 mock employees in a grid
- [ ] Each card shows emoji, name, title, status dot
- [ ] Clicking a card navigates to task input (placeholder OK for now)
- [ ] Hover effect on cards
- [ ] Gallery scrolls if many employees
- [ ] Empty state when no employees

**Backend Engineer**: No work needed — mock data.

**Test**: Launch app, click "Employees" in sidebar, verify gallery renders with 3 cards.

---

### A-5: Task Input View

**What the user sees**: After clicking an employee, a panel where they describe what they want built. Text area, file attachments, "Assign Task" button. Feels like messaging a colleague, not configuring a pipeline.

**Frontend Engineer**:

Build the task assignment panel. In Phase A, "Assign Task" sends a message via `chat.send` (existing gateway method) to a default agent.

**Files to create**:
```
apps/macos/Sources/Workforce/
├── Services/
│   └── TaskService.swift              # Task submission + state
├── Views/Tasks/
│   ├── TaskInputView.swift            # Task description panel
│   └── AttachmentPickerView.swift     # File/folder picker
```

**TaskInputView layout**:
- Employee header: emoji + name + title + "Ready to help"
- Text area: large, multiline, placeholder "What would you like me to build?"
- Attachments section: drag-and-drop zone + "Add File" button
- Shared folders: folder picker with checkmarks
- "Assign Task" button (prominent, bottom-right)

**Task submission (Phase A — uses existing gateway)**:
```swift
func submitTask(employeeId: String, description: String) async throws -> WorkforceTask {
    // Phase A: Use existing chat.send with a dedicated session
    let sessionKey = "workforce-\(employeeId)-\(UUID().uuidString.prefix(8))"

    // Send via existing gateway method
    try await gateway.call(method: "chat.send", params: [
        "message": description,
        "sessionKey": sessionKey,
        "agentId": employeeId  // Maps to OpenClaw agent
    ])

    // Create local task object for tracking
    let task = WorkforceTask(
        id: UUID().uuidString,
        employeeId: employeeId,
        description: description,
        status: .running,
        stage: .execute,
        progress: 0.0,
        sessionKey: sessionKey,
        createdAt: Date()
    )
    tasks.append(task)
    return task
}
```

**Acceptance criteria**:
- [ ] Task input shows selected employee header
- [ ] Text area accepts multiline description
- [ ] "Assign Task" button is disabled when description is empty
- [ ] Files can be attached via file picker or drag-and-drop
- [ ] After submission, navigates to progress view
- [ ] Submission calls `chat.send` on existing gateway (real agent run starts)

**Backend Engineer**: No work needed — uses existing `chat.send`.

**Test**: Select Emma, type "Write a hello world HTML file", click Assign Task. Verify agent actually runs (check gateway logs).

---

### A-6: Task Progress View

**What the user sees**: Real-time progress as the employee works. Activity log scrolling with what the agent is doing: "Reading file...", "Writing code...", "Running command...". This is the "watching someone work" moment.

**Frontend Engineer**:

Build the progress view that streams real-time agent events. In Phase A, this subscribes to existing agent events via `ControlChannel` (already built in OpenClawKit).

**Files to create**:
```
apps/macos/Sources/Workforce/
├── Views/Tasks/
│   ├── TaskProgressView.swift         # Main progress view
│   ├── StageIndicatorView.swift       # Clarify→Plan→Execute→Review→Deliver
│   ├── ActivityLogView.swift          # Scrolling activity feed
│   └── TaskControlsView.swift         # Pause/Cancel buttons (wired later)
├── Components/
│   ├── ProgressBarView.swift          # Animated progress bar
│   └── StatusDotView.swift            # Reusable status indicator
```

**Event streaming (Phase A — uses existing ControlChannel)**:
```swift
func observeTaskProgress(sessionKey: String) -> AsyncStream<TaskActivity> {
    // Subscribe to existing agent events via ControlChannel
    let pushStream = gateway.subscribe()

    return AsyncStream { continuation in
        Task {
            for await push in pushStream {
                // Filter events for our session
                if let activity = mapGatewayPushToActivity(push, sessionKey: sessionKey) {
                    continuation.yield(activity)
                }
            }
        }
    }
}
```

**Progress view layout**:
- Employee header: emoji + name + "Working on your task"
- Progress bar: animated, 0-100% (estimated from activity count in Phase A)
- Stage indicator: 5 stages with icons — in Phase A, only "Execute" is active (stage heuristics come in Phase B)
- Activity log: scrolling list of activities with timestamps
  - Tool calls: "Reading file.txt", "Writing index.html", "Running npm install"
  - Assistant text: summary of what the agent is thinking
  - Errors: red text with error message
- Controls: Cancel button (calls `chat.abort` — existing method)

**Acceptance criteria**:
- [ ] Progress view shows employee header with task description
- [ ] Activity log streams events in real-time as agent works
- [ ] Activity log auto-scrolls to latest entry
- [ ] Cancel button calls `chat.abort` and stops the agent
- [ ] Stage indicator shows (static "Execute" in Phase A — dynamic in Phase B)
- [ ] Progress bar animates (estimated in Phase A)
- [ ] View handles agent completion (shows "Task Complete")

**Backend Engineer**: No work needed — uses existing event streaming.

**Test**: Submit a task to an agent, watch activity log stream events in real-time. Click Cancel, verify agent stops.

---

### A-7: Task Dashboard

**What the user sees**: A list of all tasks — active ones with progress bars, completed ones with checkmarks, failed ones with error messages. The "what's everyone working on" view.

**Frontend Engineer**:

Build the task dashboard. In Phase A, tasks are tracked locally in `TaskService` (in-memory). They won't survive app restarts yet — that comes in Phase B when the backend task store is built.

**Files to create**:
```
apps/macos/Sources/Workforce/
├── Views/Tasks/
│   ├── TaskDashboardView.swift        # Dashboard with sections
│   └── TaskRowView.swift              # Single task row
```

**Dashboard layout**:
- Section: "Active Tasks" — running tasks with progress bars
- Section: "Completed Today" — finished tasks with completion time
- Section: "Failed" — failed tasks with error message + retry button
- Each row: employee emoji, task description (truncated), progress bar, status

**Acceptance criteria**:
- [ ] Dashboard shows active, completed, and failed task sections
- [ ] Active tasks show progress bar
- [ ] Completed tasks show completion time
- [ ] Clicking a task navigates to its progress view / output view
- [ ] Empty state: "No tasks yet. Assign a task from the Employee Gallery."
- [ ] Tasks persist during app session (in-memory)

**Backend Engineer**: No work needed.

**Test**: Submit 2 tasks, verify both appear in dashboard. Wait for completion, verify they move to "Completed" section.

---

### A-8: Settings Panel + App Shell Polish

**What the user sees**: A settings window where they configure gateway connection (port, token), manage shared folders, and see app info. Plus polished app shell: proper sidebar, status bar, window management.

**Frontend Engineer**:

Build settings and polish the app shell.

**Files to create**:
```
apps/macos/Sources/Workforce/
├── Views/Settings/
│   ├── SettingsView.swift             # Settings container (tabs)
│   ├── GatewaySettingsView.swift      # Port, token, auto-start
│   └── FoldersSettingsView.swift      # Shared folder management
├── Views/
│   └── MainWindowView.swift           # Polish: status bar, transitions
```

**Reference from existing app**:
- `apps/macos/Sources/OpenClaw/Views/Settings/SettingsRootView.swift` — tab pattern

**Settings tabs**:
- General: Launch at login, notification preferences
- Gateway: Port (default 18789), token, connection status, Restart Gateway button
- Shared Folders: List of folders accessible to employees, Add/Remove buttons

**App shell polish**:
- Status bar at bottom of window: connection dot + "Connected to Gateway v2025.x"
- Sidebar selection highlights properly
- Smooth transitions between views (`NavigationSplitView` animations)
- Cmd+, opens settings (standard macOS)
- Window remembers size and position

**Acceptance criteria**:
- [ ] Settings window opens with Cmd+,
- [ ] Gateway settings show current connection state
- [ ] Port and token are editable and saved
- [ ] Shared folders can be added (folder picker) and removed
- [ ] Status bar shows connection state at all times
- [ ] Sidebar selection state is correct

**Backend Engineer**: No work needed — uses existing `config.get/set`.

**Test**: Change gateway port in settings, verify reconnection. Add a shared folder, verify it persists.

---

### A-9: Phase A Integration Test

**What the user sees**: The full Phase A experience working end-to-end.

**Test scenario** (manual):
```
1. Launch Workforce app → window appears with sidebar
2. Status bar shows "Connected" (green dot)
3. Click "Employees" → see 3 employee cards (mock data)
4. Click Emma → task input panel opens
5. Type "Write a hello world HTML file" → click "Assign Task"
6. Progress view appears → activity log streams real-time events
7. Agent completes → "Task Complete" shown
8. Click "Tasks" in sidebar → dashboard shows completed task
9. Open Settings → verify gateway connection settings
```

**What works**: Full UI flow with real agent execution via existing gateway.
**What's mock/limited**: Employee data is hardcoded. Tasks don't survive app restart. No stage heuristics. No output previews. No feedback.

---

## Phase B: Workforce Backend + Frontend Integration

**Goal**: Build each backend component and immediately integrate + test it in the desktop app. Each ticket is a vertical slice: backend change → frontend integration → visual verification.

**Who**: Backend Engineer (TypeScript) builds the feature, Frontend Engineer (Swift) integrates it.

---

### B-1: Plugin Scaffold (Backend)

**What the user sees**: Nothing changes visually. But under the hood, the workforce plugin loads on gateway boot — the foundation for all backend features.

**Backend Engineer**:

Create the `extensions/workforce/` plugin. Follow `extensions/voice-call/` as the reference pattern (it registers gateway methods, HTTP routes, hooks, and services).

**Files to create**:
```
extensions/workforce/
├── openclaw.plugin.json           # Plugin manifest (JSON Schema configSchema)
├── package.json                   # Dependencies
├── tsconfig.json                  # TypeScript config
└── src/
    ├── index.ts                   # register(api) entry point
    └── types.ts                   # Shared TypeScript types
```

**Codebase integration**:
- Manifest format: `src/plugins/manifest.ts` — must use JSON Schema (not Zod/TypeBox)
- Entry: export `{ id: "workforce", register(api: OpenClawPluginApi) }` (see `extensions/voice-call/index.ts`)
- Discovery: auto-discovered in `extensions/` workspace (see `src/plugins/loader.ts`)
- Config schema: JSON Schema format in `openclaw.plugin.json`

**Acceptance criteria**:
- [ ] `openclaw.plugin.json` is valid and loadable
- [ ] Gateway boots with workforce plugin loaded (verify in logs)
- [ ] `register(api)` is called during boot
- [ ] Plugin can be enabled/disabled via config

**Frontend Engineer**: No work needed.

**Test**: Start gateway, check logs for `[workforce] plugin registered`.

---

### B-2: Employee Registry → Update Gallery (Vertical Slice)

**What the user sees**: Employee gallery now shows real employees loaded from the gateway, not hardcoded mock data. Status updates in real-time (online/busy/offline).

**Backend Engineer**:

Build the employee registry and `workforce.employees.list` / `workforce.employees.get` RPC methods.

**Files to create**:
```
extensions/workforce/src/
├── employee-registry.ts           # Load employees from config
├── config-schema.ts               # JSON Schema for employee config
└── server-methods/
    └── employees.ts               # workforce.employees.* handlers
```

**Config format** (in `~/.openclaw/config.yaml`):
```yaml
plugins:
  workforce:
    employees:
      - id: emma-web
        name: Emma
        title: Web Builder
        emoji: "🌐"
        description: Creates professional websites and landing pages
        agentId: emma-web
        capabilities: [websites, landing-pages, React, Tailwind]
      - id: david-decks
        name: David
        title: Deck Maker
        emoji: "📊"
        description: Creates professional presentation decks
        agentId: david-decks
        capabilities: [presentations, pitch-decks, data-visualization]
      - id: sarah-research
        name: Sarah
        title: Research Analyst
        emoji: "🔍"
        description: Deep research and competitive analysis
        agentId: sarah-research
        capabilities: [research, analysis, market-reports]
```

**RPC methods**:
```
workforce.employees.list()           → Employee[]     (with live status)
workforce.employees.get({ id })      → Employee
```

**Codebase integration**:
- Registration: `api.registerGatewayMethod("workforce.employees.list", handler)`
- Handler signature: `async (opts: { req, params, client, respond, context }) => Promise<void>`
- Response: `opts.respond({ ok: true, payload: employees })`
- Status derivation: check active agent runs to determine busy/online
- Agent workspace: `~/.openclaw/agents/<agentId>/` must exist for each employee

**Acceptance criteria (Backend)**:
- [ ] `workforce.employees.list` returns all configured employees with status
- [ ] `workforce.employees.get` returns single employee
- [ ] Status correctly shows busy when agent has active run
- [ ] Invalid config caught at load time (missing agentId, duplicates)

---

**Frontend Engineer**:

Update `EmployeeService` to call the real gateway method instead of mock data.

**Files to modify**:
```
apps/macos/Sources/Workforce/Services/EmployeeService.swift
```

**Change**:
```swift
func fetchEmployees() async throws {
    // BEFORE (Phase A): employees = Employee.mockEmployees
    // AFTER (Phase B):
    let result: [Employee] = try await gateway.call(
        method: "workforce.employees.list", params: nil
    )
    employees = result
}
```

**Acceptance criteria (Frontend)**:
- [ ] Gallery shows employees from gateway (not mock data)
- [ ] Status dots update in real-time (online/busy/offline)
- [ ] Gallery gracefully handles 0 employees (shows setup instructions)
- [ ] Gallery refreshes on reconnect

**Integration test**: Configure 3 employees in config.yaml, launch app, verify gallery shows all 3 with correct names/emoji/status.

---

### B-3: Task Store → Update Dashboard (Vertical Slice)

**What the user sees**: Tasks now survive app restarts. Close the app, reopen it, and all tasks are still there with their current state. The dashboard loads historical tasks.

**Backend Engineer**:

Build task manifest persistence.

**Files to create**:
```
extensions/workforce/src/
├── task-store.ts                  # CRUD for task manifests
├── task-types.ts                  # TaskManifest, TaskActivity types
└── server-methods/
    └── tasks.ts                   # workforce.tasks.* handlers
```

**Storage**: `~/.openclaw/tasks/<taskId>/task.json` — JSON manifest with atomic writes.

**Task manifest schema**:
```typescript
interface TaskManifest {
  id: string;
  employeeId: string;
  description: string;
  status: "pending" | "running" | "paused" | "completed" | "failed" | "cancelled";
  stage: "Clarify" | "Plan" | "Execute" | "Review" | "Deliver";
  progress: number;             // 0.0 to 1.0
  currentActivity?: string;
  activities: TaskActivity[];
  outputs: TaskOutput[];
  sessionKey: string;
  runId?: string;
  attachments: string[];
  sharedFolders: string[];
  createdAt: string;            // ISO 8601
  updatedAt: string;
  error?: string;
}
```

**RPC methods**:
```
workforce.tasks.get({ taskId })      → Task
workforce.tasks.list({ filter? })    → Task[]
```

**Acceptance criteria (Backend)**:
- [ ] `createTask()` creates directory + task.json
- [ ] `getTask(id)` reads and returns typed manifest
- [ ] `updateTask(id, patch)` atomically updates manifest
- [ ] `listTasks(filter?)` lists with optional status filter
- [ ] Tasks persist across gateway restarts
- [ ] Atomic writes prevent corruption

---

**Frontend Engineer**:

Update `TaskService` + `TaskDashboardView` to load tasks from gateway on launch.

**Files to modify**:
```
apps/macos/Sources/Workforce/Services/TaskService.swift
apps/macos/Sources/Workforce/Views/Tasks/TaskDashboardView.swift
```

**Change**:
```swift
func loadTasks() async throws {
    // BEFORE: tasks are in-memory only
    // AFTER: load from gateway on launch
    let result: [WorkforceTask] = try await gateway.call(
        method: "workforce.tasks.list", params: nil
    )
    tasks = result
}
```

**Acceptance criteria (Frontend)**:
- [ ] Dashboard loads historical tasks on app launch
- [ ] Tasks persist across app restarts
- [ ] Task list refreshes on reconnect
- [ ] Completed tasks show in "Completed" section

**Integration test**: Submit task, close app, reopen, verify task appears in dashboard with correct state.

---

### B-4: Task Runner + Event Bridge → Update Progress (Vertical Slice)

**What the user sees**: Task submission now goes through the workforce plugin (not raw `chat.send`). Progress events are structured with stage transitions, not just raw agent logs. The progress view gets richer.

**Backend Engineer**:

Build the task runner (wraps `runEmbeddedPiAgent`) and event bridge (maps agent events to structured task events).

**Files to create**:
```
extensions/workforce/src/
├── task-runner.ts                 # Task execution wrapper
├── event-bridge.ts                # Agent events → task events
└── server-methods/
    └── tasks.ts                   # Add workforce.tasks.submit
```

**Task runner flow**:
```typescript
async function runTask(taskId: string, employee: Employee): Promise<void> {
  const task = await taskStore.getTask(taskId);
  const sessionKey = `agent:${employee.agentId}:workforce-task-${taskId}`;

  const runId = await startAgentRun({
    agentId: employee.agentId,
    message: task.description,
    sessionKey,
  });

  await taskStore.updateTask(taskId, { status: "running", runId });
}
```

**Event bridge mapping**:
```
Agent Event              →  Task Event (broadcast)
────────────────────────────────────────────────
lifecycle.start          →  workforce.task.started
assistant (text chunk)   →  workforce.task.activity
tool (call)              →  workforce.task.activity (type: "tool")
tool (result)            →  workforce.task.activity (type: "action")
error                    →  workforce.task.failed
lifecycle.end            →  workforce.task.completed
```

**New RPC method**:
```
workforce.tasks.submit(TaskInput)   → Task   (creates manifest + starts agent run)
```

**Codebase integration**:
- `runEmbeddedPiAgent(params)` in `src/agents/pi-embedded-runner/run.ts`
- `onAgentEvent(listener)` from `src/infra/agent-events.ts`
- Broadcasting: `broadcastEvent({ event, payload })` from `src/gateway/server-broadcast.ts`
- Session key format: `agent:<agentId>:workforce-task-<taskId>`

**Acceptance criteria (Backend)**:
- [ ] `workforce.tasks.submit` creates manifest + starts agent run
- [ ] Agent events map to structured task events
- [ ] Task events broadcast to WebSocket clients
- [ ] Task manifest updates as events flow (status, activities, progress)
- [ ] Non-workforce agent runs unaffected

---

**Frontend Engineer**:

Update `TaskService` to use `workforce.tasks.submit` and subscribe to structured task events.

**Files to modify**:
```
apps/macos/Sources/Workforce/Services/TaskService.swift
apps/macos/Sources/Workforce/Views/Tasks/TaskProgressView.swift
```

**Change**:
```swift
func submitTask(employeeId: String, description: String) async throws -> WorkforceTask {
    // BEFORE: chat.send directly
    // AFTER: workforce.tasks.submit
    let task: WorkforceTask = try await gateway.call(
        method: "workforce.tasks.submit",
        params: ["employeeId": employeeId, "description": description]
    )
    tasks.append(task)
    return task
}

func observeEvents() {
    // Subscribe to workforce-specific events
    for await push in gateway.subscribe() {
        switch push.event {
        case "workforce.task.activity":
            updateTaskActivity(push.payload)
        case "workforce.task.completed":
            markTaskCompleted(push.payload)
        case "workforce.task.failed":
            markTaskFailed(push.payload)
        }
    }
}
```

**Acceptance criteria (Frontend)**:
- [ ] Task submission uses `workforce.tasks.submit`
- [ ] Progress view receives structured task events
- [ ] Activity log shows tool usage and agent thinking
- [ ] Task status updates automatically on completion/failure

**Integration test**: Submit task via app, verify structured events stream into progress view, verify manifest persists.

---

### B-5: System Prompt Hook → Test Employee Personality (Vertical Slice)

**What the user sees**: Each employee now has a distinct personality. Emma responds differently from David. They introduce themselves, ask relevant questions, and communicate in character.

**Backend Engineer**:

Build the `before_agent_start` hook that injects employee identity into the system prompt. Create identity files for each employee.

**Files to create**:
```
extensions/workforce/src/
└── hooks.ts                       # System prompt injection

~/.openclaw/agents/emma-web/
├── IDENTITY.md                    # Emma's personality + expertise
└── config.yaml                    # Model, tool allowlist

~/.openclaw/agents/david-decks/
├── IDENTITY.md
└── config.yaml

~/.openclaw/agents/sarah-research/
├── IDENTITY.md
└── config.yaml
```

**Hook implementation**:
```typescript
api.registerHook("before_agent_start", async (context) => {
  const taskId = extractTaskIdFromSessionKey(context.sessionKey);
  if (!taskId) return context; // Not a workforce run

  const task = await taskStore.getTask(taskId);
  const employee = await registry.getEmployee(task.employeeId);

  context.systemPrompt = [
    context.systemPrompt,
    `\n## Your Identity\nYou are ${employee.name}, ${employee.title}. ${employee.description}`,
    `\n## Current Task\n${task.description}`,
  ].join('');

  return context;
});
```

**Acceptance criteria (Backend)**:
- [ ] Hook injects employee identity when workforce task runs
- [ ] Each employee agent has IDENTITY.md
- [ ] Non-workforce runs unaffected by hook

---

**Frontend Engineer**: No code changes needed. The personality shows up automatically in the activity log and agent responses.

**Integration test**: Submit same task ("Write me a haiku") to Emma and David. Verify responses have different personalities — Emma responds as a web developer, David as a presentations expert.

---

### B-6: Stage Heuristics → Update Stage Indicator (Vertical Slice)

**What the user sees**: The 5-stage progress indicator (Clarify → Plan → Execute → Review → Deliver) now updates dynamically as the employee works. Checkmarks appear as stages complete.

**Backend Engineer**:

Add rule-based stage detection in the event bridge.

**Files to modify**:
```
extensions/workforce/src/event-bridge.ts
```

**Heuristic rules**:
```
Task starts                        → Clarify
Agent asks question (? detected)   → stay in Clarify
Agent says "plan"/"approach"/"I'll" → Plan
First tool call (write_file, bash) → Execute
Agent says "review"/"check"/"test" → Review
Agent produces final summary       → Deliver
```

**Constraints**: Stages only move forward, never backward.

**Acceptance criteria (Backend)**:
- [ ] Tasks start in Clarify stage
- [ ] Stage transitions emit `workforce.task.stage` events
- [ ] All 5 stages reachable for typical tasks
- [ ] Stages never go backward

---

**Frontend Engineer**:

Update `StageIndicatorView` to react to stage events.

**Files to modify**:
```
apps/macos/Sources/Workforce/Views/Tasks/StageIndicatorView.swift
```

**Change**: Wire stage from static "Execute" to dynamic value from task events.

**Acceptance criteria (Frontend)**:
- [ ] Stage indicator highlights current stage
- [ ] Completed stages show checkmarks
- [ ] Pending stages show empty circles
- [ ] Stage transitions animate smoothly

**Integration test**: Submit a task, watch the stage indicator progress through Clarify → Plan → Execute → Review → Deliver.

---

### B-7: Task Controls → Wire Pause/Resume/Cancel (Vertical Slice)

**What the user sees**: Pause, Resume, and Cancel buttons actually work. User can pause a long task, resume it later, or cancel if going wrong.

**Backend Engineer**:

Add task control RPC methods.

**Files to modify**:
```
extensions/workforce/src/server-methods/tasks.ts
```

**Methods**:
```
workforce.tasks.cancel({ taskId })   → void
workforce.tasks.pause({ taskId })    → void
workforce.tasks.resume({ taskId })   → void
```

**Implementation**:
- Cancel: stop agent run, update manifest to `cancelled`
- Pause: stop agent run, save state in manifest as `paused`
- Resume: start new agent run in same session (context preserved)

**Acceptance criteria (Backend)**:
- [ ] Cancel stops agent and updates manifest
- [ ] Pause stops agent and sets status to `paused`
- [ ] Resume starts new run with session context
- [ ] Paused tasks survive gateway restart

---

**Frontend Engineer**:

Wire the control buttons in `TaskControlsView`.

**Files to modify**:
```
apps/macos/Sources/Workforce/Views/Tasks/TaskControlsView.swift
```

**Change**: Buttons call `workforce.tasks.cancel/pause/resume` instead of being disabled placeholders.

**Acceptance criteria (Frontend)**:
- [ ] Cancel button stops the task and shows "Cancelled" state
- [ ] Pause button pauses and shows "Paused" state with "Resume" button
- [ ] Resume button restarts the task from where it left off
- [ ] Buttons disabled when not applicable (can't pause a completed task)

**Integration test**: Submit task, click Pause, verify it stops. Click Resume, verify it continues.

---

## Phase C: Outputs & Feedback

**Goal**: Employees produce visible deliverables. Users see previews, rate work, and request changes. Each ticket is a vertical slice tested in the app.

---

### C-1: Output Manager + Output Viewer (Vertical Slice)

**What the user sees**: When a task completes, the output section shows what was created — files, websites, documents. Each output has a thumbnail and actions (Open in Finder, Open in Browser).

**Backend Engineer**:

Build output tracking via `after_tool_call` hook.

**Files to create**:
```
extensions/workforce/src/
└── output-manager.ts              # Output detection + tracking
```

**Detection**: Hook into `after_tool_call`, inspect tool results for file paths. Classify by extension (`.html` → website, `.png` → image, `.md` → document). Register in task manifest `outputs` array.

**Acceptance criteria (Backend)**:
- [ ] Files created by agent are detected and registered
- [ ] Output type classified correctly
- [ ] `workforce.task.output` event broadcast
- [ ] Outputs appear in task manifest

---

**Frontend Engineer**:

Build output viewer.

**Files to create**:
```
apps/macos/Sources/Workforce/Views/Outputs/
├── OutputViewerView.swift         # Output list for a task
├── OutputCardView.swift           # Single output card
└── OutputPreviewView.swift        # Preview (image/text)
```

**Layout**: Grid of output cards. Each card: icon based on type, filename, "Open in Finder" / "Open in Browser" buttons.

**Acceptance criteria (Frontend)**:
- [ ] Outputs display when task completes
- [ ] File type icons (website, image, document, code)
- [ ] "Open in Finder" opens file location
- [ ] "Open in Browser" opens .html files in default browser
- [ ] Empty state when no outputs

**Integration test**: Have Emma build an HTML file. Verify output card appears with correct file type. Click "Open in Finder", verify file opens.

---

### C-2: HTTP Previews + Swift Preview Loading (Vertical Slice)

**What the user sees**: Output cards show thumbnail previews — a screenshot for websites, a thumbnail for images, a text excerpt for documents. Not just file icons.

**Backend Engineer**:

Add HTTP preview endpoints. Uses query params (not path params) due to OpenClaw's exact-path route matching.

**Files to create**:
```
extensions/workforce/src/
└── http-routes.ts                 # Preview + file endpoints
```

**Endpoints**:
```
GET /workforce/preview?taskId=X&outputId=Y    → thumbnail/excerpt
GET /workforce/file?taskId=X&outputId=Y       → full file
```

**Acceptance criteria (Backend)**:
- [ ] Preview returns resized image for image outputs
- [ ] Preview returns text excerpt for document outputs
- [ ] File endpoint returns full file with correct Content-Type
- [ ] 404 for unknown task/output

---

**Frontend Engineer**:

Load previews via HTTP in output cards.

**Files to modify**:
```
apps/macos/Sources/Workforce/Views/Outputs/OutputCardView.swift
```

**Change**: `AsyncImage` loads preview from `http://localhost:18789/workforce/preview?taskId=X&outputId=Y`

**Acceptance criteria (Frontend)**:
- [ ] Image outputs show thumbnail preview
- [ ] Document outputs show text excerpt
- [ ] Loading state shown while preview loads
- [ ] Fallback to file icon if preview fails

**Integration test**: Submit task that creates an HTML file. Verify preview thumbnail appears in output card.

---

### C-3: Feedback System (Vertical Slice)

**What the user sees**: After task completion, a feedback section appears. Star rating (1-5), optional comment, and a "Request Changes" button that starts a revision with full context.

**Backend Engineer**:

Build feedback storage and revision flow.

**Files to create**:
```
extensions/workforce/src/
└── feedback.ts                    # Feedback storage + revision
```

**Methods**:
```
workforce.tasks.feedback({ taskId, rating, comment })  → void
workforce.tasks.revise({ taskId, changes })            → Task
```

**Revision**: Starts a new agent run in the SAME session (same `sessionKey`), so the agent has full context from the original task.

**Acceptance criteria (Backend)**:
- [ ] Feedback persisted in task manifest
- [ ] Revision starts new run in same session
- [ ] Revised task keeps history of original task

---

**Frontend Engineer**:

Build feedback UI.

**Files to create**:
```
apps/macos/Sources/Workforce/Views/Tasks/
└── FeedbackView.swift             # Rating + comment + revise
```

**Layout**: Star rating, text field for comments, "Request Changes" button, "Mark Complete" button.

**Acceptance criteria (Frontend)**:
- [ ] 1-5 star rating clickable
- [ ] Comment text field
- [ ] "Request Changes" opens revision input
- [ ] Revision shows as continuation in same task

**Integration test**: Complete a task, rate it 3 stars, click "Request Changes", type a revision, verify agent runs again with context.

---

## Phase D: Memory & Polish

**Goal**: Employees remember preferences, the app handles errors gracefully, and everything feels premium.

---

### D-1: Memory Integration

**What the user sees**: "Last time you preferred blue..." — employees reference past work and preferences without being told.

**Backend Engineer**: Integrate `extensions/memory-core` plugin. Memory is already per-agent (isolated per employee). Surface memory summary via `workforce.employees.memory({ employeeId })`.

**Frontend Engineer**: Show memory summary in employee detail popover. "Emma remembers: prefers React, blue/white color schemes, Vercel deployment."

---

### D-2: Employee Customization

**What the user sees**: In Settings → Employees, users can edit personality, toggle tool permissions, and adjust communication style.

**Backend Engineer**: `workforce.employees.update({ id, identity, tools })` → writes IDENTITY.md + config.yaml.

**Frontend Engineer**: Employee settings view with editable personality description and tool toggles.

---

### D-3: Task History + Search

**What the user sees**: Full searchable history — "What did Emma build last week?" Filter by employee, date, status.

**Frontend Engineer**: Search bar + filters in dashboard. Uses `workforce.tasks.list` with filter params.

---

### D-4: Error Recovery

**What the user sees**: Helpful error messages with recovery actions everywhere. Never "Error occurred" with no next step.

**Both engineers**: Comprehensive error handling across all views and RPC calls. Every error state has a recovery action.

---

### D-5: Visual Polish

**What the user sees**: Premium macOS app. Smooth animations, dark mode, loading skeletons, keyboard navigation.

**Frontend Engineer**: Animations, dark mode, accessibility labels, menu bar badge for active tasks.

---

## Dependency Graph

```
PHASE A (Frontend Only — Existing Backend)
A-1 (Project Setup)
 └── A-2 (Gateway Connection)
      └── A-3 (Models + Mock Data)
           ├── A-4 (Employee Gallery)
           │    └── A-5 (Task Input)
           │         └── A-6 (Progress View)
           └── A-7 (Task Dashboard)
      └── A-8 (Settings + Shell)
A-9 (Integration Test)

PHASE B (Backend + Frontend Vertical Slices)
B-1 (Plugin Scaffold)
 ├── B-2 (Employee Registry → Gallery Update)
 ├── B-3 (Task Store → Dashboard Update)
 └── B-4 (Task Runner + Events → Progress Update)
      ├── B-5 (System Prompt Hook → Personality Test)
      ├── B-6 (Stage Heuristics → Stage Indicator)
      └── B-7 (Task Controls → Pause/Resume/Cancel)

PHASE C (Outputs & Feedback — Vertical Slices)
C-1 (Output Manager + Viewer)
 └── C-2 (HTTP Previews + Swift Loading)
C-3 (Feedback System)

PHASE D (Memory & Polish)
D-1 → D-2 → D-3 → D-4 → D-5
```

## Execution Order

| Order | Ticket | Engineer | What Changes Visually |
|-------|--------|----------|----------------------|
| 1 | A-1 | Frontend | Desktop window appears |
| 2 | A-2 | Frontend | Gateway connection + status indicator |
| 3 | A-3 | Frontend | Data models + mock employees |
| 4 | A-4 | Frontend | Employee gallery with mock cards |
| 5 | A-5 | Frontend | Task input panel |
| 6 | A-6 | Frontend | Real-time progress view |
| 7 | A-7 | Frontend | Task dashboard |
| 8 | A-8 | Frontend | Settings + app shell polish |
| 9 | A-9 | Both | End-to-end test (existing gateway) |
| 10 | B-1 | Backend | Plugin loads (no visual change) |
| 11 | B-2 | Backend → Frontend | Gallery shows REAL employees from gateway |
| 12 | B-3 | Backend → Frontend | Tasks persist across restarts |
| 13 | B-4 | Backend → Frontend | Structured progress events |
| 14 | B-5 | Backend | Employees have distinct personalities |
| 15 | B-6 | Backend → Frontend | Stage indicator updates dynamically |
| 16 | B-7 | Backend → Frontend | Pause/Resume/Cancel work |
| 17 | C-1 | Backend → Frontend | Output viewer shows files |
| 18 | C-2 | Backend → Frontend | Preview thumbnails |
| 19 | C-3 | Backend → Frontend | Rating + revision flow |
| 20-24 | D-* | Both | Memory, customization, polish |

## Open Decisions

1. **Separate Xcode target vs separate project?** Recommendation: New target in existing `apps/macos/` project to share `OpenClawKit` dependency easily.

2. **Keep menu bar app alongside desktop window?** Recommendation: Yes — menu bar shows status + quick actions, desktop window is the full experience. They share the same gateway connection.

3. **Agent per employee or shared agent?** Recommendation: Separate agent per employee (1:1) for memory and personality isolation. Each needs `~/.openclaw/agents/<agentId>/` directory.

4. **Phase A mock data — hardcoded or JSON file?** Recommendation: Hardcoded Swift static properties. Simple, no file I/O, easy to swap for gateway calls in Phase B.
