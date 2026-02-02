Engineering Brief: Workforce Desktop App
Document Version: 1.0
Last Updated: February 2, 2026
Author: Steven (Product/Architecture)
Audience: Swift Engineer building macOS Desktop App

Executive Summary
We're building Workforce — a macOS desktop app that gives users a team of AI employees (specialists) who can work on their digital workspace. Think of it as having a team of remote contractors who can see your screen, access your files, and complete real work.
Our differentiation from ChatGPT/Claude:

Not a chatbot — a workforce of specialists
Not conversation-centric — task & output-centric
Not generic — each employee has expertise and memory
Not cloud-only — runs locally with full context access

Our relationship with OpenClaw:

OpenClaw is our runtime foundation (like an engine)
We build the user experience on top (the car)
We don't compete with OpenClaw — we use it differently


Part 1: What We're Building
The User Mental Model
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                              │
│   USER'S MENTAL MODEL                                                        │
│                                                                              │
│   "I have a team of AI employees who work for me"                            │
│                                                                              │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│   │   Emma   │ │  David   │ │  Sarah   │ │   Alex   │ │   Maya   │          │
│   │   Web    │ │  Decks   │ │ Research │ │ Content  │ │  Visual  │          │
│   │ Developer│ │  Maker   │ │ Analyst  │ │  Writer  │ │ Designer │          │
│   └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────────┘          │
│                                                                              │
│   Each employee:                                                             │
│   • Has a specialty (what they're good at)                                   │
│   • Has a personality (how they communicate)                                 │
│   • Remembers my preferences (learns over time)                              │
│   • Can see my files and browser (has context)                               │
│   • Delivers real outputs (not just text responses)                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
User Journey (What We're Enabling)
1. USER OPENS APP
   → Sees their workforce (employee gallery)
   → Sees active tasks (what's being worked on)
   → Sees recent outputs (what's been delivered)

2. USER ASSIGNS TASK
   → Selects an employee (or app suggests one)
   → Describes what they need
   → Optionally shares specific files/folders

3. EMPLOYEE WORKS
   → Asks clarifying questions (if needed)
   → Shows their plan (transparency)
   → Executes the work (user sees progress)
   → Produces outputs (real files, deployments, etc.)

4. USER REVIEWS
   → Sees the output in context
   → Can provide feedback
   → Can request changes
   → Employee learns from feedback

5. OVER TIME
   → Employees remember preferences
   → Quality improves
   → User trusts employees with more
Key UX Principles
PrincipleWhat It MeansImplementationTask-CentricUsers assign tasks, not have conversationsTask input UI, not chat UIOutput-FirstResults matter, not the processProminent output viewer, minimal process noiseEmployees, Not BotsPersonalities, specialties, memoryEmployee profiles, per-employee memoryTransparent WorkUser can see what's happeningProgress indicators, step-by-step visibilityUser ControlUser approves, not just observesApproval flows, edit capabilities

Part 2: System Architecture
High-Level Architecture
┌─────────────────────────────────────────────────────────────────────────────┐
│                              SYSTEM ARCHITECTURE                             │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                     SWIFT APP (Your Focus)                           │   │
│   │                                                                      │   │
│   │   ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐       │   │
│   │   │  Employee  │ │    Task    │ │   Output   │ │  Settings  │       │   │
│   │   │  Gallery   │ │   Panel    │ │   Viewer   │ │   Panel    │       │   │
│   │   └────────────┘ └────────────┘ └────────────┘ └────────────┘       │   │
│   │                                                                      │   │
│   │   ┌──────────────────────────────────────────────────────────────┐  │   │
│   │   │                  WorkforceService (Swift)                     │  │   │
│   │   │   • WebSocket connection to Gateway                           │  │   │
│   │   │   • Employee state management                                 │  │   │
│   │   │   • Task lifecycle handling                                   │  │   │
│   │   │   • Output file watching                                      │  │   │
│   │   └──────────────────────────────────────────────────────────────┘  │   │
│   │                              │                                       │   │
│   └──────────────────────────────┼───────────────────────────────────────┘   │
│                                  │ WebSocket + HTTP                          │
│                                  ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                    WORKFORCE GATEWAY (Node.js)                       │   │
│   │                                                                      │   │
│   │   Our Layer:                         OpenClaw Core:                  │   │
│   │   ┌────────────────────────┐         ┌────────────────────────┐     │   │
│   │   │ Employee Registry      │         │ Session Management     │     │   │
│   │   │ Task Lifecycle Manager │         │ Tool Execution         │     │   │
│   │   │ Quality Check Runner   │         │ Browser Control        │     │   │
│   │   │ Output Manager         │         │ Memory System          │     │   │
│   │   │ Usage Tracker          │         │ Skill Loading          │     │   │
│   │   └────────────────────────┘         └────────────────────────┘     │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                  │                                           │
│                                  ▼                                           │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         HOST SYSTEM (macOS)                          │   │
│   │                                                                      │   │
│   │   File System │ Chrome/Safari │ Shell │ Native Apps (future)         │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Component Responsibilities
ComponentTechnologyResponsibilitySwift AppSwiftUI + AppKitUI, user interaction, local stateWorkforceServiceSwiftGateway communication, state syncWorkforce GatewayNode.js (TypeScript)Task orchestration, employee logicOpenClaw CoreNode.js (TypeScript)Tool execution, browser, memoryHost SystemmacOSFiles, browser sessions, shell

Part 3: OpenClaw Codebase Guide
What OpenClaw Is (Context)
OpenClaw is an open-source "personal AI assistant" that:

Runs as a local daemon (Gateway)
Connects to chat apps (WhatsApp, Telegram, Slack)
Executes AI tasks using tools (file read/write, browser, shell)
Has a skill system for teaching the AI new capabilities

Key insight: We use OpenClaw's execution engine but replace its chat-based UX with our workforce UX.
OpenClaw Directory Structure (Relevant Parts)
openclaw/
├── src/
│   ├── gateway/                 ★★★ CRITICAL - Our Gateway builds on this
│   │   ├── server-http.ts       # HTTP server setup
│   │   ├── server-ws-runtime.ts # WebSocket server (we connect here)
│   │   ├── server-methods/      # RPC methods we'll call
│   │   │   ├── agent.ts         # Agent execution methods
│   │   │   ├── sessions.ts      # Session management
│   │   │   ├── chat.ts          # Message handling
│   │   │   └── config.ts        # Configuration
│   │   ├── server-channels.ts   # Channel routing
│   │   └── boot.ts              # Gateway startup
│   │
│   ├── channels/                ★☆☆ REFERENCE ONLY - We don't use channels
│   │   ├── registry.ts          # How channels register (pattern to learn)
│   │   └── ...                  # WhatsApp, Telegram, etc. (ignore)
│   │
│   ├── plugins/                 ★★☆ USEFUL - Our employees are like plugins
│   │   ├── loader.ts            # How plugins load (skill loading)
│   │   ├── registry.ts          # Plugin management
│   │   └── runtime/             # Plugin execution context
│   │
│   ├── config/                  ★★☆ USEFUL - Configuration patterns
│   │   ├── sessions.ts          # Session key derivation
│   │   └── ...
│   │
│   ├── infra/                   ★★☆ USEFUL - Utilities we'll use
│   │   ├── exec-approvals.ts    # User approval for dangerous actions
│   │   ├── fetch.ts             # HTTP utilities
│   │   ├── ws.ts                # WebSocket utilities
│   │   └── ...
│   │
│   ├── logging/                 ★☆☆ REFERENCE - Logging patterns
│   │
│   └── cli/                     ☆☆☆ IGNORE - We have our own UI
│
├── skills/                      ★★★ CRITICAL - Our employees are enhanced skills
│   ├── */SKILL.md               # Skill definition format
│   └── ...
│
└── docs/                        ★★☆ USEFUL - Documentation
Key Files to Study
1. Gateway WebSocket Protocol
File: src/gateway/server-ws-runtime.ts
This is how we'll communicate with the Gateway from Swift.
typescript// Key concepts to understand:

// 1. Connection setup
// Gateway listens on ws://localhost:18789 (default)
// Authentication via token in query string or header

// 2. Message format (JSON-RPC style)
interface GatewayMessage {
  id: string;           // Request ID for correlation
  method: string;       // Method name (e.g., "agent.run")
  params?: object;      // Method parameters
}

interface GatewayResponse {
  id: string;           // Correlates to request
  result?: any;         // Success result
  error?: {             // Error details
    code: number;
    message: string;
  };
}

// 3. Events (server → client)
interface GatewayEvent {
  event: string;        // Event type
  data: any;            // Event payload
}
2. Agent Execution
File: src/gateway/server-methods/agent.ts
How tasks get executed.
typescript// Key methods we'll use:

// Start an agent run
"agent.run" → {
  message: string;      // User's task description
  sessionKey?: string;  // Session identifier
  agentId?: string;     // Which agent (we'll map to employees)
}

// Get agent status
"agent.status" → {
  sessionKey: string;
}

// Stop an agent run
"agent.stop" → {
  sessionKey: string;
}
3. Session Management
File: src/gateway/server-methods/sessions.ts
How conversation context is maintained.
typescript// Sessions store conversation history and state
// Each employee-task pair should have a unique session

// Key methods:
"sessions.list" → {}                    // List active sessions
"sessions.get" → { sessionKey: string } // Get session details
"sessions.clear" → { sessionKey: string } // Clear session
4. Skill Format
File: skills/*/SKILL.md
How capabilities are defined. Our employees extend this.
yaml---
name: skill-name
description: "What this skill does"
metadata: {"requires": {"bins": ["node"], "env": ["API_KEY"]}}
---

# Skill Instructions

Instructions for the AI on how to use this skill...
5. Browser Control
File: src/tools/browser.ts (referenced in gateway)
How browser automation works.
typescript// Browser tool capabilities:
// - Navigate to URLs
// - Click elements
// - Fill forms
// - Extract content
// - Screenshot

// Uses Playwright under the hood
// Connects to user's actual Chrome (with their sessions)
6. Exec Approvals
File: src/infra/exec-approvals.ts
How dangerous operations get user approval.
typescript// When agent wants to run a command, it may need approval
// This is a pattern we'll use in our UI

interface ExecApproval {
  command: string;      // What command
  reason: string;       // Why it needs to run
  risk: 'low' | 'medium' | 'high';
}

// Our Swift app will show approval dialogs for these
```

---

## Part 4: Feature Requirements

### Feature Map Overview
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           FEATURE MAP                                        │
│                                                                              │
│   MVP (Week 1)              Phase 2 (Week 2-4)         Phase 3 (Month 2+)   │
│   ────────────              ────────────────────       ──────────────────    │
│                                                                              │
│   □ Employee Gallery        □ Employee Memory          □ Cloud Sync          │
│   □ Task Input              □ Output History           □ Mobile Companion    │
│   □ Progress View           □ Folder Sharing UI        □ Expert Skills       │
│   □ Output Viewer           □ Quality Feedback         □ Usage Analytics     │
│   □ Gateway Connection      □ Notification Center      □ Team Features       │
│   □ Basic Settings          □ Employee Customization                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### MVP Features (Your Focus)

---

#### Feature 1: Employee Gallery

**Purpose:** Let users see and select from their AI employees.

**User Story:**
> As a user, I want to see all my AI employees so I can choose who to assign my task to.

**UI Specification:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           EMPLOYEE GALLERY                                   │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│   │   │              │  │              │  │              │              │   │
│   │   │     🌐       │  │     📊       │  │     🔍       │              │   │
│   │   │              │  │              │  │              │              │   │
│   │   │    Emma      │  │    David     │  │    Sarah     │              │   │
│   │   │  Web Builder │  │  Deck Maker  │  │  Researcher  │              │   │
│   │   │              │  │              │  │              │              │   │
│   │   │  ● Online    │  │  ● Online    │  │  ○ Busy      │              │   │
│   │   └──────────────┘  └──────────────┘  └──────────────┘              │   │
│   │                                                                      │   │
│   │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │   │
│   │   │              │  │              │  │              │              │   │
│   │   │     ✍️       │  │     🎨       │  │     🎬       │              │   │
│   │   │              │  │              │  │              │              │   │
│   │   │    Alex      │  │    Maya      │  │    Ryan      │              │   │
│   │   │Content Writer│  │Visual Design │  │Video Creator │              │   │
│   │   │              │  │              │  │              │              │   │
│   │   │  ● Online    │  │  ● Online    │  │  ● Online    │              │   │
│   │   └──────────────┘  └──────────────┘  └──────────────┘              │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Data Model:
swiftstruct Employee: Identifiable, Codable {
    let id: String                    // "emma-web"
    let name: String                  // "Emma"
    let title: String                 // "Web Builder"
    let emoji: String                 // "🌐"
    let description: String           // "Creates professional websites..."
    let status: EmployeeStatus        // .online, .busy, .offline
    let capabilities: [String]        // ["websites", "landing pages", ...]
    let currentTask: Task?            // If busy, what they're working on
}

enum EmployeeStatus {
    case online                       // Ready to accept tasks
    case busy(taskId: String)         // Working on a task
    case offline                      // Gateway not running
}
Gateway Integration:
swift// Fetch employees from Gateway
func fetchEmployees() async throws -> [Employee] {
    // Call custom RPC method we'll add to Gateway
    let response = try await gateway.call(
        method: "workforce.employees.list",
        params: [:]
    )
    return try decode([Employee].self, from: response)
}
```

**Interactions:**
- Click employee → Opens Task Panel for that employee
- Hover employee → Shows detailed capabilities
- Right-click → Quick actions (view history, settings)

---

#### Feature 2: Task Input Panel

**Purpose:** Let users describe what they want an employee to do.

**User Story:**
> As a user, I want to describe a task and assign it to an employee so they can do the work.

**UI Specification:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TASK INPUT PANEL                                   │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  ┌──────────┐                                                        │   │
│   │  │    🌐    │   Emma - Web Builder                                   │   │
│   │  │          │   Ready to help                                        │   │
│   │  └──────────┘                                                        │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  What would you like me to build?                                    │   │
│   │                                                                      │   │
│   │  ┌───────────────────────────────────────────────────────────────┐  │   │
│   │  │                                                               │  │   │
│   │  │  Build a landing page for my AI consulting business.         │  │   │
│   │  │  It should have a hero section, services, testimonials,      │  │   │
│   │  │  and a contact form. Modern, professional look with          │  │   │
│   │  │  blue/white color scheme.                                    │  │   │
│   │  │                                                               │  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │  📎 Attachments                                                      │   │
│   │  ┌─────────────┐  ┌─────────────┐                                   │   │
│   │  │ 📄 brief.pdf│  │ + Add File  │                                   │   │
│   │  └─────────────┘  └─────────────┘                                   │   │
│   │                                                                      │   │
│   │  📁 Shared Folders                                                   │   │
│   │  ┌─────────────────────────────────────────────────────────────┐    │   │
│   │  │ ☑️ ~/Desktop/ConsultingProject                               │    │   │
│   │  │ ☐ ~/Documents (click to share)                               │    │   │
│   │  └─────────────────────────────────────────────────────────────┘    │   │
│   │                                                                      │   │
│   │                                            ┌──────────────────┐      │   │
│   │                                            │   Assign Task    │      │   │
│   │                                            └──────────────────┘      │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Data Model:
swiftstruct TaskInput {
    let employeeId: String
    var description: String
    var attachments: [Attachment]
    var sharedFolders: [URL]
}

struct Attachment: Identifiable {
    let id: UUID
    let url: URL
    let name: String
    let type: AttachmentType         // .file, .image, .document
}

struct TaskSubmission: Codable {
    let id: String                   // UUID
    let employeeId: String
    let description: String
    let attachments: [String]        // File paths
    let sharedFolders: [String]      // Folder paths
    let createdAt: Date
}
Gateway Integration:
swift// Submit task to Gateway
func submitTask(_ input: TaskInput) async throws -> Task {
    let submission = TaskSubmission(
        id: UUID().uuidString,
        employeeId: input.employeeId,
        description: input.description,
        attachments: input.attachments.map { $0.url.path },
        sharedFolders: input.sharedFolders.map { $0.path },
        createdAt: Date()
    )

    let response = try await gateway.call(
        method: "workforce.tasks.submit",
        params: submission
    )

    return try decode(Task.self, from: response)
}
```

**Interactions:**
- Type in text area → Updates description
- Drag files → Adds to attachments
- Click folder checkbox → Shares/unshares folder
- Click "Assign Task" → Submits to Gateway, transitions to Progress View

---

#### Feature 3: Progress View

**Purpose:** Show users what the employee is doing in real-time.

**User Story:**
> As a user, I want to see my employee's progress so I know my task is being worked on.

**UI Specification:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            PROGRESS VIEW                                     │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │  ┌──────────┐                                                        │   │
│   │  │    🌐    │   Emma is working on your task                         │   │
│   │  │          │   Landing page for AI consulting                       │   │
│   │  └──────────┘                                                        │   │
│   │                                                                      │   │
│   │  PROGRESS ════════════════════════════════════════░░░░░░░░░  65%     │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  STAGE: Executing                                                    │   │
│   │                                                                      │   │
│   │  ✅ Clarify    Understood requirements                               │   │
│   │  ✅ Plan       Created project structure                             │   │
│   │  🔵 Execute    Building website components...                        │   │
│   │  ○  Review     Pending                                               │   │
│   │  ○  Deliver    Pending                                               │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  CURRENT ACTIVITY                                                    │   │
│   │  ┌───────────────────────────────────────────────────────────────┐  │   │
│   │  │ 🔧 Creating hero section with responsive layout               │  │   │
│   │  │                                                               │  │   │
│   │  │ > Building HeroSection.tsx                                    │  │   │
│   │  │ > Adding animations                                           │  │   │
│   │  │ > Styling with Tailwind CSS                                   │  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │  ┌────────────┐  ┌────────────┐                                     │   │
│   │  │   Pause    │  │   Cancel   │                                     │   │
│   │  └────────────┘  └────────────┘                                     │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Data Model:
swiftstruct Task: Identifiable, Codable {
    let id: String
    let employeeId: String
    let description: String
    var status: TaskStatus
    var stage: TaskStage
    var progress: Double              // 0.0 to 1.0
    var currentActivity: String?
    var activities: [TaskActivity]
    var outputs: [TaskOutput]
    let createdAt: Date
    var updatedAt: Date
}

enum TaskStatus {
    case pending
    case running
    case paused
    case completed
    case failed(error: String)
    case cancelled
}

enum TaskStage: String, CaseIterable {
    case clarify = "Clarify"
    case plan = "Plan"
    case execute = "Execute"
    case review = "Review"
    case deliver = "Deliver"
}

struct TaskActivity: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let type: ActivityType
    let message: String
    let details: String?
}

enum ActivityType {
    case info
    case action
    case tool                         // Tool being used
    case output                       // Output produced
    case error
    case approval                     // Needs user approval
}
Gateway Integration:
swift// Subscribe to task progress events
func subscribeToTaskProgress(taskId: String) -> AsyncStream<TaskEvent> {
    return AsyncStream { continuation in
        gateway.subscribe(event: "task.progress") { event in
            if event.taskId == taskId {
                continuation.yield(event)
            }
        }
    }
}

// Task events from Gateway
enum TaskEvent {
    case stageChanged(TaskStage)
    case progressUpdated(Double)
    case activityAdded(TaskActivity)
    case outputProduced(TaskOutput)
    case approvalRequired(ApprovalRequest)
    case completed(Task)
    case failed(Error)
}
```

**Interactions:**
- Stages update in real-time via WebSocket
- Activity log scrolls to show latest
- "Pause" → Pauses task execution
- "Cancel" → Cancels task (with confirmation)
- Approval dialogs appear when employee needs permission

---

#### Feature 4: Output Viewer

**Purpose:** Display the results of completed tasks.

**User Story:**
> As a user, I want to see and interact with what my employee produced.

**UI Specification:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            OUTPUT VIEWER                                     │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │  ✅ Task Completed                                                   │   │
│   │                                                                      │   │
│   │  Emma built your landing page                                        │   │
│   │  "Landing page for AI consulting business"                           │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  OUTPUTS                                                             │   │
│   │                                                                      │   │
│   │  ┌─────────────────────────────────────────┐  ┌──────────────────┐  │   │
│   │  │                                         │  │                  │  │   │
│   │  │    🌐 Live Website                      │  │  📁 Source Code  │  │   │
│   │  │                                         │  │                  │  │   │
│   │  │    https://ai-consulting.vercel.app    │  │  ~/Desktop/      │  │   │
│   │  │                                         │  │  consulting-site │  │   │
│   │  │    ┌─────────────────────────────┐     │  │                  │  │   │
│   │  │    │    [Preview Thumbnail]       │     │  │  ┌────────────┐ │  │   │
│   │  │    │                              │     │  │  │ Open in    │ │  │   │
│   │  │    │                              │     │  │  │ Finder     │ │  │   │
│   │  │    └─────────────────────────────┘     │  │  └────────────┘ │  │   │
│   │  │                                         │  │                  │  │   │
│   │  │    ┌────────────┐  ┌────────────┐      │  │                  │  │   │
│   │  │    │ Open Site  │  │   Copy URL │      │  │                  │  │   │
│   │  │    └────────────┘  └────────────┘      │  │                  │  │   │
│   │  │                                         │  │                  │  │   │
│   │  └─────────────────────────────────────────┘  └──────────────────┘  │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  FEEDBACK                                                            │   │
│   │                                                                      │   │
│   │  How did Emma do?                                                    │   │
│   │                                                                      │   │
│   │  ⭐⭐⭐⭐⭐     ┌────────────────────────────────────────────────┐   │   │
│   │               │ Looks great! Can you make the CTA button bigger? │   │   │
│   │               └────────────────────────────────────────────────┘   │   │
│   │                                                                      │   │
│   │  ┌──────────────────┐  ┌──────────────────┐                         │   │
│   │  │  Request Changes │  │  Mark Complete   │                         │   │
│   │  └──────────────────┘  └──────────────────┘                         │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Data Model:
swiftstruct TaskOutput: Identifiable, Codable {
    let id: String
    let type: OutputType
    let title: String
    let description: String?
    let location: OutputLocation
    let preview: OutputPreview?
    let createdAt: Date
}

enum OutputType {
    case website(url: URL)
    case file(path: URL)
    case folder(path: URL)
    case document(path: URL)
    case image(path: URL)
    case text(content: String)
}

enum OutputLocation {
    case local(path: URL)
    case remote(url: URL)
    case both(path: URL, url: URL)
}

struct OutputPreview {
    let type: PreviewType
    let data: Data                   // Thumbnail image, text excerpt, etc.
}

struct TaskFeedback: Codable {
    let taskId: String
    let rating: Int                  // 1-5
    let comment: String?
    let requestChanges: Bool
}
Gateway Integration:
swift// Get task outputs
func getTaskOutputs(taskId: String) async throws -> [TaskOutput] {
    let response = try await gateway.call(
        method: "workforce.tasks.outputs",
        params: ["taskId": taskId]
    )
    return try decode([TaskOutput].self, from: response)
}

// Submit feedback
func submitFeedback(_ feedback: TaskFeedback) async throws {
    try await gateway.call(
        method: "workforce.tasks.feedback",
        params: feedback
    )
}

// Request changes (starts new task iteration)
func requestChanges(taskId: String, changes: String) async throws -> Task {
    let response = try await gateway.call(
        method: "workforce.tasks.revise",
        params: ["taskId": taskId, "changes": changes]
    )
    return try decode(Task.self, from: response)
}
Interactions:

Click output → Opens in appropriate app (browser, Finder, etc.)
Star rating → Records feedback
"Request Changes" → Opens revision flow
"Mark Complete" → Archives task


Feature 5: Gateway Connection Manager
Purpose: Manage connection to the local Workforce Gateway.
User Story:

As a user, I want the app to automatically connect to my local Gateway.

Technical Specification:
swift// Gateway connection states
enum GatewayState {
    case disconnected
    case connecting
    case connected(version: String)
    case error(GatewayError)
}

enum GatewayError: Error {
    case notRunning                  // Gateway process not found
    case connectionFailed(Error)     // WebSocket connection failed
    case authenticationFailed        // Invalid token
    case versionMismatch(expected: String, actual: String)
}

// Gateway service
class GatewayService: ObservableObject {
    @Published var state: GatewayState = .disconnected
    @Published var employees: [Employee] = []
    @Published var activeTasks: [Task] = []

    private var webSocket: URLSessionWebSocketTask?
    private let gatewayURL = URL(string: "ws://localhost:18789")!

    // Connection lifecycle
    func connect() async throws
    func disconnect()

    // RPC calls
    func call<T: Codable>(method: String, params: [String: Any]) async throws -> T

    // Event subscription
    func subscribe(event: String, handler: @escaping (GatewayEvent) -> Void)
    func unsubscribe(event: String)

    // Gateway management
    func startGateway() throws        // Start gateway process if not running
    func stopGateway() throws
    func restartGateway() throws
}
```

**Connection Flow:**
```
App Launch
    │
    ├─► Check if Gateway running (HTTP health check)
    │   │
    │   ├─► Running: Connect WebSocket
    │   │             │
    │   │             ├─► Success: Load employees, subscribe to events
    │   │             │
    │   │             └─► Failure: Show connection error
    │   │
    │   └─► Not Running: Prompt to start Gateway
    │                    │
    │                    ├─► User clicks "Start": Launch gateway process
    │                    │                        └─► Retry connection
    │                    │
    │                    └─► User clicks "Cancel": Show offline mode
    │
    └─► Maintain connection (heartbeat, auto-reconnect)
```

**UI States:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CONNECTION STATES                                  │
│                                                                              │
│   DISCONNECTED:                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   ⚠️ Gateway Not Running                                             │   │
│   │                                                                      │   │
│   │   Workforce needs the local gateway to connect to your employees.   │   │
│   │                                                                      │   │
│   │   ┌──────────────────┐  ┌──────────────────┐                        │   │
│   │   │  Start Gateway   │  │  Learn More      │                        │   │
│   │   └──────────────────┘  └──────────────────┘                        │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   CONNECTING:                                                                │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   ⏳ Connecting to Gateway...                                        │   │
│   │                                                                      │   │
│   │   [Progress Indicator]                                               │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   CONNECTED:                                                                 │
│   (Show normal app UI with green status indicator)                          │
│                                                                              │
│   ERROR:                                                                     │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   ❌ Connection Error                                                │   │
│   │                                                                      │   │
│   │   Could not connect to Gateway: [Error message]                     │   │
│   │                                                                      │   │
│   │   ┌──────────────────┐  ┌──────────────────┐                        │   │
│   │   │     Retry        │  │  Troubleshoot    │                        │   │
│   │   └──────────────────┘  └──────────────────┘                        │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

#### Feature 6: Task List / Dashboard

**Purpose:** Show all tasks (active, completed, failed).

**User Story:**
> As a user, I want to see all my tasks so I can track what my employees are working on.

**UI Specification:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           TASK DASHBOARD                                     │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │  ACTIVE TASKS                                                        │   │
│   │                                                                      │   │
│   │  ┌───────────────────────────────────────────────────────────────┐  │   │
│   │  │ 🌐 Emma        Landing page for consulting     ████████░░ 80% │  │   │
│   │  │               Executing: Finalizing styles                    │  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │  ┌───────────────────────────────────────────────────────────────┐  │   │
│   │  │ 🔍 Sarah       Competitor analysis             ████░░░░░░ 40% │  │   │
│   │  │               Executing: Researching pricing                  │  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  COMPLETED TODAY                                                     │   │
│   │                                                                      │   │
│   │  ┌───────────────────────────────────────────────────────────────┐  │   │
│   │  │ ✅ 📊 David    Q4 Investor Deck               Completed 2h ago│  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │  ┌───────────────────────────────────────────────────────────────┐  │   │
│   │  │ ✅ ✍️ Alex     Blog post: AI Trends           Completed 5h ago│  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  QUEUED                                                              │   │
│   │                                                                      │   │
│   │  ┌───────────────────────────────────────────────────────────────┐  │   │
│   │  │ ⏸️ 🎨 Maya     Social media graphics           Waiting         │  │   │
│   │  └───────────────────────────────────────────────────────────────┘  │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
Data Model:
swiftstruct TaskListState {
    var activeTasks: [Task]
    var completedTasks: [Task]
    var queuedTasks: [Task]
    var failedTasks: [Task]
}

// Filtering and sorting
enum TaskFilter {
    case all
    case byEmployee(String)
    case byStatus(TaskStatus)
    case byDateRange(from: Date, to: Date)
}

enum TaskSort {
    case createdAtDesc
    case createdAtAsc
    case statusPriority           // Active first, then queued, then completed
}
```

---

#### Feature 7: Settings Panel

**Purpose:** Configure app and employee preferences.

**UI Specification:**
```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            SETTINGS                                          │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │  GENERAL                                                             │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  Launch at login                              [Toggle: ON ]          │   │
│   │  Show in menu bar                             [Toggle: ON ]          │   │
│   │  Notification sound                           [Toggle: ON ]          │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  GATEWAY                                                             │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  Status                                       ● Connected            │   │
│   │  Port                                         [18789        ]        │   │
│   │  Auto-start gateway                           [Toggle: ON ]          │   │
│   │                                                                      │   │
│   │  ┌────────────────┐  ┌────────────────┐                             │   │
│   │  │ Restart Gateway│  │  View Logs     │                             │   │
│   │  └────────────────┘  └────────────────┘                             │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  SHARED FOLDERS                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  These folders are accessible to all employees:                     │   │
│   │                                                                      │   │
│   │  ☑️ ~/Desktop                                 [Remove]               │   │
│   │  ☑️ ~/Documents/Projects                      [Remove]               │   │
│   │                                                                      │   │
│   │  ┌────────────────┐                                                 │   │
│   │  │ + Add Folder   │                                                 │   │
│   │  └────────────────┘                                                 │   │
│   │                                                                      │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  ACCOUNTS                                                            │   │
│   │  ─────────────────────────────────────────────────────────────────   │   │
│   │                                                                      │   │
│   │  Google                                       [Connected]            │   │
│   │  Microsoft                                    [Connect...]           │   │
│   │  Slack                                        [Connected]            │   │
│   │                                                                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part 5: Gateway API Reference

### WebSocket Protocol

**Connection:**
```
URL: ws://localhost:18789/ws
Query: ?token={gateway_token}
Message Format:
json// Request (Client → Gateway)
{
  "id": "uuid",
  "method": "workforce.tasks.submit",
  "params": { ... }
}

// Response (Gateway → Client)
{
  "id": "uuid",
  "result": { ... }
}

// Error Response
{
  "id": "uuid",
  "error": {
    "code": -32000,
    "message": "Error description"
  }
}

// Event (Gateway → Client, no request)
{
  "event": "task.progress",
  "data": { ... }
}
Workforce API Methods
These are the methods we'll add to the Gateway (on top of OpenClaw):
typescript// Employee Management
"workforce.employees.list" → Employee[]
"workforce.employees.get" → { id: string } → Employee
"workforce.employees.status" → { id: string } → EmployeeStatus

// Task Management
"workforce.tasks.submit" → TaskSubmission → Task
"workforce.tasks.get" → { taskId: string } → Task
"workforce.tasks.list" → { filter?: TaskFilter } → Task[]
"workforce.tasks.cancel" → { taskId: string } → void
"workforce.tasks.pause" → { taskId: string } → void
"workforce.tasks.resume" → { taskId: string } → void
"workforce.tasks.revise" → { taskId: string, changes: string } → Task

// Task Outputs
"workforce.tasks.outputs" → { taskId: string } → TaskOutput[]

// Feedback
"workforce.tasks.feedback" → TaskFeedback → void

// Settings
"workforce.settings.get" → Settings
"workforce.settings.update" → Partial<Settings> → Settings
"workforce.folders.list" → SharedFolder[]
"workforce.folders.add" → { path: string } → SharedFolder
"workforce.folders.remove" → { path: string } → void
Event Types
typescript// Task Events
"task.created" → { task: Task }
"task.started" → { taskId: string }
"task.stage" → { taskId: string, stage: TaskStage }
"task.progress" → { taskId: string, progress: number, activity: string }
"task.activity" → { taskId: string, activity: TaskActivity }
"task.output" → { taskId: string, output: TaskOutput }
"task.completed" → { taskId: string, task: Task }
"task.failed" → { taskId: string, error: string }

// Approval Events
"approval.required" → { taskId: string, approval: ApprovalRequest }

// Employee Events
"employee.status" → { employeeId: string, status: EmployeeStatus }

// Gateway Events
"gateway.connected" → { version: string }
"gateway.error" → { error: string }
```

---

## Part 6: Swift Implementation Guide

### Project Structure
```
Workforce/
├── App/
│   ├── WorkforceApp.swift           # App entry point
│   └── AppDelegate.swift            # Menu bar, lifecycle
│
├── Views/
│   ├── MainWindow/
│   │   ├── MainWindowView.swift     # Main container
│   │   ├── SidebarView.swift        # Navigation sidebar
│   │   └── ContentAreaView.swift    # Dynamic content
│   │
│   ├── Employees/
│   │   ├── EmployeeGalleryView.swift
│   │   ├── EmployeeCardView.swift
│   │   └── EmployeeDetailView.swift
│   │
│   ├── Tasks/
│   │   ├── TaskInputView.swift
│   │   ├── TaskProgressView.swift
│   │   ├── TaskListView.swift
│   │   └── TaskRowView.swift
│   │
│   ├── Outputs/
│   │   ├── OutputViewerView.swift
│   │   ├── OutputCardView.swift
│   │   └── OutputPreviewView.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── GeneralSettingsView.swift
│   │   ├── GatewaySettingsView.swift
│   │   └── FoldersSettingsView.swift
│   │
│   └── Components/
│       ├── ProgressBar.swift
│       ├── StatusIndicator.swift
│       ├── ActivityLog.swift
│       └── ApprovalDialog.swift
│
├── Services/
│   ├── GatewayService.swift         # WebSocket connection
│   ├── EmployeeService.swift        # Employee management
│   ├── TaskService.swift            # Task operations
│   └── SettingsService.swift        # App settings
│
├── Models/
│   ├── Employee.swift
│   ├── Task.swift
│   ├── TaskOutput.swift
│   ├── Settings.swift
│   └── GatewayModels.swift          # API types
│
├── Utilities/
│   ├── WebSocketClient.swift
│   ├── JSONCoding.swift
│   └── FileManager+Extensions.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
Key Swift Patterns
1. Gateway Connection:
swiftimport Foundation
import Combine

@MainActor
class GatewayService: ObservableObject {
    @Published var state: GatewayState = .disconnected
    @Published var employees: [Employee] = []
    @Published var activeTasks: [Task] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var pendingRequests: [String: CheckedContinuation<Data, Error>] = [:]
    private var eventHandlers: [String: [(GatewayEvent) -> Void]] = [:]

    private let baseURL = URL(string: "ws://localhost:18789")!

    // MARK: - Connection

    func connect() async throws {
        state = .connecting

        // First check if Gateway is running
        guard await isGatewayRunning() else {
            state = .error(.notRunning)
            throw GatewayError.notRunning
        }

        // Connect WebSocket
        let session = URLSession(configuration: .default)
        let url = baseURL.appendingPathComponent("/ws")
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Start receiving messages
        Task { await receiveMessages() }

        // Verify connection
        let version = try await call(method: "gateway.version", params: [:]) as String
        state = .connected(version: version)

        // Load initial data
        try await loadEmployees()
        try await loadActiveTasks()
    }

    // MARK: - RPC

    func call<T: Decodable>(method: String, params: [String: Any]) async throws -> T {
        let requestId = UUID().uuidString

        let request: [String: Any] = [
            "id": requestId,
            "method": method,
            "params": params
        ]

        let data = try JSONSerialization.data(withJSONObject: request)
        try await webSocketTask?.send(.data(data))

        // Wait for response
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[requestId] = continuation
        }
    }

    // MARK: - Events

    func subscribe(event: String, handler: @escaping (GatewayEvent) -> Void) {
        eventHandlers[event, default: []].append(handler)
    }

    private func receiveMessages() async {
        guard let webSocketTask else { return }

        while true {
            do {
                let message = try await webSocketTask.receive()

                switch message {
                case .data(let data):
                    handleMessage(data)
                case .string(let string):
                    handleMessage(Data(string.utf8))
                @unknown default:
                    break
                }
            } catch {
                state = .error(.connectionFailed(error))
                break
            }
        }
    }

    private func handleMessage(_ data: Data) {
        // Parse and route to pending request or event handler
        // ...
    }
}
2. Task Observation:
swift@MainActor
class TaskService: ObservableObject {
    @Published var tasks: [Task] = []
    @Published var selectedTask: Task?

    private let gateway: GatewayService
    private var taskSubscriptions: [String: AnyCancellable] = []

    init(gateway: GatewayService) {
        self.gateway = gateway
        setupEventHandlers()
    }

    private func setupEventHandlers() {
        gateway.subscribe(event: "task.progress") { [weak self] event in
            self?.handleTaskProgress(event)
        }

        gateway.subscribe(event: "task.completed") { [weak self] event in
            self?.handleTaskCompleted(event)
        }
    }

    func submitTask(_ input: TaskInput) async throws -> Task {
        let task: Task = try await gateway.call(
            method: "workforce.tasks.submit",
            params: [
                "employeeId": input.employeeId,
                "description": input.description,
                "attachments": input.attachments.map { $0.url.path },
                "sharedFolders": input.sharedFolders.map { $0.path }
            ]
        )

        tasks.append(task)
        return task
    }

    private func handleTaskProgress(_ event: GatewayEvent) {
        guard let taskId = event.data["taskId"] as? String,
              let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            return
        }

        // Update task
        if let progress = event.data["progress"] as? Double {
            tasks[index].progress = progress
        }
        if let activity = event.data["activity"] as? String {
            tasks[index].currentActivity = activity
        }
    }
}
3. SwiftUI Views:
swiftstruct EmployeeGalleryView: View {
    @EnvironmentObject var employeeService: EmployeeService
    @State private var selectedEmployee: Employee?

    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(employeeService.employees) { employee in
                    EmployeeCardView(employee: employee)
                        .onTapGesture {
                            selectedEmployee = employee
                        }
                }
            }
            .padding()
        }
        .sheet(item: $selectedEmployee) { employee in
            TaskInputView(employee: employee)
        }
    }
}

struct EmployeeCardView: View {
    let employee: Employee

    var body: some View {
        VStack(spacing: 12) {
            Text(employee.emoji)
                .font(.system(size: 48))

            Text(employee.name)
                .font(.headline)

            Text(employee.title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Circle()
                    .fill(employee.status.color)
                    .frame(width: 8, height: 8)
                Text(employee.status.label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

Part 7: Development Phases
Phase 1: Foundation (Days 1-2)
Goals:

Swift app connects to Gateway
Can display employees
Can submit a task

Deliverables:

Xcode project setup
GatewayService with WebSocket connection
EmployeeGalleryView showing employees
Basic TaskInputView

Dependencies:

Gateway must have workforce methods implemented

Phase 2: Core Features (Days 3-4)
Goals:

Full task lifecycle visible
Outputs displayed
Settings panel

Deliverables:

TaskProgressView with live updates
OutputViewerView with preview
TaskListView / Dashboard
SettingsView

Phase 3: Polish (Day 5)
Goals:

Error handling
Edge cases
Visual polish

Deliverables:

Error states and recovery
Loading states
Animations and transitions
Menu bar integration


Part 8: Success Criteria
MVP Must-Haves

 App launches and connects to Gateway
 User can see employee gallery
 User can select employee and submit task
 User sees task progress in real-time
 User sees task outputs when complete
 User can provide feedback
 Basic settings (shared folders)

Quality Bar

 App doesn't crash
 Connection errors are handled gracefully
 UI is responsive (no blocking main thread)
 All text is readable (proper contrast)
 Keyboard navigation works
 Standard macOS patterns (Cmd+Q, Cmd+,)

Demo Scenarios

Happy Path: Assign task to Emma → Watch progress → See website output
Error Handling: Gateway not running → Show error → User starts it → Reconnect
Multi-task: Submit to Emma, then Sarah → Both show in dashboard → Both complete
