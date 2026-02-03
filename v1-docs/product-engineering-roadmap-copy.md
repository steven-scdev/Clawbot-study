# Product-Engineering Roadmap: Workforce v1

> From working prototype to product launch. Every feature driven by what customers expect, mapped to exact implementation work.

---

## Executive Summary

### What We Have

The Workforce app is a macOS desktop application built on OpenClaw that lets users manage AI employees. The core infrastructure is solid:

- **48 Swift files** across Models, Views, Services, and Components
- **29 of 31 views are fully implemented** with glass-morphism UI, animated backgrounds, and polished interactions
- **Backend workforce plugin** with 8 gateway methods, 4 lifecycle hooks, file-based task persistence
- **Real-time event streaming** from agent to frontend via WebSocket event bridge
- **Full state machine** (`TaskFlowState`) with 7 states: idle, input, chatting, clarifying, planning, executing, reviewing

### The Critical Gap

**The chat view is the correct primary view, but it only supports plain text bubbles.** After a user submits a task brief, `MainWindowView.swift:114` transitions to `.chatting` — this is architecturally correct. All workflow phases (clarification, planning, execution, output review) should happen inline within this chat conversation. The gap is that:

1. **The chat only renders 4 message types** (`user`, `assistant`, `system`, `error`) — it needs inline card components for questionnaires, plan approvals, progress milestones, and content-specific output previews
2. **The backend never generates structured data** — no clarification questions, no execution plans, no output preview payloads
3. **Every employee behaves identically** — no personality, system prompt, or content-type differentiation exists

The app works as a text chat wrapper. It needs to work as a rich, card-based workforce conversation where each employee produces inline previews of their actual work.

### What This Document Covers

12 features organized by customer journey phase, each containing:
- **Customer Need**: What users expect when they use the app
- **Current State**: What exists in code today (with file paths)
- **Gap Analysis**: What's missing
- **Frontend Work**: Exact Swift file changes
- **Backend Work**: Exact TypeScript file changes
- **Acceptance Criteria**: How we know it's done
- **Priority**: P0 (launch blocker), P1 (launch important), P2 (post-launch)

---

## How to Read This Document

### Priority Tiers
| Tier | Meaning | Criteria |
|------|---------|----------|
| **P0** | Launch blocker | Without this, the product feels broken or indistinguishable from a chatbot |
| **P1** | Launch important | Significantly improves the "AI employee" experience |
| **P2** | Post-launch | Deepens the product but can ship after initial release |

### Effort Markers
| Marker | Meaning |
|--------|---------|
| `[FE]` | Frontend (Swift/SwiftUI) work |
| `[BE]` | Backend (TypeScript, workforce plugin) work |
| `[NEW]` | New file/component needed |
| `[MOD]` | Modification to existing file |
| `[WIRE]` | Wiring/integration (connecting existing pieces) |

### File Path Conventions
- Frontend: `apps/macos/Sources/Workforce/`
- Backend: `extensions/workforce/`
- Abbreviated as `FE/` and `BE/` in this document

---

## Phase: Getting Started

### F1: Onboarding & First Employee Experience — P1

#### Customer Need
> "I just opened the app for the first time. I don't know what AI employees are, what they can do, or how to get started. I want to be guided through assigning my first task and see something magical happen."

#### Current State
- No onboarding flow exists
- App opens to `MainWindowView` with sidebar selection defaulting to nil, showing a generic placeholder: "Select an item from the sidebar" (`MainWindowView.swift:101-105`)
- `EmployeeGalleryView.swift` shows employee cards but provides no guidance
- `TaskInputView.swift:151` has a hardcoded greeting "Good morning, Alex" with no dynamic user name
- Task templates in `TaskInputView.swift:28-50` are generic (landing page, React component, dataset) — not employee-specific

#### Gap Analysis
- No first-run detection
- No guided walkthrough introducing the employee concept
- No "try it now" flow that shows the full BRIEF → CLARIFY → PLAN → EXECUTE → REVIEW cycle
- Employee greeting is static and non-personalized
- Template suggestions aren't tailored to each employee's specialty

#### Frontend Work
1. `[FE][NEW]` Create `Views/Onboarding/OnboardingView.swift` — 3-4 step walkthrough introducing the workforce concept ("Meet your team", "Pick an employee", "Describe what you need", "Watch them work")
2. `[FE][NEW]` Create `Views/Onboarding/FirstTaskGuideView.swift` — contextual overlay/coach marks for the first task flow
3. `[FE][MOD]` `MainWindowView.swift` — Add `@AppStorage("hasCompletedOnboarding")` check; route to onboarding on first launch
4. `[FE][MOD]` `TaskInputView.swift:151` — Replace hardcoded "Alex" with dynamic user name (from system or settings)
5. `[FE][MOD]` `TaskInputView.swift:28-50` — Make templates employee-specific (Emma gets web templates, David gets deck templates, etc.)

#### Backend Work
1. `[BE][NEW]` Add `workforce.onboarding.status` gateway method — returns `{ isFirstRun: boolean, completedAt?: string }`
2. `[BE][MOD]` `employees.ts` — Add `suggestedTasks: string[]` field to `EmployeeConfig` so each employee has curated starter prompts

#### Acceptance Criteria
- [ ] First-time user sees a 3-4 step onboarding explaining what AI employees are
- [ ] After onboarding, user is guided to pick an employee and submit their first task
- [ ] Templates shown during task input are specific to the selected employee
- [ ] Greeting uses actual user name, not "Alex"
- [ ] Second launch skips onboarding entirely

---

## Phase: Briefing Your Employee

### F2: Employee Identity & Personality — P0

#### Customer Need
> "When I click on Emma, she should feel like a real web design specialist. She should greet me differently than David the data analyst. Each employee should have a distinct voice, area of expertise, and way of working."

#### Current State
- `Employee.swift` has fields for name, title, emoji, description, capabilities, status — all the **display** data
- `employees.ts:15-43` defines 3 default employees (Emma, David, Sarah) with `agentId` field that is **never used**
- No system prompt per employee — the `startAgent()` call in `TaskService.swift:456-467` sends only `message` and `sessionKey`, with no identity context
- Backend `before_agent_start` hook (`index.ts:300-311`) does not inject any employee-specific instructions
- The `EmployeeConfig` type has `agentId` but no `systemPrompt`, `toolSet`, or `personality` fields
- `TaskInputView.swift` greeting and templates are the same regardless of which employee is selected

#### Gap Analysis
- No system prompt differentiation between employees
- No personality injection into the agent
- `agentId` exists but is unused — each employee should map to a configured agent or a custom system prompt
- No employee-specific tool restrictions (Emma shouldn't be using data analysis tools; David shouldn't be building websites)
- No personalized greeting from the employee in `TaskInputView`
- `EmployeeCardView.swift` displays capabilities but these don't influence actual behavior

#### Frontend Work
1. `[FE][MOD]` `Models/Employee.swift` — Add `greeting: String?`, `systemPrompt: String?` fields
2. `[FE][MOD]` `TaskInputView.swift:149-158` — Display `employee.greeting` instead of generic text; dynamically generate greeting based on employee personality
3. `[FE][MOD]` `TaskInputView.swift:28-50` — Filter/replace templates based on `employee.capabilities`
4. `[FE][MOD]` `Views/Tasks/TaskChatView.swift` — Show employee avatar and name with personality-consistent message styling
5. `[FE][MOD]` `Views/Employees/EmployeeCardView.swift` — Add specialty indicator and sample task examples

#### Backend Work
1. `[BE][MOD]` `employees.ts` — Expand `EmployeeConfig` to include:
   ```typescript
   systemPrompt: string;      // Employee-specific instructions for the AI
   greeting: string;           // Personalized greeting text
   toolAllowlist?: string[];   // Which tools this employee can use
   toolDenylist?: string[];    // Which tools are forbidden
   suggestedTasks: string[];   // Example tasks for the task input view
   ```
2. `[BE][MOD]` `employees.ts:15-43` — Flesh out each default employee with distinct system prompts:
   - Emma: "You are Emma, a creative web designer. You build beautiful, responsive websites..."
   - David: "You are David, a data analyst. You create insightful presentations and visualizations..."
   - Sarah: "You are Sarah, a senior engineer. You conduct deep research and build robust systems..."
3. `[BE][MOD]` `index.ts:300-311` (`before_agent_start` hook) — Inject the employee's system prompt into the agent context. Currently the hook only updates task status; it needs to set `ctx.systemPrompt` or equivalent
4. `[BE][MOD]` `index.ts:76-106` (`workforce.tasks.create`) — Include employee config data in the task creation response so the frontend knows the greeting and suggested tasks
5. `[BE][MOD]` `employees.ts:53-69` (`buildEmployeeList`) — Include `greeting` and `suggestedTasks` in the employee wire format

#### Acceptance Criteria
- [ ] Each employee has a unique system prompt that shapes their AI behavior
- [ ] Emma responds with web design expertise; David with data analysis expertise; Sarah with engineering expertise
- [ ] Employee greeting on TaskInputView is personalized per employee
- [ ] Task templates change based on which employee is selected
- [ ] Employee personality is consistent across the entire task lifecycle (clarification questions, plan language, output descriptions)

---

### F3: Smart Clarification Flow — P0

#### Customer Need
> "When I tell my employee to 'build me a website,' they shouldn't just start coding immediately. They should ask me targeted questions first: What's the purpose? Who's the audience? What's the style? Like a real employee would."

#### Architectural Principle: Chat-Centric Workflow

**All workflow phases — clarification, planning, execution, and output review — happen within the same `TaskChatView`.** The user stays in `.chatting` state throughout. Instead of routing to separate full-screen views, the chat renders different **inline card components** based on structured events from the backend:

- Clarification → **Questionnaire card** appears in chat (interactive radio/checkbox/text inputs)
- Plan → **Plan approval card** appears in chat (approve/reject buttons)
- Execution → **Progress cards** and **milestone cards** appear in chat
- Output → **Content-specific preview cards** appear in chat (WebView, slides, document, etc.)

This means:
- `.chatting` is the **correct and only** state for all task phases after briefing
- The existing `ClarificationView.swift`, `PlanView.swift`, etc. are **refactored into embeddable card components** — not full-screen views
- `TaskFlowState` no longer needs `.clarifying`, `.planning`, `.executing`, `.reviewing` as separate routing targets — the chat handles all phases through different card types

#### Current State
- `ClarificationView.swift` is **fully implemented** (217 lines) — supports single-select, multi-select, text input, and file questions. Can be adapted into an inline card component.
- `TaskFlowState.clarifying(task:questions:)` exists in `TaskFlowModels.swift:110` — will be simplified
- `TaskService.submitClarification()` at `TaskService.swift:94-104` sends answers to `workforce.tasks.clarify` backend method
- Backend `workforce.tasks.clarify` at `index.ts:109-134` accepts answers, appends them to the brief, and advances stage
- `TaskChatView.swift:27-69` (`chatMessages`) only handles 4 activity types: `.userMessage`, `.text`, `.completion`, `.error`
- `ChatMessage.Role` only has 4 cases: `user`, `assistant`, `system`, `error`
- **BUT**: Nothing ever triggers clarification. The backend `workforce.tasks.create` returns immediately without generating questions. `TaskService.submitTask()` calls `startAgent()` immediately.

#### Gap Analysis
- Backend has no brief analysis logic — never generates clarification questions
- No question generation — backend never creates `ClarificationPayload` data
- `TaskService.submitTask()` at `TaskService.swift:43-92` calls `startAgent()` immediately — no pause for clarification
- No employee-specific question templates (Emma should ask about design; David should ask about data format)
- `ChatMessage.Role` doesn't support structured card types — only text bubbles
- `ChatBubbleView` cannot render interactive questionnaire cards
- `TaskActivity.ActivityType` doesn't include `.clarification` type

#### Frontend Work
1. `[FE][MOD]` `Components/ChatBubbleView.swift` — Extend `ChatMessage.Role` to support structured card types:
   ```swift
   enum Role {
       case user
       case assistant
       case system
       case error
       case clarification(ClarificationPayload)  // Questionnaire card
       case plan(PlanPayload)                      // Plan approval card
       case milestone(MilestoneData)               // Progress milestone
       case stageTransition(from: String, to: String) // Stage change divider
       case outputPreview(TaskOutput)              // Content-specific preview
   }
   ```
2. `[FE][NEW]` Create `Components/Cards/ClarificationCardView.swift` — Inline questionnaire card adapted from `ClarificationView.swift`. Shows questions with radio/checkbox/text inputs and a submit button, all rendered inside the chat scroll:
   ```swift
   struct ClarificationCardView: View {
       let questions: [ClarificationQuestion]
       let onSubmit: ([String: String]) -> Void
       @State private var isSubmitted = false
       // After submission: becomes read-only showing answers
   }
   ```
3. `[FE][MOD]` `TaskChatView.swift:107-114` — Update the `ForEach(chatMessages)` loop to render card-type messages with appropriate card components instead of `ChatBubbleView`:
   ```swift
   ForEach(self.chatMessages) { msg in
       switch msg.role {
       case .user, .assistant, .system, .error:
           ChatBubbleView(message: msg, employeeName: self.employee.name)
       case .clarification(let payload):
           ClarificationCardView(questions: payload.questions, onSubmit: self.submitClarification)
       case .plan(let payload):
           PlanCardView(plan: payload, onApprove: ..., onReject: ...)
       // ... other card types
       }
   }
   ```
4. `[FE][MOD]` `TaskChatView.swift:27-69` (`chatMessages` computed property) — Handle `.clarification` activity type by creating card-role `ChatMessage` entries
5. `[FE][MOD]` `TaskService.swift:43-92` (`submitTask`) — Do NOT call `startAgent()` immediately. Let the backend decide whether clarification is needed first. If the create response indicates clarification, the backend emits a `workforce.task.clarification` event; the chat renders it as an inline questionnaire card.
6. `[FE][MOD]` `TaskService.swift` — Add `submitClarificationAnswers(taskId:answers:)` method that sends answers and allows the backend to proceed to plan generation or execution

#### Backend Work
1. `[BE][NEW]` Create `BE/src/brief-analyzer.ts` — Analyzes the user's brief to determine if clarification is needed:
   ```typescript
   export function analyzeNeedsClarification(brief: string, employee: EmployeeConfig): ClarificationPayload | null
   ```
   Two approaches (decide based on architecture preference):
   - **Rule-based (fast, deterministic)**: Employee-specific question templates triggered by brief analysis (e.g., Emma always asks about audience and style if not mentioned; David asks about data source and format)
   - **AI-based (smarter, more dynamic)**: Short LLM call analyzing the brief to generate context-specific questions
2. `[BE][MOD]` `index.ts:76-106` (`workforce.tasks.create`) — After creating the task, call `analyzeNeedsClarification()`. If questions are returned:
   - Set task stage to `"clarify"`
   - Emit `workforce.task.clarification` event with the questions payload via WebSocket
   - Do NOT start the agent — wait for clarification answers
   If no questions needed:
   - Proceed to plan generation (emit `workforce.task.plan` event) or execution
3. `[BE][MOD]` `index.ts:109-134` (`workforce.tasks.clarify`) — After receiving answers, either generate a plan (emit `workforce.task.plan` event) or proceed to execution
4. `[BE][MOD]` `event-bridge.ts` — Add new event type: `workforce.task.clarification` with structured questions payload
5. `[BE][MOD]` `task-store.ts` — Add `clarificationPayload?: object` and `clarificationAnswers?: object` fields to `TaskManifest`

#### Acceptance Criteria
- [ ] After submitting a brief, an inline questionnaire card appears in the chat when the employee needs more info
- [ ] Clarification questions are employee-specific (web-related for Emma, data-related for David)
- [ ] Vague briefs always trigger clarification; detailed briefs may skip it
- [ ] User answers questions directly in the chat via interactive card inputs (radio, checkbox, text)
- [ ] After answering, the flow continues in the same chat (plan card or execution progress appears next)
- [ ] The questionnaire card becomes read-only after submission (answers visible but not editable)
- [ ] If user cancels/dismisses clarification, the task is cancelled cleanly

---

## Phase: Approving the Plan

### F4: Plan Generation & Approval — P0

#### Customer Need
> "Before my employee starts working, I want to see what they plan to do. I want a clear summary, numbered steps, and an estimated time. I should be able to approve, request changes, or cancel — all without leaving the conversation."

#### Architecture: Inline Plan Card in Chat

The plan appears as an **inline approval card** within the `TaskChatView` chat scroll. When the backend generates a plan (after clarification or directly for clear briefs), it emits a `workforce.task.plan` event. The chat renders this as a structured plan card with:
- Summary text
- Numbered steps with estimated times
- Approve / Request Changes / Cancel buttons
- Optional feedback text field (shown when "Request Changes" is tapped)

After the user approves, the card becomes read-only (showing "Approved" badge) and execution begins — still within the same chat view. If rejected with feedback, a new revised plan card appears below.

#### Current State
- `PlanView.swift` is **fully implemented** (194 lines) — shows summary, numbered steps with estimated times, approve/reject buttons, feedback text input. Can be adapted into an inline card component.
- `TaskFlowState.planning(task:plan:)` exists in `TaskFlowModels.swift:111` — will be simplified
- `TaskService.approvePlan()` at `TaskService.swift:106-119` sends approval to backend and starts the agent
- `TaskService.rejectPlan()` at `TaskService.swift:121-131` sends feedback to backend
- Backend `workforce.tasks.approve` at `index.ts:137-161` handles approval/rejection, updates stage
- **BUT**: No code ever generates a plan. Nothing produces `PlanPayload` data.

#### Gap Analysis
- No plan generation logic exists anywhere in the backend
- No transition from clarification → plan generation
- `PlanPayload` struct exists in Swift but no backend code produces the matching JSON
- `ChatBubbleView` cannot render a plan approval card
- `TaskActivity.ActivityType` doesn't include a `.plan` type

#### Frontend Work
1. `[FE][NEW]` Create `Components/Cards/PlanCardView.swift` — Inline plan card adapted from `PlanView.swift`:
   ```swift
   struct PlanCardView: View {
       let plan: PlanPayload
       let onApprove: () -> Void
       let onReject: (String) -> Void  // feedback text
       let onCancel: () -> Void
       @State private var isApproved = false
       @State private var showFeedbackField = false
       @State private var feedbackText = ""
       // Renders: summary, numbered steps, time estimates
       // After approval: read-only with "Approved" badge
   }
   ```
2. `[FE][MOD]` `TaskChatView.swift:107-114` — Render `.plan` role messages using `PlanCardView` instead of `ChatBubbleView` (already outlined in F3 card routing logic)
3. `[FE][MOD]` `TaskChatView.swift:27-69` (`chatMessages`) — Handle `.plan` activity type by creating a plan-role `ChatMessage`
4. `[FE][MOD]` `TaskService.swift:106-119` (`approvePlan`) — Works correctly already. Ensure it triggers agent start and that subsequent execution events render as progress cards in the same chat.

#### Backend Work
1. `[BE][NEW]` Create `BE/src/plan-generator.ts` — Generates an execution plan from the enriched brief:
   ```typescript
   export function generatePlan(brief: string, employee: EmployeeConfig, clarifications?: object): PlanPayload
   ```
   Recommended approach: **(C) Agent-driven** — the agent generates the plan as its first action via the `before_agent_start` hook injecting a "generate a structured plan first" instruction. The plan is emitted as a structured `workforce.task.plan` event that the frontend parses into a plan card.
2. `[BE][MOD]` `index.ts:109-134` (`workforce.tasks.clarify`) — After receiving clarification answers, generate plan and emit `workforce.task.plan` event via WebSocket
3. `[BE][MOD]` `index.ts:76-106` (`workforce.tasks.create`) — For clear briefs that skip clarification, generate plan immediately and emit event
4. `[BE][MOD]` `index.ts:137-161` (`workforce.tasks.approve`) — On rejection with feedback, regenerate plan and emit a new `workforce.task.plan` event. On approval, start agent execution.
5. `[BE][MOD]` `task-store.ts:22-37` — Store the plan in `TaskManifest.planPayload` so it survives across requests

#### Acceptance Criteria
- [ ] After clarification (or immediately for clear briefs), an inline plan card appears in the chat
- [ ] Plan card shows summary, numbered steps, and estimated time
- [ ] User can approve the plan inline — execution begins in the same chat
- [ ] User can reject with feedback — a revised plan card appears below the original
- [ ] User can cancel — task ends cleanly
- [ ] Approved plan card becomes read-only with "Approved" badge
- [ ] Plan content reflects the employee's specialty (Emma plans web work, David plans data work)

---

## Phase: Watching Them Work

### F5: Rich Execution Progress — P0

#### Customer Need
> "When my employee is working, I want to see meaningful progress — not just text scrolling by. I want to see which stage they're in, what they just accomplished, and how far along they are. All within the same conversation where I gave the instructions."

#### Architecture: Progress Cards & Persistent Status in Chat

Execution progress renders within `TaskChatView` through four mechanisms — all inline in the chat, no navigation to separate views:

1. **Persistent Progress Header** — A sticky/pinned progress indicator at the top of the chat (below the `ChatHeaderView`), showing current stage and progress percentage. Always visible during execution.
2. **Milestone Cards** — Inline cards in the chat scroll marking significant events: "Created homepage.html", "Build passed", "Deployed to localhost:3000". Compact visual style (icon + label + timestamp), distinct from text bubbles.
3. **Stage Transition Cards** — When the agent moves between stages (research → build → test → deploy), a visual divider card appears in the chat marking the transition.
4. **Agent Activity Stream** — The existing `AgentThinkingStreamView` (`TaskChatView.swift:117-119`) continues showing real-time thinking/tool activity. Human-friendly labels replace raw tool names.

#### Current State
- `TaskProgressView.swift` is **fully implemented** (123 lines) — its stage indicator, progress bar, and activity log components can be adapted for inline use
- `StageIndicatorView.swift` renders a visual 5-stage pipeline — can be adapted into the persistent progress header
- `ActivityLogView.swift` displays task activities with icons and timestamps
- `ProgressBarView.swift` renders an animated progress bar
- `AgentThinkingStreamView` in `TaskChatView.swift:117-119` already shows real-time internal activities (thinking, tool calls, tool results) during execution
- `TaskChatView.swift:121-124` shows a typing indicator when the agent is working
- Event bridge (`event-bridge.ts:64-68`) does stage detection via text heuristics
- Progress computation (`event-bridge.ts:201-206`) uses logarithmic formula based on activity count
- **The chat view is already the primary execution view.** The gap is that execution progress within the chat is limited to text bubbles and the thinking stream — no milestone cards, no persistent progress bar, no stage transitions.

#### Gap Analysis
- No persistent progress indicator in `TaskChatView` (progress bar only exists in standalone `TaskProgressView`)
- No milestone card component for the chat
- No stage transition card/divider in the chat
- Activity descriptions are raw tool names ("Using write_file") not human-friendly ("Creating homepage.html")
- Stage detection via text heuristics is unreliable
- Progress is artificial (event count, not actual plan-step completion)
- `AgentThinkingStreamView` shows raw activities without user-friendly translation

#### Frontend Work
1. `[FE][NEW]` Create `Components/Cards/MilestoneCardView.swift` — Compact inline card for milestones:
   ```swift
   struct MilestoneCardView: View {
       let icon: String       // SF Symbol name
       let label: String      // "Created homepage.html"
       let timestamp: Date
       // Compact: single line with icon, label, relative time
       // Styled distinctly from chat bubbles (e.g., centered, muted color)
   }
   ```
2. `[FE][NEW]` Create `Components/Cards/StageTransitionCardView.swift` — Visual divider marking stage changes:
   ```swift
   struct StageTransitionCardView: View {
       let fromStage: String  // "Research"
       let toStage: String    // "Building"
       let timestamp: Date
       // Renders as a horizontal divider with stage labels and arrow
   }
   ```
3. `[FE][NEW]` Create `Components/ChatProgressHeaderView.swift` — Persistent sticky progress indicator pinned below `ChatHeaderView`:
   ```swift
   struct ChatProgressHeaderView: View {
       let currentStage: String
       let progress: Double       // 0.0-1.0
       let stageSteps: [String]   // All stages for the mini pipeline
       // Compact bar: stage label + mini progress bar + percentage
       // Adapts StageIndicatorView into a horizontal compact form
   }
   ```
4. `[FE][MOD]` `TaskChatView.swift:97-103` — Add `ChatProgressHeaderView` between `ChatHeaderView` and the `ScrollView` (only visible when task status is `.running` or `.pending`)
5. `[FE][MOD]` `TaskChatView.swift:27-69` (`chatMessages`) — Handle `.milestone` and `.stageTransition` activity types, creating card-role `ChatMessage` entries rendered as `MilestoneCardView` and `StageTransitionCardView`
6. `[FE][MOD]` `AgentThinkingStreamView.swift` — Translate raw tool names to human-readable descriptions:
   - "Using write_file" → "Creating homepage.html" (extract file name from tool args)
   - "Using bash" → "Running build process"
   - "Using read_file" → "Reading project configuration"

#### Backend Work
1. `[BE][MOD]` `event-bridge.ts:116-138` (`buildToolActivity`) — Generate human-friendly activity messages using file paths and tool context from the tool call arguments
2. `[BE][MOD]` `event-bridge.ts:182-198` (`detectStageFromText`) — Replace text heuristic detection with tool-based detection:
   - Research/read tools used → "research" stage
   - Write/create tools used → "build" stage
   - Test/validate tools used → "test" stage
   - Deploy/serve tools used → "deploy" stage
3. `[BE][MOD]` `event-bridge.ts:200-206` (`computeProgress`) — Replace logarithmic formula with plan-aware progress:
   - If a plan exists with N steps, track which step the agent is on
   - Use tool call patterns to estimate step completion
   - Fall back to current formula only if no plan exists
4. `[BE][NEW]` Add milestone detection in `event-bridge.ts` — Emit `workforce.task.milestone` events for significant moments (file created, test passed, build complete, deploy done)
5. `[BE][NEW]` Add stage transition events — Emit `workforce.task.stage_transition` with `fromStage` and `toStage` so the chat can render transition divider cards

#### Acceptance Criteria
- [ ] During execution, a persistent progress header shows current stage and percentage at the top of the chat
- [ ] Milestone cards appear inline in the chat for significant events (file created, build passed, deployed)
- [ ] Stage transitions are visually marked with divider cards in the chat
- [ ] Activity descriptions are human-readable, not raw tool names
- [ ] Progress percentage is meaningful (tied to plan steps when available)
- [ ] User can still see agent thinking stream for detailed real-time activity
- [ ] All progress appears within the same chat view — no navigation to separate views

---

### F6: Background Notifications — P1

#### Customer Need
> "I want to keep working on other things while my employee runs a task. I need to be notified when they finish, when they fail, or when they need my input (like approval for a plan)."

#### Current State
- No notification support exists anywhere in the codebase
- Task completion is detected via `workforce.task.completed` event (`TaskService.swift:372-374`) but only updates internal state
- Task failure is detected via `workforce.task.failed` event (`TaskService.swift:376-383`) but only updates internal state
- The app has no `NSUserNotificationCenter` or `UNUserNotificationCenter` integration

#### Gap Analysis
- No macOS notification permission request
- No notification delivery for any task lifecycle event
- No badge count on the app icon
- No sound feedback for task completion
- When a task needs clarification or plan approval, the user has no way to know unless they're looking at the app

#### Frontend Work
1. `[FE][NEW]` Create `Services/NotificationService.swift` — Manages macOS notification permissions and delivery:
   - Request notification permission on first use
   - `notifyTaskCompleted(task:employee:)` — "Emma finished building your website"
   - `notifyTaskFailed(task:employee:error:)` — "David encountered an error with your data analysis"
   - `notifyTaskNeedsInput(task:employee:stage:)` — "Sarah has a question about your research requirements"
   - `notifyMilestone(task:employee:milestone:)` — "Emma created homepage.html"
2. `[FE][MOD]` `TaskService.swift:372-374` — After marking task completed, call `NotificationService.notifyTaskCompleted()`
3. `[FE][MOD]` `TaskService.swift:376-383` — After marking task failed, call `NotificationService.notifyTaskFailed()`
4. `[FE][MOD]` `WorkforceApp.swift` — Request notification permission during app startup
5. `[FE][NEW]` Add app icon badge count for active tasks needing attention

#### Backend Work
- No backend changes needed — the event system already broadcasts all necessary events. The frontend just needs to react to them with OS-level notifications.

#### Acceptance Criteria
- [ ] User receives macOS notification when a task completes
- [ ] User receives notification when a task fails with error context
- [ ] User receives notification when an employee needs input (clarification or plan approval)
- [ ] Clicking a notification brings the app to the relevant task view
- [ ] Notifications respect macOS Do Not Disturb settings
- [ ] Notifications can be disabled in app settings

---

## Phase: Reviewing Results

### F7: Output Review & Content-Specific Previews — P0

#### Customer Need
> "When my employee finishes work, I want to see the result right there in our conversation. If Emma built a website, show me the live site. If David created a deck, show me the slides. Each employee produces different things — the app should know what to show me and how."

#### Architecture: Inline Output Preview Cards in Chat

When an employee completes work, an **output preview card** appears inline in the chat — rendered specifically for the content type that employee produces. This is the most critical "wow moment" of the product: the user sees the actual result embedded in their conversation.

The chat view routes to the correct renderer based on the **employee's content type** (not just file extension):

```swift
// In TaskChatView's ForEach(chatMessages) routing:
case .outputPreview(let output):
    switch employee.contentType {
    case .web:          WebPreviewCard(output: output)
    case .slides:       SlideGalleryCard(output: output)
    case .document:     DocumentPreviewCard(output: output)
    case .imageGallery: ImageGalleryCard(output: output)   // Future
    case .video:        VideoPlayerCard(output: output)     // Future
    case .audio:        AudioPlayerCard(output: output)     // Future
    case .chart:        ChartPreviewCard(output: output)    // Future
    }
```

#### Per-Employee Output Classification Table

| Employee | Role | Primary Output | Content Type | Renderer Component | Trigger Condition | V1 Scope |
|----------|------|---------------|--------------|-------------------|-------------------|----------|
| **Emma** | Web Developer | Website | `web` | `WebPreviewCard` | localhost URL detected or HTML files produced | **Yes** |
| **David** | Designer | Presentation | `slides` | `SlideGalleryCard` | `.pptx`/`.key` file produced or slide images generated | **Yes** |
| **Sarah** | Researcher | Research Report | `document` | `DocumentPreviewCard` | `.md`/`.txt`/`.pdf` file produced | **Yes** |
| **Alex** | Writer | Written Content | `document` | `DocumentPreviewCard` | `.md`/`.txt`/`.docx` file produced | Future |
| **Maya** | Illustrator | Images | `imageGallery` | `ImageGalleryCard` | `.png`/`.jpg`/`.svg` files produced | Future |
| **Ryan** | Videographer | Video | `video` | `VideoPlayerCard` | `.mp4`/`.mov` file produced | Future |
| **Luna** | Audio Producer | Audio | `audio` | `AudioPlayerCard` | `.mp3`/`.wav` file produced | Future |
| **Marcus** | Analyst | Dashboard/Charts | `chart` | `ChartPreviewCard` | Chart data JSON or `.csv`/`.xlsx` produced | Future |

**V1 implementation**: Emma (`WebPreviewCard`), David (`SlideGalleryCard`), Sarah (`DocumentPreviewCard`)

#### Execution Patterns by Content Type

**Type A: Streamable Work** — Emma, Sarah, Alex, Marcus

Work can be previewed incrementally as the agent produces it. The output preview card appears in the chat *during* execution and updates live:
- **Emma**: WKWebView refreshes as the website is built, showing real-time preview of the site
- **Sarah/Alex**: Document preview updates as sections are written, rendered markdown appearing progressively
- **Marcus**: Charts render progressively as data is processed

For Type A, the output card has two states:
1. **Live preview** (during execution) — Shows partial/updating content with a "Building..." indicator
2. **Final preview** (after completion) — Full content with action buttons (Open, Download, Request Changes)

```
┌─────────────────────────────────────────────────────────────┐
│  🌐 Emma is building your website...                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                                                        │ │
│  │         [Live WKWebView — localhost:3000]              │ │
│  │         Auto-refreshes as files change                 │ │
│  │                                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ████████████████████░░░░░░░  65%  ~2 min remaining         │
│                                                              │
│  [Expand ↗]                                                  │
└─────────────────────────────────────────────────────────────┘
```

**Type B: Generation Work** — Maya, Ryan, Luna

Work happens in a black box (external API call), then results appear all at once. During execution, the chat shows a branded waiting card:

```
┌─────────────────────────────────────────────────────────────┐
│  🎨 Maya is creating your images...                         │
│                                                              │
│  ████████████░░░░░░░░  ~30 seconds                          │
│                                                              │
│  Creating 4 variations based on:                             │
│  "Modern tech aesthetic, blue gradient, bold typography"     │
└─────────────────────────────────────────────────────────────┘
```

When generation completes, the waiting card is replaced by the full output preview card (e.g., `ImageGalleryCard` with the 4 generated images).

#### Output Renderer Specifications

##### `WebPreviewCard` — V1 (Emma)

**Renders**: Live website preview within the chat conversation

```swift
struct WebPreviewCard: View {
    let output: TaskOutput           // Contains URL and metadata
    let isLive: Bool                 // true during execution, false after completion
    @State private var isExpanded = false

    // Compact: 400×250 inline WKWebView preview with "Expand" button
    // Expanded: near-full-width preview with URL bar
    // Actions: "Open in Browser", "Download Files", "Request Changes"
}
```

- **WKWebView** configured for localhost access (sandboxed, no external network)
- Auto-refreshes during execution when file changes are detected by the backend
- Compact mode shows a constrained preview; tap "Expand" for full-width view
- Shows URL bar with the localhost address (e.g., `localhost:3000`)
- **Trigger**: Backend detects `localhost:XXXX` URL in agent output or dev server start pattern
- **Security**: See AD-4 for WKWebView sandboxing decisions

##### `SlideGalleryCard` — V1 (David)

**Renders**: Slide deck preview with navigation in the chat

```swift
struct SlideGalleryCard: View {
    let slides: [SlidePreview]       // Array of slide images + metadata
    @State private var selectedSlide = 0
    @State private var isExpanded = false

    // Large preview of selected slide (16:9 aspect ratio)
    // Horizontal thumbnail strip below for navigation
    // Slide counter: "Slide 3 of 12"
    // Per-slide feedback: tap a slide to leave feedback on it
    // Actions: "Download PPTX", "Edit Slide", "Add Slide", "Request Changes"
}
```

- Backend generates slide preview images (PNG per slide) during deck creation
- Thumbnail strip uses horizontal scroll for decks with many slides
- Per-slide feedback: "Edit slide 3: Too much text, simplify to 3 bullets"
- **Trigger**: Backend detects `.pptx`/`.key`/`.pdf` presentation file produced
- Compact shows first slide + thumbnail count; expanded shows full gallery

##### `DocumentPreviewCard` — V1 (Sarah, Alex)

**Renders**: Formatted text/markdown content inline in the chat

```swift
struct DocumentPreviewCard: View {
    let content: String              // Markdown or plain text
    let title: String
    let wordCount: Int
    @State private var isExpanded = false

    // Compact: first ~200 words rendered with "Read more..." button
    // Expanded: full document with sections, headings, formatting
    // Footer: word count, reading time
    // Actions: "Download", "Copy to Clipboard", "Request Changes"
}
```

- Renders markdown to `AttributedString` for rich formatting (headings, lists, bold/italic, code blocks)
- Compact mode shows first ~200 words with "Read more..." expansion
- Section headings, bullet lists, bold/italic all render properly
- Word count and estimated reading time shown in footer
- **Trigger**: Backend detects `.md`/`.txt`/`.pdf`/`.docx` file produced

##### `ImageGalleryCard` — Future (Maya)

**Renders**: Grid of generated images with selection

```swift
struct ImageGalleryCard: View {
    let images: [ImageOutput]        // Array of generated images with paths/URLs
    @State private var selectedImages: Set<String> = []

    // 2×2 grid of image thumbnails (or 1×N for single images)
    // Tap to view full-size with zoom
    // Checkbox selection for batch operations
    // Actions: "Download Selected", "Regenerate", "Adjust Selected"
}
```

##### `VideoPlayerCard` — Future (Ryan)

**Renders**: Video player with scene timeline

```swift
struct VideoPlayerCard: View {
    let videoURL: URL
    let scenes: [VideoScene]         // Scene markers with timestamps and labels

    // Inline video player (AVPlayerView)
    // Scene timeline strip below player (visual segments)
    // Actions: "Download MP4", "Revise Scene", "Regenerate"
}
```

##### `AudioPlayerCard` — Future (Luna)

**Renders**: Audio waveform player with synchronized script

```swift
struct AudioPlayerCard: View {
    let audioURL: URL
    let script: [ScriptSegment]      // Timestamped script sections
    let voiceName: String

    // Waveform visualization with playback controls
    // Synchronized script display (highlights current section during playback)
    // Actions: "Download MP3", "Change Voice", "Edit Section"
}
```

##### `ChartPreviewCard` — Future (Marcus)

**Renders**: Interactive data dashboard

```swift
struct ChartPreviewCard: View {
    let charts: [ChartData]
    let summary: String

    // Rendered charts (bar, line, pie) using Swift Charts framework
    // Summary text above charts
    // Actions: "Download CSV", "Export PDF", "Adjust Analysis"
}
```

##### `OutputWaitingCard` — V1 (all Type B employees)

**Renders**: Branded waiting experience during generation work

```swift
struct OutputWaitingCard: View {
    let employee: Employee
    let description: String          // "Creating 4 variations based on: ..."
    let estimatedTime: String?       // "~30 seconds"

    // Employee emoji + "{Name} is creating your {output type}..."
    // Simple progress indicator (indeterminate or estimated)
    // Brief description of what's being generated
    // Replaced by the actual output card when generation completes
}
```

#### Current State
- `OutputReviewView.swift` is **fully implemented** (216 lines) — shows output list with type icons, "Open"/"Show in Finder" buttons, revision input, approval controls. Components can be adapted for inline card use.
- `TaskOutput.swift` has `OutputType` enum with `file`, `website`, `document`, `image`, `unknown`
- `event-bridge.ts:140-171` (`detectOutput`) classifies outputs by file extension and detects localhost URLs
- Backend `workforce.outputs.open` at `index.ts:248-272` runs `open` command; `workforce.outputs.reveal` at `index.ts:275-296` runs `open -R`
- **BUT**: Output review only shows file names with type icons. No inline previews, no content-type-specific rendering, no live preview during execution.

#### Gap Analysis
- No inline preview for any output type — only file name lists
- No content-type-specific card components exist
- `ChatMessage.Role` doesn't support output preview cards
- `TaskActivity.ActivityType` doesn't include `.outputPreview` type
- `OutputType` classification is basic — doesn't distinguish presentations, code, audio, video
- Event bridge detects outputs but doesn't generate preview data (thumbnails, rendered content, URLs)
- No live preview during execution for Type A (streamable) work
- Backend doesn't generate slide preview images or document preview content
- `Employee` model has no `contentType` field — frontend can't determine which renderer to use
- No `OutputWaitingCard` for Type B generation work

#### Frontend Work
1. `[FE][NEW]` Create `Components/Cards/WebPreviewCard.swift` — WKWebView wrapper for inline website preview with compact/expanded modes (spec above)
2. `[FE][NEW]` Create `Components/Cards/SlideGalleryCard.swift` — Slide preview with large preview + horizontal thumbnail strip + navigation (spec above)
3. `[FE][NEW]` Create `Components/Cards/DocumentPreviewCard.swift` — Markdown/text rendering with compact/expanded modes using `AttributedString` (spec above)
4. `[FE][NEW]` Create `Components/Cards/OutputWaitingCard.swift` — Branded waiting card for Type B generation work (spec above)
5. `[FE][MOD]` `TaskChatView.swift:27-69` (`chatMessages`) — Handle `.outputPreview` activity type, map to appropriate card component based on the employee's `contentType`
6. `[FE][MOD]` `TaskChatView.swift:107-114` — Render output cards using the correct renderer based on the employee:
   ```swift
   case .outputPreview(let output):
       switch employee.contentType {
       case .web:      WebPreviewCard(output: output, isLive: self.isAgentWorking)
       case .slides:   SlideGalleryCard(slides: output.slideData ?? [])
       case .document: DocumentPreviewCard(content: output.content ?? "", title: output.label, wordCount: output.metadata?.wordCount ?? 0)
       default:        OutputFileRow(output: output) // fallback
       }
   ```
7. `[FE][MOD]` `Models/TaskOutput.swift` — Extend `OutputType` enum:
   ```swift
   enum OutputType: String, Codable {
       case file, website, document, image, unknown  // existing
       case presentation, spreadsheet, code, audio, video, chart  // new
   }
   ```
   Add `previewData` field:
   ```swift
   struct TaskOutput {
       // ...existing fields...
       var previewData: PreviewData?
   }
   struct PreviewData: Codable {
       var url: URL?           // For web previews
       var content: String?    // For document text
       var thumbnails: [URL]?  // For slide/image previews
       var metadata: OutputMetadata?
   }
   struct OutputMetadata: Codable {
       var width: Int?
       var height: Int?
       var wordCount: Int?
       var slideCount: Int?
       var duration: Double?   // For audio/video
   }
   ```
8. `[FE][MOD]` `Models/Employee.swift` — Add `contentType` field so the frontend knows which renderer to use:
   ```swift
   enum ContentType: String, Codable {
       case web, slides, document, imageGallery, video, audio, chart
   }
   struct Employee {
       // ...existing fields...
       let contentType: ContentType
   }
   ```

#### Backend Work
1. `[BE][MOD]` `event-bridge.ts:140-171` (`detectOutput`) — Enhanced output detection with preview data generation:
   - Detect dev server start (parse "Server running on localhost:XXXX" patterns) → emit output with `previewData.url`
   - For documents: Read first N lines of content for preview → include in `previewData.content`
   - For presentations: Track slide count and file path → include in `previewData.metadata.slideCount`
   - Extract file metadata (dimensions for images, word count for documents)
   - Map output to employee's expected content type for correct renderer selection
2. `[BE][MOD]` `event-bridge.ts:173-178` (`classifyOutputType`) — Expanded classification:
   ```typescript
   if (["pptx", "ppt", "key"].includes(ext)) return "presentation";
   if (["csv", "xlsx", "xls"].includes(ext)) return "spreadsheet";
   if (["mp4", "mov", "webm"].includes(ext)) return "video";
   if (["mp3", "wav", "aac"].includes(ext)) return "audio";
   if (["js", "ts", "py", "swift"].includes(ext)) return "code";
   ```
3. `[BE][NEW]` Create `BE/src/preview-generator.ts` — Generates preview data for outputs:
   ```typescript
   export function generatePreviewData(output: TaskOutput, employee: EmployeeConfig): PreviewPayload
   ```
   - For websites: Returns the localhost URL for WKWebView to load
   - For documents: Returns rendered content (first 200 words for compact, full for expanded)
   - For presentations: Returns slide count and thumbnail file paths (generated via conversion tool)
   - For images: Returns image paths with dimensions
4. `[BE][MOD]` `task-store.ts:13-20` (`TaskOutput` type) — Add `previewData?: { url?: string, content?: string, thumbnails?: string[], metadata?: object }` field
5. `[BE][MOD]` `employees.ts` — Add `contentType` to `EmployeeConfig`:
   ```typescript
   export type EmployeeConfig = {
     // ...existing fields...
     contentType: "web" | "slides" | "document" | "imageGallery" | "video" | "audio" | "chart";
   };
   // Emma: contentType: "web"
   // David: contentType: "slides"
   // Sarah: contentType: "document"
   ```
6. `[BE][MOD]` Emit `workforce.task.output_preview` event when outputs are detected, including `previewData` payload so the frontend can render the appropriate card immediately
7. `[BE][MOD]` For Type A (streamable) employees, emit incremental `workforce.task.output_preview` events as the output evolves (e.g., each time Emma's dev server reloads, emit an update event so the WebPreviewCard refreshes)

#### Acceptance Criteria
- [ ] Emma's completed website shows a live WKWebView preview inline in the chat
- [ ] Emma's WKWebView auto-refreshes during execution as the site is built (Type A live preview)
- [ ] David's completed deck shows slide thumbnails with large preview and navigation inline in the chat
- [ ] Sarah's completed report shows rendered markdown content inline in the chat (compact + expandable)
- [ ] During Type A execution (Emma/Sarah), the preview card updates live as work progresses
- [ ] During Type B execution (Maya/Ryan/Luna future), a branded `OutputWaitingCard` shows until results appear
- [ ] Output preview cards have action buttons: Open, Download, Request Changes
- [ ] Each preview has compact and expanded modes (tap to expand full-width)
- [ ] Correct renderer is selected based on employee's `contentType` field, not file extension alone
- [ ] "Open in external app" still available as secondary action on all preview cards
- [ ] Preview appears automatically when output is detected — no user action required

---

### F8: Feedback & Targeted Revision — P1

#### Customer Need
> "The website my employee built is good, but the header color is wrong and the footer text needs updating. I want to give specific feedback about specific parts — not just a text box that says 'fix it.' And when I request changes, my employee should only change what I asked about."

#### Current State
- `OutputReviewView.swift:81-94` has a revision input — a simple `TextEditor` for free-text feedback
- `TaskService.requestRevision()` at `TaskService.swift:171-186` sends revision feedback and restarts the agent with "Revision requested:\n{feedback}"
- Backend `workforce.tasks.revise` at `index.ts:222-245` appends feedback to brief and resets to running/execute state
- The revision approach is blunt — the entire brief gets a "## Revision Request" section appended, and the agent restarts with the full accumulated context

#### Gap Analysis
- No output-specific feedback (can't say "fix this specific file" or "change this part")
- No inline annotation (can't mark up the preview with comments)
- No diff view showing what changed between original and revision
- Revision restarts the whole agent instead of doing targeted fixes
- No revision history (can't see what was changed)
- No partial approval (can't approve some outputs and request changes on others)

#### Frontend Work
1. `[FE][MOD]` `OutputReviewView.swift` — Add per-output feedback buttons (each output card gets a "Request Changes" option)
2. `[FE][NEW]` Create `Views/Outputs/RevisionAnnotationView.swift` — For text/document outputs, allow inline highlighting and commenting
3. `[FE][MOD]` `OutputReviewView.swift:150-184` (controls) — Add "Approve Some, Revise Others" flow where user checks off approved outputs and provides feedback per rejected output
4. `[FE][NEW]` Create `Views/Outputs/RevisionDiffView.swift` — Show before/after comparison for revised outputs

#### Backend Work
1. `[BE][MOD]` `index.ts:222-245` (`workforce.tasks.revise`) — Accept per-output feedback:
   ```typescript
   params: {
     taskId: string;
     feedback: string;
     targetOutputIds?: string[];  // Which specific outputs to revise
   }
   ```
2. `[BE][MOD]` `event-bridge.ts` — Track revision history on outputs (version numbers, diff metadata)
3. `[BE][MOD]` `task-store.ts` — Add `revisionHistory: { feedback: string, timestamp: string }[]` to `TaskManifest`

#### Acceptance Criteria
- [ ] User can give feedback on specific outputs, not just the task as a whole
- [ ] Revision preserves approved outputs and only changes targeted ones
- [ ] User can see what changed between the original and revised version
- [ ] Revision history is preserved and viewable
- [ ] Multiple revision cycles are supported without context degradation

---

## Phase: Managing Your Team

### F9: Dashboard & Team Overview — P1

#### Customer Need
> "I want to open the app and immediately see what's happening: which employees are busy, which tasks are running, recent completions, and any tasks that need my attention. Like a team standup at a glance."

#### Current State
- Dashboard sidebar item exists in `SidebarView.swift` but routes to a placeholder: "Team overview and activity feed coming soon" (`MainWindowView.swift:212-217`)
- `TaskDashboardView.swift` (265 lines) is **fully implemented** as a "Global History" view with search, filters (All/Active/Completed/Failed), and task list — but it's mapped to the "Tasks" sidebar item, not "Dashboard"
- Employee status tracking works via `workforce.employee.status` events (`EmployeeService.swift`)
- No aggregate statistics, no activity feed, no "needs attention" queue

#### Gap Analysis
- No actual dashboard view — the placeholder is never replaced
- TaskDashboardView functions as task history, not team overview
- No summary statistics (tasks completed today, success rate, active employees)
- No "needs attention" section for tasks awaiting clarification or plan approval
- No recent activity feed showing latest events across all tasks
- No employee status grid showing who's busy/idle/offline
- The floating bottom bar in `TaskDashboardView.swift:217-264` has non-functional buttons (mic, send, calendar, download)

#### Frontend Work
1. `[FE][NEW]` Create `Views/Dashboard/DashboardView.swift` — Team overview with sections:
   - **Team Status**: Grid of employee cards showing current status and active task
   - **Needs Attention**: Tasks awaiting user input (clarification, plan approval, review)
   - **Active Tasks**: Currently running tasks with progress indicators
   - **Recent Activity**: Feed of latest events (task completed, output generated, etc.)
   - **Statistics**: Tasks completed today/week, success rate, average time per task
2. `[FE][MOD]` `MainWindowView.swift:212-217` — Replace dashboard placeholder with `DashboardView`
3. `[FE][MOD]` `TaskDashboardView.swift:217-264` — Wire up the floating bottom bar buttons or remove non-functional UI elements
4. `[FE][MOD]` `TaskDashboardView.swift:142-152` — Wire up the calendar and download header buttons

#### Backend Work
1. `[BE][NEW]` Add `workforce.dashboard.summary` gateway method — Returns aggregate stats:
   ```typescript
   {
     activeTaskCount: number,
     completedToday: number,
     needsAttention: TaskManifest[],  // Tasks in clarify/plan stage
     recentActivity: TaskActivity[],  // Latest 20 events across all tasks
     employeeUtilization: { employeeId: string, taskCount: number, avgTime: number }[]
   }
   ```
2. `[BE][MOD]` `task-store.ts` — Add query functions: `getTasksNeedingAttention()`, `getCompletedSince(date)`, `getRecentActivities(limit)`

#### Acceptance Criteria
- [ ] Dashboard shows real team status at a glance
- [ ] "Needs Attention" section highlights tasks waiting for user input
- [ ] Active tasks show live progress
- [ ] Recent activity feed updates in real-time
- [ ] Statistics are accurate and update as tasks complete
- [ ] Clicking any item navigates to the appropriate view

---

### F10: Task History & Search — P2

#### Customer Need
> "I've been using the app for weeks. I want to find that website Emma built last month, or see all of David's completed analyses. I need to search, filter, and browse my task history easily."

#### Current State
- `TaskDashboardView.swift` already has search and filter functionality (search by description or employee name, filter by status)
- `TaskService.fetchTasks()` at `TaskService.swift:214-223` fetches tasks via `workforce.tasks.list`
- Backend `workforce.tasks.list` at `index.ts:164-179` supports `limit`, `offset`, and `status` filtering
- `TaskRowView.swift` renders task rows with employee, description, status, and timestamp

#### Gap Analysis
- No date range filtering
- No employee-specific filtering (see all of Emma's tasks)
- No full-text search in task outputs (search for content within completed files)
- No pagination UI (backend supports offset/limit but frontend loads all at once)
- No task archiving or deletion
- No export of task results

#### Frontend Work
1. `[FE][MOD]` `TaskDashboardView.swift` — Add employee filter dropdown and date range picker
2. `[FE][MOD]` `TaskDashboardView.swift:192-213` — Add pagination (load more on scroll) using the backend's `hasMore` response
3. `[FE][NEW]` Create `Views/Tasks/TaskDetailView.swift` — Full task detail view showing brief, clarification Q&A, plan, execution log, and all outputs in one scrollable page
4. `[FE][MOD]` `TaskDashboardView.swift` — Add sort options (newest, oldest, by employee, by status)

#### Backend Work
1. `[BE][MOD]` `index.ts:164-179` (`workforce.tasks.list`) — Add `employeeId`, `dateFrom`, `dateTo`, `searchQuery` filter parameters
2. `[BE][MOD]` `task-store.ts:95-121` (`listTasks`) — Implement the additional filter queries
3. `[BE][NEW]` Add `workforce.tasks.delete` gateway method for task cleanup
4. `[BE][NEW]` Add `workforce.tasks.export` gateway method — Returns task + outputs as a downloadable archive

#### Acceptance Criteria
- [ ] User can filter tasks by employee, date range, and status
- [ ] Search works across task descriptions and employee names
- [ ] Task list paginates smoothly (no loading all at once)
- [ ] User can view full task detail including the complete lifecycle
- [ ] User can delete old tasks they no longer need

---

## Phase: Growing Together

### F11: Memory Bank & Preferences — P2

#### Customer Need
> "My employees should remember what I like. If I always ask Emma for minimalist websites with blue color schemes, she should learn that preference over time. If David knows I prefer bar charts over pie charts, he should default to that."

#### Current State
- Memory Bank sidebar item exists in `SidebarView.swift` but routes to a placeholder: "Shared knowledge and learned patterns coming soon" (`MainWindowView.swift:242-248`)
- No memory or preference storage anywhere in the codebase
- Each task starts fresh with no context from previous tasks
- `TaskManifest` has no reference to previous tasks or learned preferences

#### Gap Analysis
- No memory storage system
- No preference extraction from completed tasks
- No cross-task context (employee doesn't know about past work)
- No user preference model
- Memory Bank sidebar item is a dead end
- No way to manually teach an employee a preference

#### Frontend Work
1. `[FE][NEW]` Create `Views/Memory/MemoryBankView.swift` — Shows learned preferences organized by employee:
   - List of preferences per employee ("Emma knows you prefer minimalist design")
   - Manual preference entry ("Always use Inter font for websites")
   - Preference editing and deletion
   - Cross-employee shared preferences
2. `[FE][NEW]` Create `Models/MemoryEntry.swift` — `{ id, employeeId, category, content, source, createdAt }`
3. `[FE][NEW]` Create `Services/MemoryService.swift` — CRUD for memory entries via gateway
4. `[FE][MOD]` `MainWindowView.swift:242-248` — Replace Memory Bank placeholder with `MemoryBankView`

#### Backend Work
1. `[BE][NEW]` Create `BE/src/memory-store.ts` — File-based storage for preferences at `~/.openclaw/workforce/memory/`
2. `[BE][NEW]` Add gateway methods:
   - `workforce.memory.list` — List preferences, optionally filtered by employee
   - `workforce.memory.add` — Add a preference manually
   - `workforce.memory.delete` — Remove a preference
3. `[BE][MOD]` `index.ts` (`before_agent_start` hook) — Inject relevant memory entries into the agent's system prompt context
4. `[BE][NEW]` Add post-task preference extraction — After task completion, analyze the task to extract reusable preferences (style choices, tool preferences, communication patterns)

#### Acceptance Criteria
- [ ] Memory Bank shows learned preferences per employee
- [ ] Users can manually add/edit/delete preferences
- [ ] Preferences are injected into future task contexts
- [ ] Employees behave differently based on accumulated preferences
- [ ] Memory persists across app restarts

---

### F12: Error Recovery & Resilience — P1

#### Customer Need
> "When something goes wrong — the AI crashes, the network drops, or a tool fails — I don't want a cryptic error message. I want to know what happened, whether it's recoverable, and what my options are (retry, revise, cancel)."

#### Current State
- `TaskService.swift:78-91` has a try/catch that falls back to creating a local-only task when `workforce.tasks.create` fails
- Backend `event-bridge.ts:97-110` handles lifecycle errors — broadcasts `workforce.task.failed` with error message and `canRetry: true`
- `TaskProgressView.swift:107` shows error message in status label
- `TaskService.swift:376-383` sets error message on task when `workforce.task.failed` is received
- No retry mechanism exists anywhere

#### Gap Analysis
- Error messages are raw and technical (e.g., "Connection refused", "Tool execution failed")
- No user-friendly error classification (network error vs. AI error vs. tool error)
- No retry button or mechanism
- No auto-retry for transient failures (network blips)
- `canRetry: true` is sent from backend but frontend never uses it
- No partial recovery (if agent completed 80% of work, that work is lost on failure)
- No graceful degradation when gateway disconnects mid-task
- `GatewayNotRunningView.swift` shows connection issues but doesn't handle mid-task disconnects

#### Frontend Work
1. `[FE][NEW]` Create `Views/Tasks/TaskErrorView.swift` — User-friendly error display with:
   - Plain English error description
   - What went wrong (network, AI, tool)
   - Recovery options: Retry, Retry with changes, Cancel
   - Link to activity log for technical details
2. `[FE][MOD]` `TaskProgressView.swift` — When task fails, show `TaskErrorView` inline instead of just a status label
3. `[FE][MOD]` `TaskService.swift` — Add `retryTask(id:)` method that re-submits the task with the same brief and clarification answers
4. `[FE][MOD]` `MainWindowView.swift` — Handle gateway disconnect during active task — show reconnection indicator, auto-resume observation on reconnect
5. `[FE][MOD]` `TaskService.swift:376-383` — Check `canRetry` field from the failure event and expose it to the UI

#### Backend Work
1. `[BE][MOD]` `event-bridge.ts:97-110` — Classify errors and include category in the failure event:
   ```typescript
   broadcast("workforce.task.failed", {
     taskId,
     error: errorMessage,
     errorCategory: "network" | "ai" | "tool" | "timeout" | "unknown",
     canRetry: true,
     partialOutputs: task.outputs  // Preserve any outputs generated before failure
   });
   ```
2. `[BE][NEW]` Add `workforce.tasks.retry` gateway method — Restarts a failed task from its last known good state
3. `[BE][MOD]` `task-store.ts` — Add `lastCheckpoint?: { stage, progress, timestamp }` to `TaskManifest` for partial recovery
4. `[BE][MOD]` `index.ts` lifecycle hooks — Add error handling for individual tool failures that don't need to fail the whole task (log the error, skip the tool, continue)

#### Acceptance Criteria
- [ ] Error messages are human-readable with clear recovery options
- [ ] Users can retry failed tasks with one click
- [ ] Transient network errors trigger auto-retry (with backoff)
- [ ] Partial work is preserved and visible even after failure
- [ ] Gateway disconnects during active tasks are handled gracefully (reconnect and resume)
- [ ] Error category helps users understand if the issue is their brief or a system problem

---

## Implementation Sequence

### Dependency Graph

```
F2 (Employee Identity) ─┐
                         ├─► F3 (Clarification) ─► F4 (Plan) ─► F5 (Rich Progress)
F12 (Error Recovery) ────┘                                            │
                                                                      ▼
F1 (Onboarding) ◄──────────────────────────── F7 (Output Preview)
                                                      │
                                                      ▼
                                               F8 (Feedback/Revision)

F6 (Notifications) ── independent, can ship anytime after F5
F9 (Dashboard) ── independent, can ship anytime
F10 (Task History) ── builds on F9
F11 (Memory Bank) ── builds on F2, can ship anytime after F2
```

### Recommended Build Order

**Sprint 1: Foundation + Card System (P0 core)**
1. **F2 — Employee Identity** — Add system prompts, personality, and `contentType` field to employees. This is the foundation that makes everything else meaningful.
2. **F3 — Smart Clarification** — Build brief analyzer, extend `ChatMessage.Role` with card types, create `ClarificationCardView`, emit `workforce.task.clarification` events. The biggest single change — it establishes the inline card pattern used by all subsequent features.
3. **F4 — Plan Generation** — Build plan generator, create `PlanCardView`, emit `workforce.task.plan` events. Extends the card pattern established in F3.

**Sprint 2: Execution & Output Cards (P0 completeness)**
4. **F5 — Rich Execution Progress** — Create `MilestoneCardView`, `StageTransitionCardView`, `ChatProgressHeaderView`. Improve stage detection and activity descriptions in the event bridge.
5. **F7 — Output Preview** — Build content-type specific preview cards (`WebPreviewCard`, `SlideGalleryCard`, `DocumentPreviewCard`, `OutputWaitingCard`). The "wow moment" of the product.

**Sprint 3: Resilience & Awareness (P1)**
6. **F12 — Error Recovery** — Classify errors, add retry mechanism, handle disconnects.
7. **F6 — Background Notifications** — Add macOS notification support for task lifecycle events.

**Sprint 4: Team Management (P1)**
8. **F9 — Dashboard** — Build real team overview to replace placeholder.
9. **F8 — Feedback & Revision** — Add per-output feedback and diff views.
10. **F1 — Onboarding** — Build first-run experience (best to build this after the full flow works).

**Sprint 5: Depth (P2)**
11. **F10 — Task History** — Enhanced search, filtering, pagination.
12. **F11 — Memory Bank** — Preference storage and cross-task context.

---

## Architecture Decisions Needed

### AD-1: Clarification Question Generation
**Options:**
- **(A) Rule-based templates**: Each employee has predefined question trees based on brief keyword analysis. Fast, deterministic, zero-cost. Limited to anticipated scenarios.
- **(B) LLM-based generation**: Short AI call analyzes the brief and generates contextual questions. Smarter, handles any brief. Adds latency and API cost per task.
- **(C) Hybrid**: Rule-based defaults with LLM fallback for ambiguous briefs.

**Recommendation**: Start with (A) for v1 — it's fast and predictable. Plan for (C) in v1.1.

### AD-2: Plan Generation
**Options:**
- **(A) Template-based plans**: Employee-specific plan templates filled with brief details. Fast, consistent structure.
- **(B) LLM-generated plans**: AI generates custom plans per brief. More flexible, handles novel tasks.
- **(C) Agent-driven plans**: Let the agent itself generate the plan as its first action before executing.

**Recommendation**: (C) is the most natural fit — the agent already has the context. The `before_agent_start` hook injects a "generate a plan first" instruction. The plan is emitted as a structured event that the frontend parses.

### AD-3: Employee System Prompt Injection
**Options:**
- **(A) Plugin hook injection**: The `before_agent_start` hook sets `ctx.systemPrompt` on the agent context.
- **(B) Agent configuration**: Each employee maps to a pre-configured agent with its own system prompt file.
- **(C) Session message injection**: Prepend the system prompt as the first message in the agent session.

**Decision depends on**: What the OpenClaw `before_agent_start` hook API supports. Needs investigation.

### AD-4: Output Preview Security
Website previews via WKWebView need sandboxing decisions:
- Should localhost URLs be loaded directly?
- Should file:// URLs be allowed for local HTML files?
- Network access policy for preview WebViews

### AD-5: Memory Storage Format
**Options:**
- **(A) File-based** (like current task store): Simple, consistent with existing patterns.
- **(B) SQLite**: Better querying, handles large memory sets.
- **(C) In-agent-context**: Store preferences as part of the agent's session history.

**Recommendation**: (A) for v1 consistency. Migrate to (B) if memory sets grow large.

---

## Appendix: Current File Inventory

### Frontend Swift Files (48 total)

**App Shell**
| File | Status | Notes |
|------|--------|-------|
| `WorkforceApp.swift` | Complete | App entry, window setup |
| `MainWindowView.swift` | OK for now | Line 114 correctly routes to `.chatting` — chat is the primary view |
| `SidebarView.swift` | Complete | 4 nav items |
| `ContentPlaceholderView.swift` | Complete | Reusable placeholder |

**Models**
| File | Status | Notes |
|------|--------|-------|
| `Models/Employee.swift` | Needs F2 expansion | Add greeting, systemPrompt fields |
| `Models/WorkforceTask.swift` | Complete | Full lifecycle model |
| `Models/TaskFlowModels.swift` | Needs F3 expansion | Add optional payloads to response |
| `Models/TaskOutput.swift` | Needs F7 expansion | Add more output types |
| `Mock/MockData.swift` | Complete | 3 employees, 3 tasks |

**Services**
| File | Status | Notes |
|------|--------|-------|
| `Services/TaskService.swift` | Needs F3 wiring | Stop auto-starting agent; add clarification/card event handling |
| `Services/EmployeeService.swift` | Complete | Fetch + status listener |
| `Services/WorkforceGatewayService.swift` | Complete | WebSocket wrapper |
| `Services/WorkforceGateway.swift` | Complete | Gateway protocol |

**Task Views**
| File | Status | Notes |
|------|--------|-------|
| `Views/Tasks/TaskInputView.swift` | Needs F1/F2 | Dynamic greeting + templates |
| `Views/Tasks/TaskChatView.swift` | Needs F3/F4/F5/F7 | Primary view — needs inline card rendering for all phases |
| `Views/Tasks/ClarificationView.swift` | Adapt to card | Refactor into `ClarificationCardView` for inline chat use |
| `Views/Tasks/PlanView.swift` | Adapt to card | Refactor into `PlanCardView` for inline chat use |
| `Views/Tasks/TaskProgressView.swift` | Adapt components | Stage indicator + progress bar adapt into `ChatProgressHeaderView` |
| `Views/Tasks/OutputReviewView.swift` | Needs F7/F8 | Add inline previews |
| `Views/Tasks/TaskDashboardView.swift` | Needs F9 | Non-functional buttons |
| `Views/Tasks/TaskRowView.swift` | Complete | |
| `Views/Tasks/ActivityLogView.swift` | Needs F5 | Better descriptions |
| `Views/Tasks/StageIndicatorView.swift` | Complete | |
| `Views/Tasks/TaskControlsView.swift` | Complete | |
| `Views/Tasks/ChatHeaderView.swift` | Complete | |
| `Views/Tasks/AgentThinkingStreamView.swift` | Complete | |

**Employee Views**
| File | Status | Notes |
|------|--------|-------|
| `Views/Employees/EmployeeGalleryView.swift` | Complete | |
| `Views/Employees/EmployeeCardView.swift` | Complete | |
| `Views/Employees/GalleryHeaderView.swift` | Stub filter button | |

**Components**
| File | Status | Notes |
|------|--------|-------|
| `Components/ChatInputPill.swift` | Complete | |
| `Components/ChatBubbleView.swift` | Needs F3 | Extend Role enum for card types, add card routing |
| `Components/ProgressBarView.swift` | Complete | |
| `Components/BlobBackgroundView.swift` | Complete | |
| `Components/GlassEffect.swift` | Complete | |
| `Components/GlowBorder.swift` | Complete | |
| `Components/ShimmerEffect.swift` | Complete | |
| `Components/StatusDotView.swift` | Complete | |
| `Components/StatusBadgeView.swift` | Complete | |
| `Components/TypingIndicatorView.swift` | Complete | |
| `Components/SidebarNavButton.swift` | Complete | |
| `Components/SidebarUserProfile.swift` | Complete | |
| `Components/NewAgentButton.swift` | Stub | Not wired |
| `Components/WindowConfigurator.swift` | Complete | |

### Backend TypeScript Files

| File | Status | Notes |
|------|--------|-------|
| `index.ts` | Needs F2/F3/F4 | Hook injection, structured event emission |
| `src/employees.ts` | Needs F2/F7 | System prompts, personality, contentType field |
| `src/event-bridge.ts` | Needs F5/F7 | Stage detection, milestones, output preview events |
| `src/task-store.ts` | Needs F3/F4/F7 | Store clarification/plan/preview data |

### New Files Needed

| File | Feature | Priority |
|------|---------|----------|
| `FE/Components/Cards/ClarificationCardView.swift` | F3 | P0 |
| `FE/Components/Cards/PlanCardView.swift` | F4 | P0 |
| `FE/Components/Cards/MilestoneCardView.swift` | F5 | P0 |
| `FE/Components/Cards/StageTransitionCardView.swift` | F5 | P0 |
| `FE/Components/ChatProgressHeaderView.swift` | F5 | P0 |
| `FE/Components/Cards/WebPreviewCard.swift` | F7 | P0 |
| `FE/Components/Cards/SlideGalleryCard.swift` | F7 | P0 |
| `FE/Components/Cards/DocumentPreviewCard.swift` | F7 | P0 |
| `FE/Components/Cards/OutputWaitingCard.swift` | F7 | P0 |
| `BE/src/brief-analyzer.ts` | F3 | P0 |
| `BE/src/plan-generator.ts` | F4 | P0 |
| `BE/src/preview-generator.ts` | F7 | P0 |
| `FE/Services/NotificationService.swift` | F6 | P1 |
| `FE/Views/Dashboard/DashboardView.swift` | F9 | P1 |
| `FE/Views/Tasks/TaskErrorView.swift` | F12 | P1 |
| `FE/Views/Onboarding/OnboardingView.swift` | F1 | P1 |
| `FE/Views/Onboarding/FirstTaskGuideView.swift` | F1 | P1 |
| `FE/Views/Outputs/RevisionAnnotationView.swift` | F8 | P1 |
| `FE/Views/Outputs/RevisionDiffView.swift` | F8 | P1 |
| `FE/Components/Cards/ImageGalleryCard.swift` | F7 | Future |
| `FE/Components/Cards/VideoPlayerCard.swift` | F7 | Future |
| `FE/Components/Cards/AudioPlayerCard.swift` | F7 | Future |
| `FE/Components/Cards/ChartPreviewCard.swift` | F7 | Future |
| `FE/Views/Memory/MemoryBankView.swift` | F11 | P2 |
| `FE/Models/MemoryEntry.swift` | F11 | P2 |
| `FE/Services/MemoryService.swift` | F11 | P2 |
| `FE/Views/Tasks/TaskDetailView.swift` | F10 | P2 |
| `BE/src/memory-store.ts` | F11 | P2 |
