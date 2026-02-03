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

**The entire structured workflow exists in code but is never activated.** After a user submits a task brief, `MainWindowView.swift:114` transitions directly to `.chatting` — a freeform chat interface — bypassing clarification, plan approval, and structured output review. The backend never generates clarification questions or execution plans. Every employee behaves identically because no personality or system prompt differentiation exists.

The app works as a chat wrapper. It needs to work as a workforce manager.

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

#### Current State
- `ClarificationView.swift` is **fully implemented** (217 lines) — supports single-select, multi-select, text input, and file questions with proper validation and submission
- `TaskFlowState.clarifying(task:questions:)` exists in `TaskFlowModels.swift:110`
- `MainWindowView.swift:129-147` handles the `.clarifying` state correctly — routes to `ClarificationView` and handles `onComplete` transition
- `TaskService.submitClarification()` at `TaskService.swift:94-104` sends answers to `workforce.tasks.clarify` backend method
- Backend `workforce.tasks.clarify` at `index.ts:109-134` accepts answers, appends them to the brief, and advances stage to `plan`
- **BUT**: Nothing ever triggers the `.clarifying` state. `MainWindowView.swift:114` goes from `.input` directly to `.chatting`. The backend `workforce.tasks.create` returns immediately without generating questions.

#### Gap Analysis
- Backend has no brief analysis logic — it doesn't examine the user's task description to determine whether clarification is needed
- No question generation — the backend never creates `ClarificationPayload` data
- No event or response field tells the frontend "this task needs clarification before proceeding"
- The `TaskService.submitTask()` method at `TaskService.swift:43-92` calls `startAgent()` immediately after task creation — there's no pause for clarification
- No employee-specific question templates (Emma should ask about design; David should ask about data format)

#### Frontend Work
1. `[FE][WIRE]` `MainWindowView.swift:108-118` — Change the `.input` case so `onTaskSubmitted` checks the response for a clarification payload:
   ```swift
   // Instead of:
   self.flowState = .chatting(employee: employee, taskId: task.id)
   // Do:
   if let questions = response.clarificationPayload {
       self.flowState = .clarifying(task: task, questions: questions)
   } else if let plan = response.planPayload {
       self.flowState = .planning(task: task, plan: plan)
   } else {
       self.flowState = .executing(taskId: task.id)
   }
   ```
2. `[FE][MOD]` `Models/TaskFlowModels.swift` — Extend `TaskCreateResponse` to include optional `clarificationPayload: ClarificationPayload?` and `planPayload: PlanPayload?`
3. `[FE][MOD]` `TaskService.swift:43-92` — Do NOT call `startAgent()` in `submitTask()` if the response includes clarification questions. Only start the agent after clarification is complete (or if no clarification is needed).
4. `[FE][MOD]` `ClarificationView.swift:136-147` (`onComplete`) — After submitting clarification, check if a plan payload comes back; transition to `.planning` if so, or `.executing` if the backend auto-proceeds

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
   - Include `clarificationPayload` in the response
   - Do NOT broadcast "start agent" — wait for clarification answers
   If no questions needed:
   - Set task stage to `"plan"` or `"execute"`
   - Include `planPayload` or proceed to execution
3. `[BE][MOD]` `index.ts:109-134` (`workforce.tasks.clarify`) — After receiving answers, either generate a plan (transition to plan stage) or proceed to execution. Broadcast `workforce.task.stage` event so frontend transitions correctly.
4. `[BE][MOD]` `task-store.ts` — Add `clarificationPayload?: object` and `planPayload?: object` fields to `TaskManifest` so they persist across requests

#### Acceptance Criteria
- [ ] After submitting a brief, the app shows ClarificationView (not chat) when the employee needs more info
- [ ] Clarification questions are employee-specific (web-related for Emma, data-related for David)
- [ ] Vague briefs always trigger clarification; detailed briefs may skip it
- [ ] User can answer questions with radio buttons, checkboxes, or text fields
- [ ] After answering, the flow proceeds to plan or execution (never back to chat)
- [ ] If user cancels clarification, the task is cancelled cleanly

---

## Phase: Approving the Plan

### F4: Plan Generation & Approval — P0

#### Customer Need
> "Before my employee starts working, I want to see what they plan to do. I want a clear summary, numbered steps, and an estimated time. I should be able to approve, request changes, or cancel."

#### Current State
- `PlanView.swift` is **fully implemented** (194 lines) — shows summary, numbered steps with estimated times, approve/reject buttons, feedback text input
- `TaskFlowState.planning(task:plan:)` exists in `TaskFlowModels.swift:111`
- `MainWindowView.swift:149-162` handles `.planning` state — routes to `PlanView` with approve/cancel callbacks
- `TaskService.approvePlan()` at `TaskService.swift:106-119` sends approval to backend and starts the agent
- `TaskService.rejectPlan()` at `TaskService.swift:121-131` sends feedback to backend
- Backend `workforce.tasks.approve` at `index.ts:137-161` handles approval/rejection, updates stage
- **BUT**: No code ever generates a plan. The backend creates a task and goes straight to execution. Nothing produces `PlanPayload` data. The `.planning` state is never entered.

#### Gap Analysis
- No plan generation logic exists anywhere in the backend
- No transition from clarification → planning (or from task creation → planning for simple briefs)
- `PlanPayload` struct exists in Swift but no backend code ever produces the matching JSON
- The backend `workforce.tasks.clarify` method advances stage to `"plan"` but never generates plan content

#### Frontend Work
1. `[FE][WIRE]` Already handled in F3 above — the `onTaskSubmitted` and `onComplete` (from ClarificationView) handlers need to check for plan payloads and transition to `.planning`
2. `[FE][MOD]` `TaskService.swift:106-119` (`approvePlan`) — This already works correctly (sends approval, starts agent). No changes needed if the backend generates plans properly.
3. `[FE][MOD]` Handle the case where plan rejection returns a new plan — `PlanView.swift:180-193` calls `self.onApproved(updated)` after rejection, which should actually route back to `.planning` with the new plan, not forward to execution

#### Backend Work
1. `[BE][NEW]` Create `BE/src/plan-generator.ts` — Generates an execution plan from the enriched brief:
   ```typescript
   export function generatePlan(brief: string, employee: EmployeeConfig, clarifications?: object): PlanPayload
   ```
   Two approaches:
   - **Template-based (fast)**: Employee-specific plan templates filled with brief details (Emma's plan: research → wireframe → code → deploy; David's plan: data import → analysis → visualization → formatting)
   - **AI-based (dynamic)**: Short LLM call to generate a structured plan from the enriched brief
2. `[BE][MOD]` `index.ts:109-134` (`workforce.tasks.clarify`) — After receiving clarification answers, call `generatePlan()` and include the result in the response. Update task stage to `"plan"`.
3. `[BE][MOD]` `index.ts:76-106` (`workforce.tasks.create`) — For simple briefs that skip clarification, generate a plan immediately and include it in the response.
4. `[BE][MOD]` `index.ts:137-161` (`workforce.tasks.approve`) — On rejection with feedback, regenerate the plan with feedback incorporated and return the new plan in the response. Keep stage as `"plan"`.
5. `[BE][MOD]` `task-store.ts:22-37` — Store the plan in `TaskManifest.planPayload` so it survives across requests

#### Acceptance Criteria
- [ ] After clarification (or immediately for clear briefs), the app shows PlanView with a structured plan
- [ ] Plan includes summary, numbered steps, and estimated time
- [ ] User can approve the plan — execution begins immediately
- [ ] User can reject the plan with feedback — a revised plan is generated
- [ ] User can cancel — task is cancelled cleanly
- [ ] Plan content reflects the employee's specialty (Emma plans web work, David plans data work)

---

## Phase: Watching Them Work

### F5: Rich Execution Progress — P0

#### Customer Need
> "When my employee is working, I want to see meaningful progress — not a scrolling chat log. I want to see which stage they're in (researching, building, testing), a progress bar, and key milestones. It should feel like watching a professional at work."

#### Current State
- `TaskProgressView.swift` is **fully implemented** (123 lines) — shows employee avatar, status label, `StageIndicatorView`, percentage progress bar, and `ActivityLogView`
- `StageIndicatorView.swift` renders a visual 5-stage pipeline (clarify → plan → execute → review → deliver)
- `ActivityLogView.swift` displays task activities with icons and timestamps
- `ProgressBarView.swift` renders an animated progress bar
- The `.executing` state in `MainWindowView.swift:164-183` correctly routes to `TaskProgressView`
- **BUT**: The current flow goes to `.chatting` (TaskChatView) instead of `.executing` (TaskProgressView). The chat view shows raw streaming text as conversation bubbles — useful for debugging but not the product experience.
- Event bridge (`event-bridge.ts:64-68`) does stage detection but uses crude text heuristics (checking for words like "plan", "implement", "review" in agent output)
- Progress computation (`event-bridge.ts:201-206`) uses a logarithmic formula based on activity count — not meaningful task progress

#### Gap Analysis
- TaskProgressView is never shown as the default during execution — TaskChatView is shown instead
- Stage detection is unreliable (based on word matching in agent text output)
- Progress is artificial (based on number of events, not actual completion)
- No milestone tracking (e.g., "file created", "test passed", "deploy complete")
- Activities shown are raw tool calls ("Using write_file") rather than human-friendly descriptions ("Creating your homepage")

#### Frontend Work
1. `[FE][WIRE]` `MainWindowView.swift:108-118` — Change the flow so that after task creation (and optional clarification/plan), the state goes to `.executing(taskId:)` instead of `.chatting`. TaskProgressView becomes the primary execution view.
2. `[FE][MOD]` `TaskProgressView.swift` — Consider adding a "Show chat log" toggle/disclosure that reveals the raw chat for power users, while keeping the structured progress view as default
3. `[FE][MOD]` `ActivityLogView.swift` — Improve activity descriptions to be user-friendly:
   - "Using write_file" → "Creating homepage.html"
   - "Using bash" → "Running build process"
   - Raw thinking text → Summarized status updates

#### Backend Work
1. `[BE][MOD]` `event-bridge.ts:116-138` (`buildToolActivity`) — Generate human-friendly activity messages:
   ```typescript
   // Instead of: "Using write_file"
   // Generate: "Creating homepage.html" (using the file path from the tool call)
   ```
2. `[BE][MOD]` `event-bridge.ts:182-198` (`detectStageFromText`) — Replace text heuristic stage detection with tool-based detection:
   - Research tools used → "research" stage
   - Write/create tools used → "execute" stage
   - Test/validate tools used → "review" stage
   - Final output produced → "deliver" stage
3. `[BE][MOD]` `event-bridge.ts:200-206` (`computeProgress`) — Replace logarithmic formula with plan-aware progress:
   - If a plan exists with N steps, track which step the agent is on
   - Use tool call patterns to estimate step completion
   - Fall back to current formula only if no plan exists
4. `[BE][NEW]` Add milestone detection in `event-bridge.ts` — Emit `workforce.task.milestone` events for significant moments (file created, test passed, build complete, deploy done)

#### Acceptance Criteria
- [ ] After plan approval, user sees TaskProgressView (not chat) as the default execution view
- [ ] Stage indicator accurately reflects what the agent is doing (not just word matching)
- [ ] Progress bar moves meaningfully (tied to plan steps, not just event count)
- [ ] Activity log shows human-readable descriptions, not raw tool names
- [ ] User can optionally view the raw chat log if they want to see details
- [ ] Milestones are highlighted visually (e.g., "File created: homepage.html")

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
> "When my employee finishes a website, I want to see a live preview right in the app — not just a file name. If it's a document, show me the rendered content. If it's an image, show the image. Each type of output should have an appropriate preview."

#### Current State
- `OutputReviewView.swift` is **fully implemented** (216 lines) — shows output list with type icons, "Open" and "Show in Finder" buttons, revision request form, activity log, and approval/rejection controls
- `TaskOutput.swift` has `OutputType` enum with `file`, `website`, `document`, `image`, `unknown` and icon mappings
- `event-bridge.ts:140-171` (`detectOutput`) classifies outputs by file extension and detects localhost URLs
- Backend `workforce.outputs.open` at `index.ts:248-272` runs `open` command; `workforce.outputs.reveal` at `index.ts:275-296` runs `open -R`
- **BUT**: The output review only shows a list of file names with type icons. There are no inline previews. "Open" launches the file in an external app. No WebView for websites, no image preview, no document rendering.

#### Gap Analysis
- No inline preview for any output type
- No WebView for website outputs (even though localhost URLs are detected)
- No image preview (just a file icon and "Open" button)
- No document preview (markdown rendering, PDF display)
- No side-by-side comparison view (brief vs. output)
- `OutputType` classification is basic — doesn't distinguish between HTML, React, presentation, etc.

#### Frontend Work
1. `[FE][NEW]` Create `Views/Outputs/WebPreviewView.swift` — `WKWebView` wrapper that loads website outputs (localhost URLs) inline
2. `[FE][NEW]` Create `Views/Outputs/ImagePreviewView.swift` — Native image display for PNG/JPG/SVG outputs with zoom
3. `[FE][NEW]` Create `Views/Outputs/DocumentPreviewView.swift` — Markdown/text rendering for document outputs using `AttributedString` or similar
4. `[FE][MOD]` `OutputReviewView.swift:101-146` (`outputRow`) — Replace the simple row layout with content-type specific preview cards:
   ```swift
   switch output.type {
   case .website: WebPreviewView(url: output.url)
   case .image: ImagePreviewView(path: output.filePath)
   case .document: DocumentPreviewView(path: output.filePath)
   default: // current file row
   }
   ```
5. `[FE][MOD]` `Models/TaskOutput.swift` — Extend `OutputType` to include `presentation`, `spreadsheet`, `code` for richer classification
6. `[FE][MOD]` `OutputReviewView.swift` — Add a "Full Preview" mode that expands the preview to fill the entire content area

#### Backend Work
1. `[BE][MOD]` `event-bridge.ts:140-171` (`detectOutput`) — Improve output detection:
   - Detect when a dev server is started (not just localhost URLs in text)
   - Extract file content metadata (dimensions for images, word count for documents)
   - Classify more precisely (`.pptx` → presentation, `.csv/.xlsx` → spreadsheet)
2. `[BE][MOD]` `event-bridge.ts:173-178` (`classifyOutputType`) — Expand classification:
   ```typescript
   if (["pptx", "ppt", "key"].includes(ext)) return "presentation";
   if (["csv", "xlsx", "xls"].includes(ext)) return "spreadsheet";
   if (["js", "ts", "py", "swift"].includes(ext)) return "code";
   ```
3. `[BE][MOD]` `task-store.ts:13-20` (`TaskOutput` type) — Add `metadata?: { width?: number, height?: number, wordCount?: number, previewUrl?: string }` field
4. `[BE][NEW]` Add output thumbnail/preview generation — For file outputs, generate a small preview (first 50 lines of code, image thumbnail, etc.) and include in the output event

#### Acceptance Criteria
- [ ] Website outputs show a live WKWebView preview within the app
- [ ] Image outputs display inline with zoom capability
- [ ] Document outputs render as formatted text (markdown rendered, plain text displayed)
- [ ] Each output type has a distinct visual treatment
- [ ] "Open in external app" still available as a secondary action
- [ ] Preview loads without requiring the user to click anything

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

**Sprint 1: Connect the Flow (P0 core)**
1. **F2 — Employee Identity** — Add system prompts and personality to employees. This is the foundation that makes everything else meaningful.
2. **F3 — Smart Clarification** — Build brief analyzer, connect `MainWindowView` flow routing, stop going to `.chatting` state. The biggest single-point change.
3. **F4 — Plan Generation** — Build plan generator, connect clarification → planning → execution transitions.

**Sprint 2: Execution & Output (P0 completeness)**
4. **F5 — Rich Execution Progress** — Route to TaskProgressView as default, improve stage detection and activity descriptions.
5. **F7 — Output Preview** — Build content-type specific preview views (WebView, image, document).

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
| `MainWindowView.swift` | Needs F3 wiring | Line 114 is the critical bypass |
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
| `Services/TaskService.swift` | Needs F3/F5 wiring | Stop auto-starting agent |
| `Services/EmployeeService.swift` | Complete | Fetch + status listener |
| `Services/WorkforceGatewayService.swift` | Complete | WebSocket wrapper |
| `Services/WorkforceGateway.swift` | Complete | Gateway protocol |

**Task Views**
| File | Status | Notes |
|------|--------|-------|
| `Views/Tasks/TaskInputView.swift` | Needs F1/F2 | Dynamic greeting + templates |
| `Views/Tasks/TaskChatView.swift` | Complete | Will become secondary view |
| `Views/Tasks/ClarificationView.swift` | Complete | Ready to use once wired |
| `Views/Tasks/PlanView.swift` | Complete | Ready to use once wired |
| `Views/Tasks/TaskProgressView.swift` | Complete | Will become primary execution view |
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
| `Components/ChatBubbleView.swift` | Complete | |
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
| `index.ts` | Needs F2/F3/F4 | Hook injection, response payloads |
| `src/employees.ts` | Needs F2 | System prompts, personality |
| `src/event-bridge.ts` | Needs F5 | Stage detection, progress |
| `src/task-store.ts` | Needs F3/F4 | Store clarification/plan data |

### New Files Needed

| File | Feature | Priority |
|------|---------|----------|
| `BE/src/brief-analyzer.ts` | F3 | P0 |
| `BE/src/plan-generator.ts` | F4 | P0 |
| `FE/Views/Outputs/WebPreviewView.swift` | F7 | P0 |
| `FE/Views/Outputs/ImagePreviewView.swift` | F7 | P0 |
| `FE/Views/Outputs/DocumentPreviewView.swift` | F7 | P0 |
| `FE/Services/NotificationService.swift` | F6 | P1 |
| `FE/Views/Dashboard/DashboardView.swift` | F9 | P1 |
| `FE/Views/Tasks/TaskErrorView.swift` | F12 | P1 |
| `FE/Views/Onboarding/OnboardingView.swift` | F1 | P1 |
| `FE/Views/Onboarding/FirstTaskGuideView.swift` | F1 | P1 |
| `FE/Views/Outputs/RevisionAnnotationView.swift` | F8 | P1 |
| `FE/Views/Outputs/RevisionDiffView.swift` | F8 | P1 |
| `FE/Views/Memory/MemoryBankView.swift` | F11 | P2 |
| `FE/Models/MemoryEntry.swift` | F11 | P2 |
| `FE/Services/MemoryService.swift` | F11 | P2 |
| `FE/Views/Tasks/TaskDetailView.swift` | F10 | P2 |
| `BE/src/memory-store.ts` | F11 | P2 |
