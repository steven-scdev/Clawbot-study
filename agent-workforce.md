codex
Below is a product-driven, implementation-ready technical spec to start building Workforce end-to-end on top of
OpenClaw. It maps the Swift UI to current Gateway capabilities first, then defines the backend extensions we’ll add
(Workforce layer) and how each frontend feature consumes them. It includes explicit data contracts, file layout,
events, safety, and milestones so engineering can begin immediately.

Architecture

- Swift app: SwiftUI + AppKit, WebSocket JSON-RPC to local Gateway (tokenized URL).
- Gateway: OpenClaw runtime (Node/TS). Phase A uses existing methods; Phase B adds Workforce methods/events.
- Workforce layer: Task orchestrator + employee registry + output manager + events (node/TS).
- Storage: per-task manifest + outputs; per-employee workspace (OpenClaw workspace) for identity/memory.
- Safety: token auth, tool-policy, sandbox, exec approvals.

Connection

- URL: ws://127.0.0.1:18789/ws?token=<gateway_token>
- Framing:
    - Request: {"id":"uuid","method":"namespace.method","params":{}}
    - Response: {"id":"uuid","result":...} or {"id":"uuid","error":{"code":-32000,"message":"..."}}
    - Event: {"event":"topic.name","data":{...}}

Phase A — Swift UI on Current Capabilities

- Goal: Ship the new UI using existing OpenClaw features (no new backend yet). We’ll simulate employees from
configured agents and surface sessions/progress via existing methods.

Frontend features (initial bindings)

- Employee Gallery
    - Source: statically defined agent profiles in app config for now (or read OpenClaw agent IDs via
gateway.call("agents.list") if available). Show status “online” if gateway connected, “busy” if a session exists for
that agent (check sessions.list).
- Task Input
    - Submit: call agent.run with {message, agentId, sessionKey}. Attachments: for now, copy to a per-task folder
under ~/.openclaw/workspace and reference paths in the message (we’ll formalize later).
- Progress View
    - Listen to stream events produced by agent.run (partial tokens, tool logs) if exposed; otherwise poll
sessions.get and tail logs.tail as a fallback to show activity.
- Output Viewer
    - Initially show “outputs” as local file references produced by the run (e.g., path printed by the model/tools
to stdout). This becomes first-class in Phase B.
- Settings
    - Display gateway connection status (ping gateway.health or version). Provide UI for token entry and port.
Shared folders UI is stubbed; we’ll wire it to policies in Phase B.

Swift deliverables (files)

- Services:
    - GatewayService.swift: tokenized WS connect, call(method:params:), subscribe(event:), reconnect, error
propagation.
    - EmployeeService.swift: in Phase A, produce in-app list (static JSON or from agents list if available).
    - TaskService.swift: submitTask, observeProgress, in-memory store of tasks; uses agent.run and logs.tail as
fallback for activity.
    - SettingsService.swift: token/port persistence, shared folders (local storage only for now).
- Models: Employee.swift, Task.swift, TaskOutput.swift, Settings.swift, GatewayModels.swift (Codable).
- Views: EmployeeGalleryView, TaskInputView, TaskProgressView, OutputViewerView, TaskListView, SettingsView.
- Utilities: WebSocketClient.swift (JSON-RPC), JSONCoding.swift, FileManager+Extensions.swift.

Acceptance (Phase A)

- App connects to gateway with token; handles errors and retry.
- Employee gallery renders; clicking an employee opens Task input; submitting creates a run.
- Progress view updates (token stream/log tail), shows activities (at least as log lines).
- Outputs section shows produced paths (manual until outputs API exists).
- Settings shows connection and token controls.

Phase B — Workforce Layer (Gateway Extensions)

- Goal: Add a thin Workforce orchestrator in OpenClaw to make the UI truly task/output-centric and predictable.

Backend (Node/TS) new module

- Directory: src/workforce/
    - registry.ts: employee registry (map agent IDs to display metadata, load from config).
    - orchestrator.ts: TaskLifecycleManager (clarify/plan/execute/review/deliver), wraps agent.run, tracks stage/
progress/activity.
    - outputs.ts: OutputManager (writes per-task task.json + outputs/*, emits task.output events).
    - events.ts: pub/sub helpers into Gateway WS runtime.
    - server-methods.ts: register workforce.* methods.
    - types.ts: Task/Employee/Output contracts shared with Swift.
- Bind at Gateway boot:
    - In src/gateway/boot.ts (or equivalent), import and register Workforce server methods.

New RPC methods (server-side)

- Employees:
    - workforce.employees.list() -> Employee[]
    - workforce.employees.get({id}) -> Employee
    - workforce.employees.status({id}) -> EmployeeStatus
- Tasks:
    - workforce.tasks.submit(TaskSubmission) -> Task
    - workforce.tasks.get({taskId}) -> Task
    - workforce.tasks.list({filter?}) -> Task[]
    - workforce.tasks.cancel({taskId}) -> void
    - workforce.tasks.pause({taskId}) -> void
    - workforce.tasks.resume({taskId}) -> void
    - workforce.tasks.revise({taskId, changes}) -> Task
- Outputs:
    - workforce.tasks.outputs({taskId}) -> TaskOutput[]
- Feedback:
    - workforce.tasks.feedback(TaskFeedback) -> void
- Settings + Folders:
    - workforce.settings.get() -> Settings
    - workforce.settings.update(Partial<Settings>) -> Settings
    - workforce.folders.list() -> SharedFolder[]
    - workforce.folders.add({path}) -> SharedFolder
    - workforce.folders.remove({path}) -> void

Events (server → client)

- Task:
    - task.created, task.started, task.stage, task.progress, task.activity, task.output, task.completed, task.failed
- Approvals:
    - approval.required (from exec approvals forwarder)
- Employee:
    - employee.status
- Gateway:
    - gateway.connected, gateway.error

Contracts (TypeScript ⇄ Swift Codable)

- Employee:
    - {id, name, title, emoji, description, status: "online"|"busy"|"offline", capabilities?: string[],
currentTask?: Task}
- Task:
    - {id, employeeId, description, status: "pending"|"running"|"paused"|"completed"|"failed"|"cancelled",
stage: "Clarify"|"Plan"|"Execute"|"Review"|"Deliver", progress: number, currentActivity?: string, activities:
TaskActivity[], outputs: TaskOutput[], createdAt, updatedAt, error?: string}
- TaskActivity:
    - {id, timestamp, type: "info"|"action"|"tool"|"output"|"error"|"approval", message, details?}
- TaskOutput:
    - {id, type: "website"|"file"|"folder"|"document"|"image"|"text", title, description?, location:
{ kind:"local"|"remote"|"both", path?: string, url?: string }, preview?: {type:"image"|"text", dataBase64},
createdAt}
- TaskSubmission:
    - {id, employeeId, description, attachments: string[], sharedFolders: string[], createdAt}
- ApprovalRequest:
    - {taskId, command, reason, risk: "low"|"medium"|"high"}
- Settings:
    - {port, autoStart, token?, sharedFolders: string[]}

Orchestrator logic (high-level)

- On workforce.tasks.submit:
    - Create task record; emit task.created.
    - Build system prompt (employee identity/workspace + compact skills primer).
    - Launch agent.run with stream handlers.
    - On token/tool event: update currentActivity, append TaskActivity (type=tool/info/action), derive progress
heuristics; emit task.activity/task.progress.
    - On file outputs or declared artifacts: create TaskOutput entries; emit task.output.
    - Handle approvals: forward approval.required (map from exec forwarder); pause until approved/denied.
    - Stage transitions: rule-based (e.g., first plan markers → Plan, first edit/tool use → Execute, after tests/
lint pass → Review, produce outputs → Deliver).
    - On completion or error: task.completed or task.failed with final state; persist task.json.

Approvals wiring

- Subscribe to exec approvals forwarder events; translate to approval.required.
- Provide workforce.tasks.pause/resume/cancel to control underlying process registry.
- In Review/Deliver stage, optionally auto-request approvals on risky outputs.

Folders and sandboxing (Phase B)

- Add macOS sandbox-friendly shared folders:
    - Use workforce.folders.add/remove/list to manage a safelist.
    - Map safelist into tool policy and/or sandbox binds for the task session.
    - Default write to shared folders; read broadly (or per policy).

Phase C — Employees & Memory

- Define employees in config workforce.employees mapping to OpenClaw agent IDs, with display metadata.
- Memory: rely on extensions/memory-core tools; surface memory search within employee detail (future).
- Employee customization: update per-employee identity files (IDENTITY.md/SOUL.md) via Gateway
workforce.employees.update (optional later).

Frontend Feature ↔ Backend

- Employee Gallery
    - FE: EmployeeService.fetch() → workforce.employees.list
    - FE: show status via employee.status events and activeTasks.
- Task Input
    - FE: TaskService.submit(input) → workforce.tasks.submit
    - FE: attachments become file paths; shared folders piped to workforce.folders.add.
- Progress View
    - FE: subscribe to events: task.stage/progress/activity/output/completed/failed
    - FE: show approval dialogs on approval.required and send openclaw approvals mutations (or Workforce wrapper) to
approve/deny.
- Output Viewer
    - FE: workforce.tasks.outputs to list; open local paths or remote URLs; fetch preview via Gateway HTTP when
present.
- Settings
    - FE: workforce.settings.get/update, workforce.folders.list/add/remove
    - FE: Gateway control buttons (start/stop/restart): map to existing daemon CLI via gateway.call("daemon.*") if
we expose wrapper methods (optional).
- Task Dashboard
    - FE: workforce.tasks.list with filters; live updates via events.

Security & Safety

- Token auth: pass ?token=... always; surface clear UI for invalid token/reconnect.
- Exec approvals: approvals must be visible in app; /approve via chat remains supported.
- Tool policy: keep conservative defaults; expose a “Policy explain” screen powered by sandbox explain output.
- Filesystem safety: only allow write within safelisted shared folders or sandbox bind mounts; read can be broader,
but start conservative.

Deliverables & Milestones

- Week 1 (UI on current runtime)
    - Swift: GatewayService, EmployeeGallery, TaskInput, TaskProgress (logs-based), Output placeholder, Settings
(connection only).
    - Accept: create a task and see progress tokens/log lines.
- Weeks 2–3 (Workforce layer + wiring)
    - Backend: src/workforce/* (methods, events, orchestrator, outputs manifest).
    - Swift: switch UI to new workforce.* APIs; real-time events; outputs viewer with previews; approvals dialog.
    - Accept: full round-trip task: submit → progress → outputs → feedback.
- Week 4 (polish)
    - Shared folders (bookmarks), Settings fleshed out, error cases, UX polish, perf tweaking.

Testing

- Local manual tests: scripts that submit a simple “build site” task, run pnpm openclaw logs --follow, confirm task
events.
- Swift unit/UI tests: JSON-RPC plumbing, event decoding, view state.
- Gateway unit tests: methods return shape, event emission, orchestrator stage transitions, outputs writing.
- Safety: approvals allowlist tests, sandbox deny defaults.

File Map (Gateway additions)

- src/workforce/registry.ts: employee registry loading from config.
- src/workforce/orchestrator.ts: TaskLifecycleManager (agent.run wrapper).
- src/workforce/outputs.ts: OutputManager (manifest + previews).
- src/workforce/events.ts: event helpers.
- src/workforce/server-methods.ts: RPC registration + handlers.
- src/workforce/types.ts: shared interfaces.
- Bind: import server-methods.ts from src/gateway/boot.ts (or equivalent bootstrap).

Swift File Map

- Services: GatewayService.swift, EmployeeService.swift, TaskService.swift, SettingsService.swift
- Views: EmployeeGalleryView.swift, EmployeeCardView.swift, TaskInputView.swift, TaskProgressView.swift,
OutputViewerView.swift, TaskListView.swift, SettingsView.swift
- Models: Employee.swift, Task.swift, TaskOutput.swift, GatewayModels.swift, Settings.swift
- Utilities: WebSocketClient.swift, JSONCoding.swift, FileManager+Extensions.swift

Open Questions / Decisions

- Approvals action transport: either reuse OpenClaw approvals CLI via a wrapper RPC or add workforce.approvals.*
helpers that call into approvals internals.
- Quality runner: codify minimum checks (lint/build/test) and expose as configured steps per employee type (web,
docs, decks), or keep Phase 2 optional.
- Claude Code CLI integration: keep as “editor-only” mode (tools off). For automation flows, prefer the normal agent
path with tools + approvals.

If you want, I can immediately:

- Scaffold the src/workforce module (method stubs + events + types).
- Provide Swift GatewayService and stubs for workforce.*.
- Add a basic “outputs manifest” handler with thumbnail route so the Output Viewer has something to render on Day 1
of Phase B.
