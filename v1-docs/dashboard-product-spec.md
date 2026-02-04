# Dashboard — Product Specification

> The dashboard is a manager's morning briefing, not a monitoring panel.

---

## Vision
efs
The Workforce app gives a solo founder or tiny team something they've never had: employees who work around the clock. The dashboard is the first thing users see when they open the app. It should answer the three questions every manager has when they check in on their team:

1. **"What needs me right now?"** — Your employees are blocked waiting on you.
2. **"What's happening right now?"** — Your team is actively working.
3. **"What got done since I last looked?"** — Results are ready for you.

The dashboard is not a metrics panel. It's not an analytics view. It's the command center for a manager who is always the bottleneck in a system of tireless employees.

---

## User Stories

### Story 1: Morning Check-In

> As a user who has been away from the app, I want to immediately see what happened while I was gone and what needs my attention, so I can unblock my employees and review completed work without hunting through individual chats.

**Why this matters**: AI employees work 24/7. Unlike human teams, work continues while the user sleeps. The gap between "when work happened" and "when the user sees it" creates a backlog. The dashboard eliminates that gap.

**Need fulfilled by**: Needs Attention section, Recently Completed section

---

### Story 2: Unblocking My Team

> As a user, when an employee is waiting for my input (a clarification question, a plan to approve, or work to review), I want to see that immediately and act on it with one click, so my employees don't sit idle.

**Why this matters**: The user is always the bottleneck. Every hour they don't respond to a clarification question is an hour that employee is idle. The dashboard should create gentle urgency — "2 employees are waiting on you" — that drives engagement.

**Need fulfilled by**: Needs Attention section (with wait-time indicators and direct navigation)

---

### Story 3: Feeling the Leverage

> As a user, I want to see my employees actively working on tasks in real time, so I feel the leverage of having a team and have confidence that work is progressing.

**Why this matters**: The emotional core of the product. A solo founder who has always done everything themselves now sees three employees working simultaneously. That feeling of leverage — "I'm getting more done than one person ever could" — is what drives retention and willingness to pay. The dashboard must make this feeling tangible.

**Need fulfilled by**: In Progress section (with employee identity, task description, and live stage indicators)

---

### Story 4: Reviewing Deliverables

> As a user, I want to see what my employees have completed since I last checked, so I can review their work, provide feedback, or use the deliverables.

**Why this matters**: Completed work that the user never sees is wasted work. The dashboard needs an "unread inbox" concept: here's what's new since your last visit. This is distinct from the Tasks page (full history) — this is specifically about fresh results.

**Need fulfilled by**: Recently Completed section (with "unseen" tracking and quick access to outputs)

---

### Story 5: Quick Context at a Glance

> As a user who pops in and out of the app throughout the day, I want to get the full picture of my team's status in under 3 seconds, so I can decide whether I need to take action or come back later.

**Why this matters**: The user is busy running their business. They don't have time to click through each employee's chat to piece together what's happening. The dashboard gives them the full picture in one glance.

**Need fulfilled by**: Overall dashboard layout, information hierarchy, and visual density

---

## Feature Breakdown

### Feature 1: Needs Attention Queue

**Fulfills**: Story 1 (Morning Check-In), Story 2 (Unblocking My Team), Story 5 (Quick Context)

**What it is**: A prioritized list of tasks where an AI employee is blocked waiting for the user's input. This is the user's to-do list as a manager.

**Items appear here when a task is in one of these states**:
- **Clarification needed**: Employee asked a question and is waiting for the answer (task stage: `.clarify`)
- **Plan approval needed**: Employee created a plan and is waiting for approval (task stage: `.plan`, status: `.running`)
- **Review requested**: Employee finished work and it's awaiting the user's review (task stage: `.review` or status: `.completed` and user hasn't opened it)

**Each item shows**:
- Employee emoji + name (who needs you)
- What they need (one-line description: "Asking about color preference" / "Plan ready for approval" / "Landing page ready for review")
- How long they've been waiting (relative time: "12 min ago", "2 hours ago", "since yesterday")
- The type of action needed (visual indicator: question mark for clarification, checkmark for approval, eye for review)

**Interaction**: Clicking an item navigates directly to the relevant view (ClarificationView, PlanView, or OutputReviewView/TaskChatView).

**Empty state**: When nothing needs attention, show a calm, positive message. This is a good thing — it means no one is blocked.

**Ordering**: Most recently waiting items first (longest-waiting at top would create guilt; most-recent keeps it feeling fresh and actionable).

---

### Feature 2: In Progress Panel

**Fulfills**: Story 3 (Feeling the Leverage), Story 5 (Quick Context)

**What it is**: A view of all tasks currently being executed by AI employees. This is where the user sees their team working.

**Items appear here when**: Task status is `.running` and stage is `.execute` (actively doing work, not waiting on user).

**Each item shows**:
- Employee emoji + name
- Task description (what they're working on)
- Current stage indicator (using existing `TaskStage` — clarify/plan/execute/review/deliver)
- A sense of activity (not a percentage — AI task progress is unpredictable, so avoid fake progress bars. Instead show the current phase and elapsed time)

**Interaction**: Clicking navigates to the live TaskChatView where the user can watch the employee work (and where the output preview will appear once F7 is implemented).

**Empty state**: When no tasks are running, this section should feel like a quiet office, not a failure state. Invite the user to assign work.

**Why no progress percentage**: AI task execution doesn't have predictable progress. A progress bar that says "45%" is a lie. Instead, show qualitative progress: what stage the task is in, and how long it's been running. The user can infer pace from that.

---

### Feature 3: Recently Completed Feed

**Fulfills**: Story 1 (Morning Check-In), Story 4 (Reviewing Deliverables), Story 5 (Quick Context)

**What it is**: A list of tasks that completed since the user last visited the dashboard. This is the user's "unread inbox" for deliverables.

**Items appear here when**: Task status is `.completed` AND the user hasn't explicitly opened/reviewed the output yet.

**Each item shows**:
- Employee emoji + name
- Task description
- When it completed (relative time)
- Output type indicator (website, document, file, image — using existing `OutputType` styling)
- Output title if available (e.g., "Product Landing Page", "Q1 Market Analysis")

**Interaction**: Clicking navigates to the task's output view. Once the user has viewed a completed task, it moves out of this section (into the permanent task history on the Tasks page).

**"Mark all as seen" action**: A subtle way for the user to clear this section without clicking into each one (for when they're already aware of the results through notifications or earlier sessions).

**Limit**: Show the 10 most recent. If there are more, show a "View all in Tasks" link.

**Empty state**: When everything has been reviewed, show a brief positive message.

---

## Information Architecture

```
┌─────────────────────────────────────────────────────┐
│  DASHBOARD                                          │
│                                                     │
│  ┌─ Needs Attention ──────────────────────────────┐ │
│  │                                                │ │
│  │  The most important section. Top of the page.  │ │
│  │  Items where employees are blocked on user.    │ │
│  │                                                │ │
│  │  [item] [item] [item]                          │ │
│  │                                                │ │
│  └────────────────────────────────────────────────┘ │
│                                                     │
│  ┌─ In Progress ──────┐  ┌─ Recently Completed ──┐ │
│  │                    │  │                        │ │
│  │  Tasks actively    │  │  Finished work the     │ │
│  │  being worked on.  │  │  user hasn't seen yet. │ │
│  │                    │  │                        │ │
│  │  [item]            │  │  [item]                │ │
│  │  [item]            │  │  [item]                │ │
│  │  [item]            │  │  [item]                │ │
│  │                    │  │                        │ │
│  └────────────────────┘  └────────────────────────┘ │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Layout Logic

**Needs Attention**: Full-width across the top. This is the priority section. It demands the most visual prominence. If this section has items, the user's eye should go here first.

**In Progress + Recently Completed**: Side by side below Needs Attention. These are secondary — the user glances at them after handling their to-do items. Two-column layout gives a balanced view of "happening now" (left) and "just finished" (right).

**When sections are empty**: Sections with no items should collapse gracefully (not show a big empty box). If all three are empty (fresh install or all tasks handled), show a single welcoming state that invites the user to assign their first task.

### Responsive Behavior

- **Wide window (>1000px content area)**: Two-column layout for In Progress + Recently Completed
- **Narrow window (<1000px content area)**: Stack all three sections vertically (Needs Attention, then In Progress, then Recently Completed)

---

## UI/UX Requirements

### Overall Dashboard Style

**Background**: Use the existing `BlobBackgroundView` for visual consistency with other views (TaskDashboardView, TaskChatView). The animated gradient blobs provide warmth and life.

**Scrolling**: The entire dashboard is a single ScrollView. All three sections scroll together. No independently scrolling subsections (avoids nested scroll confusion).

**Spacing**: Generous vertical spacing between sections (32pt). Each section has a clear header. The dashboard should feel spacious, not cramped.

**Typography**: Section headers use the same style as existing views — size 20-24, semibold, `white.opacity(0.9)`. Subtext at size 12-13, `white.opacity(0.5)`.

---

### Needs Attention Section

#### Section Header
- Title: "Needs Your Attention" (or "Needs Attention")
- Item count badge: a small pill showing the number (e.g., "3") in a warm color (amber/orange) to create gentle urgency
- If empty, the section header still shows but with a calm "All clear" indicator

#### Attention Item Card

**Layout**: Horizontal card, full-width. Glass-morphism surface (existing `.glassCard()` modifier).

```
┌──────────────────────────────────────────────────┐
│  🌐  Emma is asking a question        12 min ago │
│      "Should the hero use a photo or             │
│       illustration?"                              │
│                                   [  Respond  ]  │
└──────────────────────────────────────────────────┘
```

**Components**:
- **Left**: Employee emoji (from `Employee.emoji`) — large, ~32pt, serves as avatar
- **Middle**:
  - **Top line**: Employee name + action type label. Bold employee name (size 14), followed by action description in regular weight (size 13). Examples:
    - "Emma is asking a question"
    - "David's plan is ready"
    - "Sarah's work is ready for review"
  - **Bottom line**: Context snippet — the actual question text, or "Marketing Strategy — 3 steps, estimated 15 min" for plans, or "Product Landing Page" for completed output. Size 12, `white.opacity(0.6)`, max 2 lines, truncated.
- **Right**:
  - Relative timestamp (size 11, `white.opacity(0.4)`)
  - Action button — a compact button in the appropriate color:
    - Clarification: "Respond" (blue)
    - Plan approval: "Review Plan" (blue)
    - Output review: "View Output" (green)

**Visual states**:
- Default: standard glass card
- Hover: slightly elevated shadow, increased background opacity (existing `.glassCard(isHovered: true)` pattern)
- The entire card is clickable (navigates to the relevant view), the button is a visual affordance

**Action type indicators**: A small icon before or integrated into the action label:
- Clarification: `questionmark.circle` icon
- Plan approval: `checkmark.circle` icon
- Output review: `eye` icon

These should use existing `TaskStage` icons where applicable.

#### Empty State (Needs Attention)

When no items need attention:

```
┌──────────────────────────────────────────────────┐
│         ✓  All clear — no one needs you          │
│                                                  │
│     Your team is either working or waiting for   │
│     new assignments.                             │
└──────────────────────────────────────────────────┘
```

- Subtle, not celebratory. A simple checkmark with calm text.
- Reduced visual weight compared to when items are present — this section should recede when empty.
- Use a softer glass surface (lower opacity background, thinner border).

---

### In Progress Section

#### Section Header
- Title: "In Progress"
- Active count: small indicator showing number of running tasks
- Subtle animated dot or pulse to indicate live activity (optional, designer's discretion)

#### Progress Item Card

```
┌────────────────────────────────────┐
│  📊  David                         │
│      Analyzing competitor pricing  │
│                                    │
│  ○ Clarify  ● Execute  ○ Review   │
│                         18 min     │
└────────────────────────────────────┘
```

**Components**:
- **Employee emoji + name**: Size 14 bold for name
- **Task description**: Size 13, `white.opacity(0.7)`, max 2 lines
- **Stage indicator**: A horizontal row of the task stages (Clarify → Plan → Execute → Review → Deliver) with the current stage highlighted. Use small dots or step indicators — the current stage is filled/colored, past stages are checkmarked, future stages are hollow. Reference existing `StageIndicatorView` for styling cues.
- **Elapsed time**: "18 min" — how long the task has been running. Size 11, `white.opacity(0.4)`.

**Layout**: Cards in a vertical stack within the column. Each card uses `.glassCard()`.

**Interaction**: Click to navigate to the task's live chat view.

**Visual activity**: Consider a subtle shimmer or breathing animation on the card to indicate live work (similar to existing `.shimmer()` modifier on employee cards). Designer should decide if this adds or distracts.

#### Empty State (In Progress)

```
┌────────────────────────────────────┐
│       No active tasks              │
│                                    │
│  Assign work to get your team      │
│  started.                          │
└────────────────────────────────────┘
```

- Text-only, minimal. Include a subtle link or mention that the user can go to Employees to assign work. Do not add a prominent CTA button here — the empty state should be informational, not pushy.

---

### Recently Completed Section

#### Section Header
- Title: "Recently Completed"
- Count of unseen items
- "Mark all as seen" text button (only visible when items exist). Subtle, right-aligned. Size 12, `white.opacity(0.5)` with blue on hover.

#### Completed Item Card

```
┌────────────────────────────────────┐
│  🌐  Emma                         │
│      Product Landing Page          │
│                                    │
│  🌐 Website          2 hours ago  │
└────────────────────────────────────┘
```

**Components**:
- **Employee emoji + name**: Size 14 bold
- **Output title**: Size 13, `white.opacity(0.8)`. If no specific title, fall back to task description.
- **Output type badge**: Small colored pill matching existing `OutputPillView` styling from `TaskRowView`:
  - Website: teal
  - Document: purple
  - File: blue
  - Image: pink
- **Completion time**: Relative timestamp. Size 11, `white.opacity(0.4)`.

**Unseen indicator**: A small dot (blue or accent color) on the card or beside the title to indicate the user hasn't viewed this output yet. When the user clicks in and comes back, the dot disappears.

**Interaction**: Click to navigate to the output review view for that task.

**Multiple outputs per task**: If a task produced multiple outputs (e.g., a document + a chart), show one card per task (not per output), with multiple output type badges. The card title should be the task description, and badges indicate what was produced.

#### Empty State (Recently Completed)

```
┌────────────────────────────────────┐
│       You're all caught up         │
└────────────────────────────────────┘
```

- Single line, minimal. The user has seen everything.

---

### Full Empty State (No Data At All)

When the user has no tasks at all (fresh install, first use):

```
┌──────────────────────────────────────────────────┐
│                                                  │
│         Welcome to your team's dashboard         │
│                                                  │
│   Once you assign tasks to your employees,       │
│   you'll see their progress and results here.    │
│                                                  │
│   Head to Employees to get started.              │
│                                                  │
└──────────────────────────────────────────────────┘
```

- Centered on the page. Warm, welcoming tone. Not a tutorial — just a brief pointer.
- "Employees" can be a clickable link/button that navigates to the Employees sidebar item.
- Use a relaxed visual — maybe a single subtle icon. No illustration needed for v1.

---

## States & Transitions

### Dashboard Data Refresh

- **On appear**: Fetch fresh data when dashboard becomes visible (user clicks Dashboard in sidebar)
- **Real-time updates**: Subscribe to existing task events via `TaskService`. When a task's status or stage changes, the dashboard sections update automatically (items move between sections or appear/disappear).
- **No manual refresh button**: Data should always feel current. The existing WebSocket event system handles this.

### Item Lifecycle Across Sections

A task can move between dashboard sections as its state changes:

```
[No dashboard presence]
        │
        ▼  (task submitted, enters .execute stage)
   ┌─────────────┐
   │ In Progress  │
   └─────┬───────┘
         │  (employee has a question → enters .clarify stage)
         ▼
   ┌─────────────────┐
   │ Needs Attention  │  (clarification type)
   └─────┬───────────┘
         │  (user answers → back to .execute stage)
         ▼
   ┌─────────────┐
   │ In Progress  │
   └─────┬───────┘
         │  (plan generated → enters .plan stage)
         ▼
   ┌─────────────────┐
   │ Needs Attention  │  (plan approval type)
   └─────┬───────────┘
         │  (user approves → back to .execute stage)
         ▼
   ┌─────────────┐
   │ In Progress  │
   └─────┬───────┘
         │  (task completes → status .completed)
         ▼
   ┌─────────────────────┐
   │ Recently Completed   │  (unseen)
   └─────┬───────────────┘
         │  (user views output)
         ▼
   [Exits dashboard → lives in Tasks history]
```

### Section Visibility Rules

| Task Status | Task Stage | Dashboard Section |
|---|---|---|
| `.running` | `.clarify` | Needs Attention (clarification type) |
| `.running` | `.plan` | Needs Attention (plan approval type) |
| `.running` | `.execute` | In Progress |
| `.running` | `.review` | Needs Attention (review type) |
| `.running` | `.deliver` | Needs Attention (review type) |
| `.completed` | any | Recently Completed (if unseen) |
| `.completed` | any | Not shown (if already seen) |
| `.failed` | any | Needs Attention (error type — optional v1.1) |
| `.pending` | any | In Progress (queued, waiting to start) |
| `.cancelled` | any | Not shown |

---

### "Seen" Tracking

**Mechanism**: Track which completed task IDs the user has opened. Store locally (UserDefaults or a simple on-disk set). When the user navigates to a completed task's output view from any entry point (dashboard, tasks page, notification), mark that task ID as "seen."

**Reset**: The "seen" set can be cleared periodically (e.g., keep only the last 30 days) to prevent unbounded growth.

**"Mark all as seen"**: Adds all currently visible completed task IDs to the seen set. Items animate out of the Recently Completed section.

---

## Sidebar Badge

The Dashboard sidebar item should display a badge count when items need attention.

**Badge value**: Count of items in the Needs Attention section only (not In Progress, not Recently Completed). This matches the mental model of "things I need to act on."

**Visual**: A small numbered badge (red or accent-colored circle) on the Dashboard icon in the sidebar, similar to notification badges in other apps. Use a compact size (fits 1-2 digits).

**When zero**: No badge shown. The absence of a badge means "nothing urgent."

---

## Interaction Patterns

### Navigation from Dashboard

Every clickable item on the dashboard navigates to the appropriate existing view:

| Dashboard Item | Navigates To | How |
|---|---|---|
| Clarification item | `ClarificationView` for that task | Set `flowState = .clarifying(task, questions)` |
| Plan approval item | `PlanView` for that task | Set `flowState = .planning(task, plan)` |
| Output review item | `TaskChatView` or `OutputReviewView` for that task | Set `flowState = .chatting(employee, taskId)` or `.reviewing(taskId)` |
| In Progress item | `TaskChatView` for that task (live) | Set `flowState = .chatting(employee, taskId)` |
| Recently Completed item | Output view for that task | Set `flowState = .reviewing(taskId)` |

All navigation uses the existing `TaskFlowState` enum in `MainWindowView.swift`. No new navigation patterns needed.

### Back to Dashboard

After the user handles an item (answers a question, approves a plan, reviews output), they should be able to return to the dashboard easily. The sidebar "Dashboard" item is always visible and serves as the return path.

---

## Out of Scope for v1

These features were considered and intentionally deferred:

| Feature | Why Deferred |
|---|---|
| **Statistics / analytics** | A solo founder with 3-5 employees and a few tasks per day doesn't need utilization charts. They assigned every task themselves — they know the stats. This becomes valuable at scale (weeks of usage, many tasks). Build when users ask for it. |
| **Employee status grid** | With 3-5 employees, a grid of idle/busy cards is information-sparse. The In Progress section already tells you who's working. A dedicated grid matters when you have 10+ employees. |
| **Activity feed / event log** | A reverse-chronological stream of events ("Emma started task at 2:14pm") is noisy and not actionable. What matters is outcomes (needs attention, completed), not play-by-play. |
| **Quick task dispatch from dashboard** | Users can already assign tasks via the Employees page. Adding a dispatch widget to the dashboard adds complexity without clear value — the dashboard is for *reviewing*, not *creating*. |
| **Task failure handling** | Failed tasks could appear in Needs Attention ("Emma's task failed — retry?"). This is a good idea but adds complexity to the attention queue. Defer to v1.1. |
| **Customizable dashboard layout** | Let users rearrange or hide sections. Not needed until we validate the default layout works. |

---

## Technical Context (For Engineers)

### Where the Dashboard Fits

**Sidebar routing**: `SidebarView.swift` already has `.dashboard` as a `SidebarItem`. `MainWindowView.swift` line 212-217 currently shows a `ContentPlaceholderView`. Replace that with the new `DashboardView`.

**Data sources**: All data needed for the dashboard already flows through existing services:
- `TaskService.tasks` — array of all `WorkforceTask` objects
- `TaskService.activeTasks` — computed property filtering for `.running` status
- `TaskService.completedTasks` — computed property filtering for `.completed` status
- `EmployeeService.employees` — array of all `Employee` objects
- `EmployeeService.employee(byId:)` — lookup employee for display

**Real-time updates**: `TaskService` already subscribes to task events via WebSocket. When task status/stage changes, the `tasks` array updates, and SwiftUI re-renders views that depend on it. No new event subscriptions needed — the dashboard reads from the same observable state.

### Existing Models Referenced

**`WorkforceTask`** (`Models/WorkforceTask.swift`):
- `.status`: `TaskStatus` — .pending, .running, .completed, .failed, .cancelled
- `.stage`: `TaskStage` — .clarify, .plan, .execute, .review, .deliver
- `.employeeId`: links to `Employee`
- `.description`: task description text
- `.outputs`: array of `TaskOutput`
- `.createdAt`, `.completedAt`: timestamps

**`Employee`** (`Models/Employee.swift`):
- `.emoji`: character used as avatar
- `.name`: display name
- `.status`: `EmployeeStatus` — .online, .idle, .busy, .offline

**`TaskOutput`** (`Models/TaskOutput.swift`):
- `.type`: `OutputType` — .file, .website, .document, .image
- `.title`: output title
- `.filePath`, `.url`: location of output

### Existing Visual Components to Reuse

- `GlassCard` modifier — `Components/GlassEffect.swift`
- `BlobBackgroundView` — `Components/BlobBackgroundView.swift`
- `StageIndicatorView` — `Views/Tasks/StageIndicatorView.swift`
- `StatusBadgeView` — `Components/StatusBadgeView.swift`
- `OutputPillView` styling — `Views/Tasks/TaskRowView.swift`

### New Files to Create

| File | Purpose |
|---|---|
| `Views/Dashboard/DashboardView.swift` | Main dashboard container (scroll view with three sections) |
| `Views/Dashboard/NeedsAttentionSection.swift` | Needs Attention section with item cards |
| `Views/Dashboard/InProgressSection.swift` | In Progress section with task cards |
| `Views/Dashboard/RecentlyCompletedSection.swift` | Recently Completed section with output cards |
| `Views/Dashboard/DashboardItemCard.swift` | Shared card component used across sections (or per-section cards if styling diverges significantly) |

### Files to Modify

| File | Change |
|---|---|
| `MainWindowView.swift` | Replace `.dashboard` placeholder with `DashboardView` (line 212-217) |
| `SidebarView.swift` | Add badge count to Dashboard nav button (read from task service) |

### No Backend Changes Required

The dashboard reads entirely from data already available on the client:
- Task list with status and stage (already fetched by `TaskService`)
- Employee details (already fetched by `EmployeeService`)
- Real-time updates (already flowing via WebSocket events)

The only new client-side state is the "seen" tracking set for completed tasks (stored locally).

---

## Success Criteria

- [ ] User opens app and sees their team's status in under 3 seconds (no loading spinner on repeat visits)
- [ ] Items in "Needs Attention" accurately reflect tasks blocked on user input
- [ ] Clicking any dashboard item navigates to the correct view for that task
- [ ] When a task's state changes (via WebSocket event), the dashboard updates in real time without manual refresh
- [ ] "Recently Completed" only shows tasks the user hasn't reviewed yet
- [ ] "Mark all as seen" clears the Recently Completed section
- [ ] Sidebar badge shows the count of items needing attention
- [ ] Empty states are graceful and informative for each section
- [ ] Full empty state (no tasks ever) guides the user toward their first task assignment
- [ ] Dashboard visual style matches existing app aesthetic (glass-morphism, blob background, consistent typography)
