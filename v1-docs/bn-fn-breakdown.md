# Workforce: Backend & Frontend Integration Breakdown

**Date**: February 2, 2026
**Status**: Phase A complete (29 source files, mock data, `chat.send`/`chat.abort`). This document defines the exact integration work to close the gap to a fully functional product.

## How This Document Works

For each feature:
1. **What's Built** — Current Phase A state
2. **Backend Gap** — Exact plugin methods, hooks, events to add (TypeScript, `extensions/workforce/`)
3. **Frontend Gap** — Exact Swift files to create/modify (`apps/macos/Sources/Workforce/`)
4. **Integration Wire** — How backend events map to frontend state changes
5. **Done When** — Acceptance criteria

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Workforce Desktop App (SwiftUI + AppKit)                     │
│                                                               │
│  WorkforceGateway (actor)                                     │
│    └─ request(method:params:) → Data                         │
│    └─ requestDecoded<T>(method:params:) → T                  │
│    └─ subscribe() → AsyncStream<GatewayPush>                 │
│                                                               │
│  Services: EmployeeService, TaskService (all @Observable)    │
│  Navigation: MainWindowView routes via TaskFlowState enum    │
└──────────────────────────┬───────────────────────────────────┘
                           │ WebSocket (JSON-RPC)
                           ▼
┌──────────────────────────────────────────────────────────────┐
│  OpenClaw Gateway                                             │
│                                                               │
│  extensions/workforce/ (NEW PLUGIN)                           │
│    ├─ api.registerGatewayMethod("workforce.*", handler)      │
│    ├─ api.registerHook("before_agent_start", handler)        │
│    ├─ onAgentEvent(listener) → event bridge                  │
│    └─ context.broadcast("workforce.task.*", payload)         │
│                                                               │
│  Existing Core (UNCHANGED):                                   │
│    ├─ Agent Runtime (chat.send, chat.abort)                  │
│    ├─ Session Manager (sessions.list)                         │
│    └─ Agent Events (onAgentEvent, emitAgentEvent)            │
└──────────────────────────────────────────────────────────────┘
```

### Protocol Format

```json
// Request (Swift → Gateway)
{ "type": "req", "id": "uuid", "method": "workforce.tasks.create", "params": {...} }

// Response (Gateway → Swift)
{ "type": "res", "id": "uuid", "ok": true, "payload": {...} }

// Event broadcast (Gateway → all clients)
{ "type": "event", "event": "workforce.task.activity", "payload": {...}, "seq": 42 }
```

### Plugin Handler Signature (TypeScript)

```typescript
api.registerGatewayMethod("workforce.method.name", async ({ params, respond, context }) => {
  // params: Record<string, unknown> — parsed from request
  // respond(ok: boolean, payload?: unknown, error?: { code, message }) — send response
  // context.broadcast(event: string, payload: unknown) — push to all clients
});
```

### Swift Gateway Call Pattern

```swift
// Typed request → decoded response
let result: SomeResponse = try await gateway.requestDecoded(
    method: "workforce.tasks.create",
    params: ["employeeId": AnyCodable(id), "brief": AnyCodable(text)])

// Event subscription
for await push in gateway.subscribe() {
    guard case let .event(frame) = push else { continue }
    guard frame.event.hasPrefix("workforce.") else { continue }
    // handle structured workforce events
}
```

---

## Architectural Decisions

### 1. Clarification: Structured Questions API (not conversational)

The plugin returns clarification questions as a typed JSON array with `type` (single/multiple/text/file), `options[]`, and `required` flags. The Swift frontend renders native form controls (Picker, Toggle list, TextEditor, file picker). This gives deterministic validation, testable UI, and clean UX.

The agent can still generate questions dynamically — the plugin parses the agent's response into structured form before returning to the client.

### 2. Plan: Structured Plan Object (not conversational)

The plugin returns a plan as `{ summary, steps[], estimatedTime }`. The frontend renders it as a numbered list with approve/reject buttons. Plan iterations (reject with feedback) produce a new plan object.

### 3. Event Bridge: Plugin listener on `onAgentEvent`

The workforce plugin registers a global `onAgentEvent()` listener that:
1. Filters by `sessionKey.startsWith("workforce-")`
2. Looks up the task in the task store by session key
3. Transforms raw agent events into structured `workforce.task.*` events
4. Broadcasts via `context.broadcast()`

The existing `chat.*` events still flow untouched. The Swift frontend switches from `chat.*` to `workforce.task.*`.

### 4. Mock-to-Real: Graceful Fallback (no feature flags)

`EmployeeService.fetchEmployees()` calls the gateway method. On failure (plugin not loaded), falls back to `Employee.mockEmployees`. Mock data stays compiled in as a safety net.

### 5. Navigation: TaskFlowState Enum

Replace `selectedEmployee` + `activeTaskId` in `MainWindowView` with:

```swift
enum TaskFlowState {
    case idle
    case input(employee: Employee)
    case clarifying(task: WorkforceTask, questions: ClarificationPayload)
    case planning(task: WorkforceTask, plan: PlanPayload)
    case executing(taskId: String)
    case reviewing(taskId: String)
}
```

---

## Feature 1.1: App Launch & Connection

### Status: COMPLETE

No work needed. Everything built in Phase A:

| Component | File | State |
|-----------|------|-------|
| Gateway actor | `Services/WorkforceGateway.swift` | Wraps `GatewayChannelActor`, `connect()`, `request()`, `subscribe()` |
| Gateway service | `Services/WorkforceGatewayService.swift` | `@Observable @MainActor`, ConnectionState enum, auto-reconnect 3s |
| Status bar | `Views/StatusBarView.swift` | Green/yellow/red dot + label |
| Error screen | `Views/GatewayNotRunningView.swift` | Full-screen error with retry button |
| Settings | `Views/Settings/GatewaySettingsView.swift` | Port + token config via `@AppStorage` |
| App entry | `WorkforceApp.swift` | Connects on launch via `.task { await gatewayService.connect() }` |

**Optional enhancement**: Add `reconnectAttempts` counter to `WorkforceGatewayService`. Stop after 5 attempts, show manual retry. Currently reconnects forever.

### Done When
- [x] App connects on launch, shows green dot
- [x] Disconnection shows reconnecting state
- [x] Gateway offline shows error with retry
- [x] Settings allow port/token configuration

---

## Feature 1.2: Employee Selection (Mock → Real)

### What's Built

| Component | File | State |
|-----------|------|-------|
| Model | `Models/Employee.swift` | id, name, title, emoji, description, status, capabilities |
| Service | `Services/EmployeeService.swift` | `fetchEmployees()` returns `Employee.mockEmployees` (3 hardcoded) |
| Gallery | `Views/Employees/EmployeeGalleryView.swift` | Grid with search, loading state, calls `fetchEmployees()` on appear |
| Card | `Views/Employees/EmployeeCardView.swift` | Emoji, name, title, status badge, hover effects |

### Backend Gap

**File**: `extensions/workforce/src/server-methods/employees.ts`

**Method**: `workforce.employees.list`

```typescript
api.registerGatewayMethod("workforce.employees.list", async ({ params, respond, context }) => {
  const config = api.pluginConfig as WorkforceConfig;
  const employees = config.employees.map(emp => ({
    id: emp.id,
    name: emp.name,
    title: emp.title,
    emoji: emp.emoji,
    description: emp.description,
    capabilities: emp.capabilities,
    status: taskStore.isEmployeeBusy(emp.id) ? "busy" : "online",
    currentTaskId: taskStore.getActiveTaskForEmployee(emp.id)?.id ?? null,
    avatarSystemName: "person.circle.fill",
  }));
  respond(true, { employees });
});
```

**Config** (in `~/.openclaw/config.yaml`):
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

**Employee status broadcast** (emitted by `workforce.tasks.create`, `workforce.task.completed`, `workforce.tasks.cancel`):

```typescript
context.broadcast("workforce.employee.status", {
  employeeId: emp.id,
  status: "busy", // or "online"
  currentTaskId: task.id, // or null
});
```

### Frontend Gap

**Modify**: `Sources/Workforce/Models/Employee.swift`
- Add `var currentTaskId: String?` (optional, defaults to `nil`)

**Modify**: `Sources/Workforce/Services/EmployeeService.swift`

```swift
// Add gateway reference
private let gateway: WorkforceGateway

// Change fetchEmployees()
func fetchEmployees() async {
    self.isLoading = true
    do {
        let response: EmployeeListResponse = try await self.gateway.requestDecoded(
            method: "workforce.employees.list")
        self.employees = response.employees
    } catch {
        Self.logger.warning("Gateway fetch failed, using mock data: \(error)")
        if self.employees.isEmpty {
            self.employees = Employee.mockEmployees
        }
    }
    self.isLoading = false
}

// Add real-time status updates
func startStatusListener() async {
    let stream = await self.gateway.subscribe()
    for await push in stream {
        guard case let .event(frame) = push,
              frame.event == "workforce.employee.status",
              let payload = frame.payload?.value as? [String: Any],
              let employeeId = payload["employeeId"] as? String,
              let statusRaw = payload["status"] as? String,
              let index = self.employees.firstIndex(where: { $0.id == employeeId })
        else { continue }
        await MainActor.run {
            self.employees[index].status = EmployeeStatus(rawValue: statusRaw) ?? .unknown
            self.employees[index].currentTaskId = payload["currentTaskId"] as? String
        }
    }
}
```

**Create**: `Sources/Workforce/Models/EmployeeListResponse.swift`
```swift
struct EmployeeListResponse: Codable {
    let employees: [Employee]
}
```

### Integration Wire

```
Frontend                               Backend
   │                                      │
   ├─ workforce.employees.list ──────────►│ Load config + check task store
   │◄─ { employees: [...] } ─────────────┤
   │                                      │
   │  (when task starts or completes)     │
   │◄─ workforce.employee.status ─────────┤ { employeeId, status, currentTaskId }
   │  Update employee in-place            │
```

### Done When
- [ ] Gallery shows employees from gateway (not mock)
- [ ] Status dots update in real-time when tasks start/complete
- [ ] Gallery falls back to mock data when plugin not loaded
- [ ] Gallery refreshes on reconnect

---

## Feature 1.3: Task Briefing / Input (Structured Submission)

### What's Built

| Component | File | State |
|-----------|------|-------|
| View | `Views/Tasks/TaskInputView.swift` | Text area, file picker, submit button, employee header |
| Service | `Services/TaskService.swift` | `submitTask()` calls `chat.send` with sessionKey, creates local `WorkforceTask` |
| Model | `Models/WorkforceTask.swift` | Full task model with status, stage, progress, activities |

### Backend Gap

**File**: `extensions/workforce/src/server-methods/tasks.ts`

**Method**: `workforce.tasks.create`

```typescript
api.registerGatewayMethod("workforce.tasks.create", async ({ params, respond, context }) => {
  const { employeeId, brief, attachments } = params as {
    employeeId: string;
    brief: string;
    attachments?: Array<{ name: string; path: string }>;
  };

  // Validate employee exists
  const employee = registry.getEmployee(employeeId);
  if (!employee) {
    respond(false, undefined, { code: -1, message: `Employee ${employeeId} not found` });
    return;
  }

  // Create task manifest
  const taskId = crypto.randomUUID();
  const sessionKey = `workforce-${employeeId}-${taskId.slice(0, 8)}`;
  const task = taskStore.create({
    id: taskId,
    employeeId,
    description: brief,
    status: "clarifying",
    stage: "clarify",
    progress: 0,
    sessionKey,
    attachments: attachments ?? [],
    createdAt: new Date().toISOString(),
  });

  // Determine if clarification needed
  const needsClarification = employee.clarificationQuestions?.length > 0;

  if (needsClarification) {
    respond(true, {
      task,
      clarification: { questions: employee.clarificationQuestions },
    });
  } else {
    // Generate plan (short agent call or rule-based)
    const plan = await generatePlan(employee, brief);
    task.status = "planning";
    task.stage = "plan";
    taskStore.update(task);
    respond(true, { task, plan });
  }

  // Broadcast employee status change
  context.broadcast("workforce.employee.status", {
    employeeId,
    status: "busy",
    currentTaskId: task.id,
  });
});
```

### Frontend Gap

**Create**: `Sources/Workforce/Models/TaskFlowModels.swift`

```swift
struct TaskCreateResponse: Codable {
    let task: WorkforceTask
    let clarification: ClarificationPayload?
    let plan: PlanPayload?
}

struct TaskCreateResult {
    let task: WorkforceTask
    let clarification: ClarificationPayload?
    let plan: PlanPayload?
}
```

**Modify**: `Sources/Workforce/Services/TaskService.swift`

```swift
// Replace submitTask() — from chat.send to workforce.tasks.create
func submitTask(employeeId: String, description: String, attachments: [URL] = []) async throws -> TaskCreateResult {
    let attachmentParams: [[String: AnyCodable]] = attachments.map { url in
        ["name": AnyCodable(url.lastPathComponent), "path": AnyCodable(url.path)]
    }
    let params: [String: AnyCodable] = [
        "employeeId": AnyCodable(employeeId),
        "brief": AnyCodable(description),
        "attachments": AnyCodable(attachmentParams),
    ]
    let response: TaskCreateResponse = try await self.gateway.requestDecoded(
        method: "workforce.tasks.create", params: params)
    self.tasks.insert(response.task, at: 0)
    return TaskCreateResult(
        task: response.task,
        clarification: response.clarification,
        plan: response.plan)
}
```

**Modify**: `Sources/Workforce/Views/Tasks/TaskInputView.swift`
- Pass `self.attachments` URLs to `taskService.submitTask(employeeId:description:attachments:)`
- Change `onTaskSubmitted` callback to accept `TaskCreateResult` (not just `WorkforceTask`)

**Modify**: `Sources/Workforce/MainWindowView.swift`
- After submission, route based on result:
  - `result.clarification != nil` → `.clarifying(task, questions)`
  - `result.plan != nil` → `.planning(task, plan)`
  - Neither → `.executing(taskId)` + start `observeTask()`

### Integration Wire

```
Frontend                               Backend
   │  User clicks "Assign to Emma"       │
   │                                      │
   ├─ workforce.tasks.create ────────────►│ Create manifest, check clarification
   │  { employeeId, brief, attachments }  │
   │                                      │
   │◄─ { task, clarification } ───────────┤ (if questions needed)
   │  Show ClarificationView              │
   │                                      │
   │  OR                                  │
   │◄─ { task, plan } ───────────────────┤ (if no clarification)
   │  Show PlanView                       │
```

### Done When
- [ ] Submit calls `workforce.tasks.create` (not `chat.send`)
- [ ] Attachments are sent to backend
- [ ] Response routes to clarification or plan view
- [ ] Loading state shown during submission
- [ ] Error handling with user-visible message

---

## Feature 1.4: Clarification Questions (NEW)

### What's Built

Nothing. This is entirely new.

### Backend Gap

**Method**: `workforce.tasks.clarify`

```typescript
api.registerGatewayMethod("workforce.tasks.clarify", async ({ params, respond, context }) => {
  const { taskId, answers } = params as {
    taskId: string;
    answers: Array<{ questionId: string; value: unknown }>;
  };

  const task = taskStore.get(taskId);
  if (!task) {
    respond(false, undefined, { code: -1, message: "Task not found" });
    return;
  }

  // Store answers in task manifest
  task.clarificationAnswers = [...(task.clarificationAnswers || []), ...answers];
  taskStore.update(task);

  // Check if more clarification needed (employee-specific logic)
  const followUp = await checkFollowUpQuestions(task, answers);

  if (followUp.questions.length > 0) {
    respond(true, {
      task,
      clarification: { questions: followUp.questions },
    });
  } else {
    // Generate plan from brief + answers
    const plan = await generatePlan(task);
    task.status = "planning";
    task.stage = "plan";
    taskStore.update(task);
    respond(true, { task, plan });
  }
});
```

**Question types** (defined per employee in config):

| Type | Answer Format | Description |
|------|--------------|-------------|
| `single` | `"option-id"` (string) | Radio button group — one selection |
| `multiple` | `["opt1", "opt2"]` (string array) | Checkbox group — multiple selections |
| `text` | `"free text"` (string) | Text area for freeform input |
| `file` | `{ name, path }` (object) | File upload |

### Frontend Gap

**Create**: `Sources/Workforce/Models/ClarificationQuestion.swift`

```swift
struct ClarificationPayload: Codable, Sendable {
    let questions: [ClarificationQuestion]
}

struct ClarificationQuestion: Identifiable, Codable, Sendable {
    let id: String
    let text: String
    let type: QuestionType
    let required: Bool
    let options: [QuestionOption]?
}

enum QuestionType: String, Codable, Sendable {
    case single, multiple, text, file, unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = QuestionType(rawValue: raw) ?? .unknown
    }
}

struct QuestionOption: Identifiable, Codable, Sendable {
    let id: String
    let label: String
    let value: String
    var selected: Bool?
}

struct ClarificationAnswer: Codable, Sendable {
    let questionId: String
    let value: ClarificationValue
}

enum ClarificationValue: Codable, Sendable {
    case string(String)
    case array([String])
    case file(name: String, path: String)
}
```

**Create**: `Sources/Workforce/Views/Tasks/ClarificationView.swift`

Layout:
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│   🌐 Emma needs a few more details:                             │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│                                                                  │
│   What pages do you need? *                                     │
│   ☑️ Home/Landing    ☐ About    ☑️ Contact    ☑️ Services       │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│                                                                  │
│   Do you have brand assets? *                                   │
│   ○ Yes, I'll upload them    ● No, suggest something            │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│                                                                  │
│   Any specific requirements?                                    │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ I want it to feel premium and trustworthy               │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│                                         ┌──────────────────┐   │
│                                         │    Continue →     │   │
│                                         └──────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

UI components by question type:
- `single` → `Picker` with `.radioGroup` style
- `multiple` → `ForEach` of `Toggle` checkboxes
- `text` → `TextEditor` with placeholder
- `file` → Button opening `NSOpenPanel`

Validation: Required questions marked with `*`. Continue button disabled until all required answered. Inline error on unanswered required questions.

**Modify**: `Sources/Workforce/Services/TaskService.swift`

```swift
func submitClarification(taskId: String, answers: [ClarificationAnswer]) async throws -> TaskCreateResult {
    let params: [String: AnyCodable] = [
        "taskId": AnyCodable(taskId),
        "answers": AnyCodable(answers.map { /* encode to dict */ }),
    ]
    let response: TaskCreateResponse = try await self.gateway.requestDecoded(
        method: "workforce.tasks.clarify", params: params)
    if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
        self.tasks[index] = response.task
    }
    return TaskCreateResult(task: response.task, clarification: response.clarification, plan: response.plan)
}
```

### Integration Wire

```
Frontend                               Backend
   │                                      │
   │  (from tasks.create with questions)  │
   │  Render ClarificationView            │
   │                                      │
   │  User answers questions              │
   │                                      │
   ├─ workforce.tasks.clarify ───────────►│ Store answers, check follow-up
   │  { taskId, answers[] }               │
   │                                      │
   │◄─ { task, clarification } ───────────┤ (more questions → loop)
   │  OR                                  │
   │◄─ { task, plan } ───────────────────┤ (done → PlanView)
```

### Done When
- [ ] Questions render correctly by type (single/multiple/text/file)
- [ ] Required questions enforced — cannot submit without answers
- [ ] Answers submitted to backend
- [ ] Multiple rounds of questions work (loop)
- [ ] Transitions to plan when clarification complete

---

## Feature 1.5: Plan Presentation (NEW)

### What's Built

Nothing. This is entirely new.

### Backend Gap

**Method**: `workforce.tasks.approve`

```typescript
api.registerGatewayMethod("workforce.tasks.approve", async ({ params, respond, context }) => {
  const { taskId, approved, feedback } = params as {
    taskId: string;
    approved: boolean;
    feedback?: string;
  };

  const task = taskStore.get(taskId);
  if (!task) {
    respond(false, undefined, { code: -1, message: "Task not found" });
    return;
  }

  if (approved) {
    // Start execution
    task.status = "running";
    task.stage = "execute";
    task.progress = 0;
    taskStore.update(task);

    // Start agent run (non-blocking)
    startExecution(task, context);

    respond(true, { task });
  } else {
    // Regenerate plan with feedback
    const newPlan = await regeneratePlan(task, feedback);
    respond(true, { task, plan: newPlan });
  }
});
```

### Frontend Gap

**Create**: `Sources/Workforce/Models/Plan.swift`

```swift
struct PlanPayload: Codable, Sendable {
    let summary: String
    let steps: [PlanStep]
    let estimatedTime: Int // seconds
}

struct PlanStep: Identifiable, Codable, Sendable {
    let id: String
    let description: String
    let estimatedTime: Int? // seconds
}
```

**Create**: `Sources/Workforce/Views/Tasks/PlanView.swift`

Layout:
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│   🌐 Emma's plan:                                               │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│                                                                  │
│   "I'll create a 3-page website with home, contact, and        │
│    services pages. Modern dark theme with a contact form."      │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│                                                                  │
│   Steps:                                                        │
│   1. Set up project structure                          ~30s     │
│   2. Build home page with hero section                 ~60s     │
│   3. Build contact page with form                      ~45s     │
│   4. Build services page                               ~45s     │
│   5. Style and polish                                  ~30s     │
│   6. Deploy to live URL                                ~30s     │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│   Estimated time: ~4 minutes                                    │
│                                                                  │
│   ┌───────────────────┐            ┌────────────────────────┐  │
│   │  Request changes   │            │  Looks good, start →   │  │
│   └───────────────────┘            └────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

"Request changes" flow:
1. Button reveals text field: "What would you like to change?"
2. User types feedback
3. Submit calls `rejectPlan(taskId:feedback:)`
4. New plan returned, view updates

**Modify**: `Sources/Workforce/Services/TaskService.swift`

```swift
func approvePlan(taskId: String) async throws -> WorkforceTask {
    let params: [String: AnyCodable] = [
        "taskId": AnyCodable(taskId),
        "approved": AnyCodable(true),
    ]
    let response: TaskCreateResponse = try await self.gateway.requestDecoded(
        method: "workforce.tasks.approve", params: params)
    if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
        self.tasks[index] = response.task
    }
    return response.task
}

func rejectPlan(taskId: String, feedback: String) async throws -> TaskCreateResult {
    let params: [String: AnyCodable] = [
        "taskId": AnyCodable(taskId),
        "approved": AnyCodable(false),
        "feedback": AnyCodable(feedback),
    ]
    let response: TaskCreateResponse = try await self.gateway.requestDecoded(
        method: "workforce.tasks.approve", params: params)
    if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
        self.tasks[index] = response.task
    }
    return TaskCreateResult(task: response.task, clarification: nil, plan: response.plan)
}
```

### Integration Wire

```
Frontend                               Backend
   │                                      │
   │  (plan from tasks.clarify)           │
   │  Show PlanView                       │
   │                                      │
   │  User clicks "Looks good, start"     │
   ├─ workforce.tasks.approve ───────────►│ Start agent execution
   │  { taskId, approved: true }          │
   │◄─ { task: { status: "running" } } ──┤
   │  → TaskProgressView + observeTask()  │
   │                                      │
   │  User clicks "Request changes"       │
   ├─ workforce.tasks.approve ───────────►│ Regenerate plan
   │  { taskId, approved: false,          │
   │    feedback: "..." }                 │
   │◄─ { task, plan: {new plan} } ───────┤
   │  → Update PlanView with new plan     │
```

### Done When
- [ ] Plan displays summary, steps, time estimate
- [ ] Approve starts execution
- [ ] Reject with feedback gets new plan
- [ ] Multiple plan iterations work
- [ ] Smooth transition to progress view on approve

---

## Feature 1.6: Execution Progress (Refactor to Structured Events)

### What's Built

| Component | File | State |
|-----------|------|-------|
| Progress view | `Views/Tasks/TaskProgressView.swift` | Employee header, stage indicator, progress bar, activity log, cancel |
| Activity log | `Views/Tasks/ActivityLogView.swift` | Scrolling feed, auto-scroll, type icons |
| Stage indicator | `Views/Tasks/StageIndicatorView.swift` | 5-stage pipeline (static "Execute" in Phase A) |
| Controls | `Views/Tasks/TaskControlsView.swift` | Cancel button for running tasks |
| Event handling | `Services/TaskService.swift` | `observeTask()` subscribes to gateway, filters by sessionKey, maps `chat.*`/`agent.*` events |
| Progress | `Services/TaskService.swift` | Asymptotic heuristic: `min(1 - 1/(1 + count*0.1), 0.95)` |

### Backend Gap — EVENT BRIDGE

This is the most critical integration piece. The plugin listens to raw agent events and re-broadcasts them as structured workforce events.

**File**: `extensions/workforce/src/event-bridge.ts`

```typescript
import { onAgentEvent, type AgentEventPayload } from "../../src/infra/agent-events.js";

export function startEventBridge(taskStore: TaskStore, broadcast: BroadcastFn) {
  return onAgentEvent((evt: AgentEventPayload) => {
    // Only process workforce sessions
    if (!evt.sessionKey?.startsWith("workforce-")) return;

    const task = taskStore.getBySessionKey(evt.sessionKey);
    if (!task) return;

    switch (evt.stream) {
      case "tool": {
        const toolName = (evt.data.name as string) ?? "tool";

        if (evt.data.type === "call") {
          broadcast("workforce.task.activity", {
            taskId: task.id,
            activity: {
              id: `act-${evt.seq}`,
              type: "toolCall",
              message: `Using ${toolName}`,
              detail: summarizeToolInput(evt.data.input),
              timestamp: new Date(evt.ts).toISOString(),
            },
          });
        } else if (evt.data.type === "result") {
          broadcast("workforce.task.activity", {
            taskId: task.id,
            activity: {
              id: `act-${evt.seq}`,
              type: "toolResult",
              message: `${toolName} finished`,
              timestamp: new Date(evt.ts).toISOString(),
            },
          });

          // Check for output-producing tools
          if (isOutputTool(toolName, evt.data)) {
            const output = detectOutput(task, toolName, evt.data);
            if (output) {
              task.outputs.push(output);
              taskStore.update(task);
              broadcast("workforce.task.output", { taskId: task.id, output });
            }
          }
        }

        // Update progress based on activity count
        const activityCount = taskStore.getActivityCount(task.id);
        const progress = Math.min(1.0 - 1.0 / (1.0 + activityCount * 0.1), 0.95);
        task.progress = progress;
        taskStore.update(task);
        broadcast("workforce.task.progress", {
          taskId: task.id,
          progress,
          currentActivity: `Using ${toolName}`,
        });
        break;
      }

      case "assistant": {
        if (evt.data.text) {
          broadcast("workforce.task.activity", {
            taskId: task.id,
            activity: {
              id: `act-${evt.seq}`,
              type: "text",
              message: String(evt.data.text).slice(0, 500),
              timestamp: new Date(evt.ts).toISOString(),
            },
          });

          // Stage heuristics
          const newStage = detectStageTransition(task, String(evt.data.text));
          if (newStage && newStage !== task.stage) {
            task.stage = newStage;
            taskStore.update(task);
            broadcast("workforce.task.stage", { taskId: task.id, stage: newStage });
          }
        }
        break;
      }

      case "lifecycle": {
        if (evt.data.state === "complete") {
          task.status = "completed";
          task.stage = "deliver";
          task.progress = 1.0;
          taskStore.update(task);
          broadcast("workforce.task.completed", {
            taskId: task.id,
            task,
            outputs: task.outputs,
          });
          broadcast("workforce.employee.status", {
            employeeId: task.employeeId,
            status: "online",
            currentTaskId: null,
          });
        } else if (evt.data.state === "error") {
          task.status = "failed";
          task.errorMessage = String(evt.data.error ?? "Unknown error");
          taskStore.update(task);
          broadcast("workforce.task.failed", {
            taskId: task.id,
            error: task.errorMessage,
            canRetry: true,
          });
          broadcast("workforce.employee.status", {
            employeeId: task.employeeId,
            status: "online",
            currentTaskId: null,
          });
        }
        break;
      }
    }
  });
}
```

**Stage heuristic rules** (stages only move forward, never backward):

```
Task starts                              → clarify
Agent asks question (? detected)         → stay in clarify
Agent says "plan"/"approach"/"I'll"      → plan
First tool call (write_file, bash)       → execute
Agent says "review"/"check"/"test"       → review
Agent produces final summary / completes → deliver
```

**Broadcast events emitted**:

| Event | Payload | Trigger |
|-------|---------|---------|
| `workforce.task.progress` | `{ taskId, progress: 0.0-1.0, currentActivity }` | Each tool call |
| `workforce.task.activity` | `{ taskId, activity: { id, type, message, timestamp, detail? } }` | Tool call/result, text, thinking |
| `workforce.task.stage` | `{ taskId, stage }` | Detected stage transition |
| `workforce.task.preview` | `{ taskId, preview: { type: "url", value } }` | Preview URL available |
| `workforce.task.output` | `{ taskId, output }` | Output file detected |
| `workforce.task.completed` | `{ taskId, task, outputs[] }` | Agent lifecycle.complete |
| `workforce.task.failed` | `{ taskId, error, canRetry }` | Agent lifecycle.error |

### Frontend Gap

**Modify**: `Sources/Workforce/Services/TaskService.swift`

Replace `handlePush()` to consume structured `workforce.task.*` events:

```swift
private func handlePush(_ push: GatewayPush, taskId: String) {
    guard case let .event(frame) = push else { return }
    guard frame.event.hasPrefix("workforce.task.") else { return }
    guard let payload = frame.payload?.value as? [String: Any],
          let eventTaskId = payload["taskId"] as? String,
          eventTaskId == taskId else { return }

    switch frame.event {
    case "workforce.task.progress":
        if let progress = payload["progress"] as? Double,
           let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
            self.tasks[index].progress = progress
        }

    case "workforce.task.activity":
        if let activityDict = payload["activity"] as? [String: Any],
           let activity = self.decodeActivity(activityDict) {
            self.appendActivity(taskId: taskId, activity: activity)
        }

    case "workforce.task.stage":
        if let stageRaw = payload["stage"] as? String,
           let stage = TaskStage(rawValue: stageRaw),
           let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
            self.tasks[index].stage = stage
        }

    case "workforce.task.preview":
        if let preview = payload["preview"] as? [String: Any],
           let urlStr = preview["value"] as? String {
            self.taskPreviews[taskId] = URL(string: urlStr)
        }

    case "workforce.task.completed":
        if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
            self.tasks[index].status = .completed
            self.tasks[index].progress = 1.0
            self.tasks[index].completedAt = Date()
        }
        if let outputsArray = payload["outputs"] as? [[String: Any]] {
            self.taskOutputs[taskId] = outputsArray.compactMap { self.decodeOutput($0) }
        }
        self.stopObserving(taskId: taskId)

    case "workforce.task.failed":
        let message = payload["error"] as? String ?? "An error occurred"
        if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
            self.tasks[index].status = .failed
            self.tasks[index].errorMessage = message
        }
        self.stopObserving(taskId: taskId)

    default:
        break
    }
}
```

Add new storage properties:
```swift
var taskPreviews: [String: URL] = [:]
var taskOutputs: [String: [TaskOutput]] = [:]
```

**Modify**: `Sources/Workforce/Views/Tasks/TaskProgressView.swift`
- Add preview pane beside activity log: `if let previewURL = taskService.taskPreviews[task.id]` → show `WKWebView` or link
- Add cancel confirmation: `.confirmationDialog("Cancel this task?", isPresented: $showCancelConfirm)`

### Integration Wire

```
Frontend                               Backend
   │                                      │
   │  (after tasks.approve)               │
   │  Start observeTask(id)               │
   │                                      │
   │◄─ workforce.task.progress ───────────┤ (many times)
   │  Update progress bar                 │
   │                                      │
   │◄─ workforce.task.activity ───────────┤ (many times)
   │  Append to activity log              │
   │                                      │
   │◄─ workforce.task.stage ──────────────┤ (on stage transition)
   │  Update stage indicator              │
   │                                      │
   │◄─ workforce.task.preview ────────────┤ (when available)
   │  Load preview in pane                │
   │                                      │
   │◄─ workforce.task.completed ──────────┤ (eventually)
   │  → OutputReviewView                  │
   │                                      │
   │◄─ workforce.task.failed ─────────────┤ (on error)
   │  Show error with retry option        │
```

### Done When
- [ ] Progress bar updates from structured events (not heuristic)
- [ ] Activity log shows tool usage and agent thinking
- [ ] Stage indicator updates dynamically through 5 stages
- [ ] Preview loads when available
- [ ] Completion transitions to review view
- [ ] Cancel works with confirmation dialog

---

## Feature 1.7: Output Review (NEW)

### What's Built

| Component | File | State |
|-----------|------|-------|
| Model | `Models/TaskOutput.swift` | id, taskId, type, title, filePath, url, createdAt |
| Mock data | `Mock/MockData.swift` | 2 mock outputs (file + website) |

No review view exists.

### Backend Gap

**Method**: `workforce.outputs.open`

```typescript
api.registerGatewayMethod("workforce.outputs.open", async ({ params, respond }) => {
  const { outputId } = params as { outputId: string };
  const output = taskStore.getOutput(outputId);
  if (!output) {
    respond(false, undefined, { code: -1, message: "Output not found" });
    return;
  }
  // Open URL in browser or file in default app
  const { exec } = await import("child_process");
  const target = output.remoteUrl || output.localPath;
  exec(`open "${target}"`);
  respond(true, { success: true });
});
```

**Method**: `workforce.outputs.reveal`

```typescript
api.registerGatewayMethod("workforce.outputs.reveal", async ({ params, respond }) => {
  const { outputId } = params as { outputId: string };
  const output = taskStore.getOutput(outputId);
  if (!output?.localPath) {
    respond(false, undefined, { code: -1, message: "No local path" });
    return;
  }
  const { exec } = await import("child_process");
  exec(`open -R "${output.localPath}"`);
  respond(true, { success: true });
});
```

**Method**: `workforce.tasks.revise`

```typescript
api.registerGatewayMethod("workforce.tasks.revise", async ({ params, respond, context }) => {
  const { taskId, feedback } = params as { taskId: string; feedback: string };
  const task = taskStore.get(taskId);
  if (!task) {
    respond(false, undefined, { code: -1, message: "Task not found" });
    return;
  }

  // Start new agent run in SAME session (context preserved)
  task.status = "running";
  task.stage = "execute";
  task.progress = 0;
  taskStore.update(task);

  // Agent run with revision context — same sessionKey means full conversation history
  startExecution(task, context, { revisionFeedback: feedback });

  context.broadcast("workforce.employee.status", {
    employeeId: task.employeeId,
    status: "busy",
    currentTaskId: task.id,
  });

  respond(true, { task });
});
```

### Frontend Gap

**Create**: `Sources/Workforce/Views/Tasks/OutputReviewView.swift`

Layout:
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│   ✅ Emma finished your task                                    │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │                                                          │  │
│   │                  [Website Preview]                        │  │
│   │                                                          │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   Consulting Landing Page                                       │
│   https://consulting-abc123.vercel.app                          │
│                                                                  │
│   ┌────────────────┐  ┌────────────────┐  ┌────────────────┐  │
│   │ Open Website ↗ │  │  View Code     │  │ Show in Finder │  │
│   └────────────────┘  └────────────────┘  └────────────────┘  │
│                                                                  │
│   ─────────────────────────────────────────────────────────     │
│                                                                  │
│   Want changes?                                                 │
│   ┌─────────────────────────────────────────────────────────┐  │
│   │ Make the CTA button bigger                              │  │
│   └─────────────────────────────────────────────────────────┘  │
│                                                                  │
│   ┌────────────────┐                    ┌────────────────┐     │
│   │ Request Changes │                    │  ✓ Looks Great │     │
│   └────────────────┘                    └────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

**Modify**: `Sources/Workforce/Services/TaskService.swift`

```swift
func openOutput(id: String) async throws {
    _ = try await self.gateway.request(
        method: "workforce.outputs.open",
        params: ["outputId": AnyCodable(id)])
}

func revealOutput(id: String) async throws {
    _ = try await self.gateway.request(
        method: "workforce.outputs.reveal",
        params: ["outputId": AnyCodable(id)])
}

func requestRevision(taskId: String, feedback: String) async throws -> WorkforceTask {
    let response: TaskCreateResponse = try await self.gateway.requestDecoded(
        method: "workforce.tasks.revise",
        params: ["taskId": AnyCodable(taskId), "feedback": AnyCodable(feedback)])
    if let index = self.tasks.firstIndex(where: { $0.id == taskId }) {
        self.tasks[index] = response.task
    }
    return response.task
}
```

### Integration Wire

```
Frontend                               Backend
   │                                      │
   │  (from workforce.task.completed)     │
   │  Show OutputReviewView               │
   │                                      │
   │  User clicks "Open Website"          │
   ├─ workforce.outputs.open ────────────►│ exec("open URL")
   │◄─ { success: true } ────────────────┤
   │                                      │
   │  User clicks "Show in Finder"        │
   ├─ workforce.outputs.reveal ──────────►│ exec("open -R path")
   │◄─ { success: true } ────────────────┤
   │                                      │
   │  User clicks "Request Changes"       │
   ├─ workforce.tasks.revise ────────────►│ New run in same session
   │  { taskId, feedback }                │
   │◄─ { task: { status: "running" } } ──┤
   │  → Back to TaskProgressView          │
   │                                      │
   │  User clicks "Looks Great"           │
   │  → Back to idle / task list          │
```

### Done When
- [ ] Review view shows on completion
- [ ] Output preview displays (WebView for websites, image for images)
- [ ] Open / Show in Finder buttons work
- [ ] Revision sends feedback, returns to execution
- [ ] Multiple revisions work (full context preserved)
- [ ] "Looks Great" completes the flow

---

## Feature 1.8: Task History (Persistence)

### What's Built

| Component | File | State |
|-----------|------|-------|
| Service | `Services/TaskService.swift` | `tasks: [WorkforceTask]` in-memory only. Computed `activeTasks`, `completedTasks`, `failedTasks`. |
| Dashboard | `Views/Tasks/TaskDashboardView.swift` | Sections: Active/Completed/Failed. Row navigation. |
| Row | `Views/Tasks/TaskRowView.swift` | Emoji, description, time, status indicator |

Tasks lost on app restart.

### Backend Gap

**Method**: `workforce.tasks.list`

```typescript
api.registerGatewayMethod("workforce.tasks.list", async ({ params, respond }) => {
  const { limit = 20, offset = 0, status } = params as {
    limit?: number;
    offset?: number;
    status?: string[];
  };
  let tasks = taskStore.list(); // Returns all tasks sorted by createdAt desc
  if (status?.length) {
    tasks = tasks.filter(t => status.includes(t.status));
  }
  const total = tasks.length;
  const page = tasks.slice(offset, offset + limit);
  respond(true, { tasks: page, total, hasMore: offset + limit < total });
});
```

**Method**: `workforce.tasks.get`

```typescript
api.registerGatewayMethod("workforce.tasks.get", async ({ params, respond }) => {
  const { taskId } = params as { taskId: string };
  const task = taskStore.get(taskId);
  if (!task) {
    respond(false, undefined, { code: -1, message: "Task not found" });
    return;
  }
  const activities = taskStore.getActivities(taskId);
  const outputs = taskStore.getOutputs(taskId);
  respond(true, { task, activities, outputs });
});
```

**Method**: `workforce.tasks.cancel`

```typescript
api.registerGatewayMethod("workforce.tasks.cancel", async ({ params, respond, context }) => {
  const { taskId } = params as { taskId: string };
  const task = taskStore.get(taskId);
  if (!task) {
    respond(false, undefined, { code: -1, message: "Task not found" });
    return;
  }
  // Abort the agent run by session key
  abortBySessionKey(task.sessionKey);
  task.status = "cancelled";
  taskStore.update(task);
  context.broadcast("workforce.employee.status", {
    employeeId: task.employeeId,
    status: "online",
    currentTaskId: null,
  });
  respond(true, { task });
});
```

**Task store implementation**: `~/.openclaw/tasks/<taskId>/task.json`
- Atomic writes (write to tmp, rename)
- Activities in separate `activities.jsonl` (append-only)
- Outputs tracked in task manifest `outputs[]` array

### Frontend Gap

**Modify**: `Sources/Workforce/Services/TaskService.swift`

```swift
func fetchTasks() async {
    do {
        let response: TaskListResponse = try await self.gateway.requestDecoded(
            method: "workforce.tasks.list",
            params: ["limit": AnyCodable(50)])
        self.tasks = response.tasks
    } catch {
        Self.logger.warning("Failed to fetch tasks: \(error)")
        // Keep existing in-memory tasks as fallback
    }
}

func fetchTask(id: String) async throws {
    let response: TaskDetailResponse = try await self.gateway.requestDecoded(
        method: "workforce.tasks.get",
        params: ["taskId": AnyCodable(id)])
    if let index = self.tasks.firstIndex(where: { $0.id == id }) {
        self.tasks[index] = response.task
        self.tasks[index].activities = response.activities
    }
    self.taskOutputs[id] = response.outputs
}

// Replace cancelTask() — from chat.abort to workforce.tasks.cancel
func cancelTask(id: String) async {
    guard let index = self.tasks.firstIndex(where: { $0.id == id }) else { return }
    do {
        let response: TaskCreateResponse = try await self.gateway.requestDecoded(
            method: "workforce.tasks.cancel",
            params: ["taskId": AnyCodable(id)])
        self.tasks[index] = response.task
    } catch {
        Self.logger.error("Cancel failed: \(error)")
        self.tasks[index].status = .cancelled
    }
}
```

New response types:
```swift
struct TaskListResponse: Codable {
    let tasks: [WorkforceTask]
    let total: Int
    let hasMore: Bool
}

struct TaskDetailResponse: Codable {
    let task: WorkforceTask
    let activities: [TaskActivity]
    let outputs: [TaskOutput]
}
```

**Modify**: `Sources/Workforce/Views/Tasks/TaskDashboardView.swift`
- Add `.task { await taskService.fetchTasks() }` to load from backend on appear
- Clicking completed task → `OutputReviewView`
- Clicking active task → `TaskProgressView` + `observeTask()`

### Integration Wire

```
Frontend                               Backend
   │                                      │
   │  (on app launch / reconnect)         │
   ├─ workforce.tasks.list ──────────────►│ Read from task store
   │  { limit: 50 }                       │
   │◄─ { tasks: [...], total, hasMore } ──┤
   │                                      │
   │  User clicks task in list            │
   ├─ workforce.tasks.get ───────────────►│ Full task detail
   │  { taskId }                          │
   │◄─ { task, activities, outputs } ─────┤
   │  Show appropriate view               │
   │                                      │
   │  User clicks cancel                  │
   ├─ workforce.tasks.cancel ────────────►│ Abort agent, update manifest
   │  { taskId }                          │
   │◄─ { task: { status: "cancelled" } } ─┤
```

### Done When
- [ ] Tasks persist across app restarts
- [ ] Dashboard loads historical tasks on launch
- [ ] Clicking completed task shows outputs
- [ ] Clicking active task shows progress
- [ ] Cancel uses `workforce.tasks.cancel` (not `chat.abort`)
- [ ] Task list refreshes on reconnect

---

## Plugin Method Reference

| Method | Params | Returns | Feature |
|--------|--------|---------|---------|
| `workforce.employees.list` | `{}` | `{ employees[] }` | 1.2 |
| `workforce.tasks.create` | `{ employeeId, brief, attachments[] }` | `{ task, clarification?, plan? }` | 1.3 |
| `workforce.tasks.clarify` | `{ taskId, answers[] }` | `{ task, clarification?, plan? }` | 1.4 |
| `workforce.tasks.approve` | `{ taskId, approved, feedback? }` | `{ task, plan? }` | 1.5 |
| `workforce.tasks.list` | `{ limit?, offset?, status[]? }` | `{ tasks[], total, hasMore }` | 1.8 |
| `workforce.tasks.get` | `{ taskId }` | `{ task, activities[], outputs[] }` | 1.8 |
| `workforce.tasks.cancel` | `{ taskId }` | `{ task }` | 1.8 |
| `workforce.tasks.revise` | `{ taskId, feedback }` | `{ task }` | 1.7 |
| `workforce.outputs.open` | `{ outputId }` | `{ success }` | 1.7 |
| `workforce.outputs.reveal` | `{ outputId }` | `{ success }` | 1.7 |

## Broadcast Event Reference

| Event | Payload | Emitted By |
|-------|---------|------------|
| `workforce.task.progress` | `{ taskId, progress, currentActivity }` | Event bridge (tool events) |
| `workforce.task.activity` | `{ taskId, activity }` | Event bridge (tool/text/thinking) |
| `workforce.task.stage` | `{ taskId, stage }` | Event bridge (stage heuristics) |
| `workforce.task.preview` | `{ taskId, preview: { type, value } }` | Event bridge (preview detected) |
| `workforce.task.output` | `{ taskId, output }` | Event bridge (output file detected) |
| `workforce.task.completed` | `{ taskId, task, outputs[] }` | Event bridge (lifecycle.complete) |
| `workforce.task.failed` | `{ taskId, error, canRetry }` | Event bridge (lifecycle.error) |
| `workforce.employee.status` | `{ employeeId, status, currentTaskId? }` | tasks.create / tasks.cancel / task.completed |

## Implementation Order

```
Layer 0: DONE (Phase A — 29 source files, mock data)

Layer 1: Plugin Foundation (backend only)
  1. Plugin scaffold: extensions/workforce/{openclaw.plugin.json, package.json, src/index.ts}
  2. Task store: create/read/update/list as JSON files in ~/.openclaw/tasks/
  3. workforce.employees.list — load config, enrich with status
  4. workforce.tasks.create — create manifest, determine clarification/plan

Layer 2: Frontend Data Layer (depends on Layer 1)
  5. EmployeeService.fetchEmployees() → gateway call with mock fallback
  6. New models: ClarificationPayload, PlanPayload, TaskFlowModels
  7. TaskService.submitTask() → workforce.tasks.create
  8. MainWindowView → TaskFlowState navigation enum

Layer 3: Clarification + Plan (depends on Layer 2)
  9. workforce.tasks.clarify + workforce.tasks.approve (backend)
  10. ClarificationView.swift + PlanView.swift (frontend)
  11. Routing wiring in MainWindowView

Layer 4: Event Bridge (depends on Layer 1, parallel with Layer 3)
  12. onAgentEvent → workforce.task.* broadcasts (event-bridge.ts)
  13. TaskService.handlePush() refactor → workforce.task.* events
  14. Preview pane + cancel confirmation in TaskProgressView

Layer 5: Output Review (depends on Layer 4)
  15. workforce.outputs.open/reveal + workforce.tasks.revise (backend)
  16. OutputReviewView.swift (frontend)
  17. Review → revision routing in MainWindowView

Layer 6: Task History (depends on Layer 1, parallel with Layers 3-5)
  18. workforce.tasks.list/get/cancel (backend)
  19. TaskService.fetchTasks()/fetchTask()/cancelTask() refactor
  20. TaskDashboardView loads from backend on appear
```

## Testing Strategy

**Backend (each method independently testable)**:
```bash
wscat -c ws://localhost:18789/ws
> {"type":"req","id":"1","method":"workforce.employees.list","params":{}}
# Should return employee list

> {"type":"req","id":"2","method":"workforce.tasks.create","params":{"employeeId":"emma-web","brief":"Build a landing page","attachments":[]}}
# Should return task with clarification or plan
```

**Frontend (mock fallback ensures testability without backend)**:
- Each view works with mock data when plugin not loaded
- `TaskFlowState` transitions testable with unit tests
- Event handling testable with synthetic `EventFrame` objects

**Integration (full end-to-end)**:
1. Launch app → connect → see employees from gateway
2. Click Emma → type task → submit → see clarification questions
3. Answer questions → see plan → approve → see real-time progress
4. Task completes → see output review → open output
5. Request revision → see progress again → completes
6. Close app → reopen → see task in history with correct state
