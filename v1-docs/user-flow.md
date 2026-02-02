 Frontend Feature Map: UX Vision → App Features

  I've mapped every experience promise in user-experience.md to concrete frontend features. The UX doc
  describes four emotional phases the user goes through. Each phase requires specific features to deliver
   the promised feeling. Here's the complete breakdown.

  ---
  Feature 1: Employee Personality Greeting & Introduction

  UX promise it serves: Phase 1 — "Feels like hiring a capable contractor, NOT chatting with a bot". The
  doc explicitly shows: "Hi! I'm Emma, your web developer. What would you like me to build today?"

  User Story: As a user clicking on an employee card, I want to see a personalized greeting from that
  employee in their voice and personality, so that I feel like I'm working with a specialist — not typing
   into a text box.

  Frontend Interaction Flow:
  1. User clicks Emma's card in the gallery
  2. Task input panel slides in with Emma's header (emoji + name + title)
  3. Below the header: a greeting bubble in Emma's voice, dynamically phrased for the employee's
  specialty
  4. Greeting references context if available: "Welcome back! Last time I built you a landing page for
  Acme Corp."
  5. Below the greeting: the task input field with a placeholder specific to the employee ("Describe the
  website you'd like...")

  Exact App Flow:
  Gallery → Click "Emma" card
    → Task Input View appears
    → Header: 🌐 Emma — Web Builder — Ready to help
    → Greeting: "Hi! I'm Emma, your web builder. What would you like me to create today?"
    → Input: [text field with employee-specific placeholder]
    → Attachments + Assign button

  Input/Output Mapping:
  ┌─────────────────┬───────────────────────┬─────────────────────────────┬────────────────────────────┐
  │    App Input    │     App Function      │         App Output          │        User Benefit        │
  ├─────────────────┼───────────────────────┼─────────────────────────────┼────────────────────────────┤
  │ Employee        │ Load employee profile │ Personalized greeting       │ Feels like engaging a      │
  │ selection (tap) │  + greeting template  │ bubble + contextual         │ specialist, not a generic  │
  │                 │                       │ placeholder                 │ tool                       │
  ├─────────────────┼───────────────────────┼─────────────────────────────┼────────────────────────────┤
  │ Employee memory │ Inject past-work      │ "Last time you preferred    │ Continuity — employee      │
  │  (if exists)    │ reference into        │ React + Tailwind..."        │ "knows" them               │
  │                 │ greeting              │                             │                            │
  └─────────────────┴───────────────────────┴─────────────────────────────┴────────────────────────────┘
  What's missing from current build: TaskInputView shows the employee header but no greeting message. The
   placeholder is generic ("Describe the task...") not employee-specific. Need: a computed greeting
  property on Employee or a greeting service that factors in memory.

  ---
  Feature 2: Clarification Flow (The "Clarify" Stage)

  UX promise it serves: Phase 1 — "Emma asks smart questions, shows she 'gets it'". The task lifecycle in
   the doc is explicitly: Clarify → Plan → Execute → Review → Deliver.

  User Story: As a user who just assigned a task, I want the employee to ask me 2-3 smart clarifying
  questions before starting work, so that I trust the employee understands what I need and the output
  matches my expectations.

  Frontend Interaction Flow:
  1. User types task description + clicks "Assign Task"
  2. Instead of immediately jumping to progress/execute, the view transitions to a Clarification Chat
  3. Employee sends 1-3 targeted questions: "What's your target audience?" / "Do you have brand colors?"
  4. User replies inline (quick reply chips for common answers + free text)
  5. Employee acknowledges: "Got it! Here's my plan..." → transitions to Plan stage
  6. User can skip clarification: "Just get started" button

  Exact App Flow:
  Task Input → "Assign Task"
    → Clarification View appears
    → Emma: "Before I start, a few questions:"
    → Q1: "Who is the target audience?" [chips: B2B / B2C / Internal / Other]
    → Q2: "Do you have brand guidelines?" [chips: Yes, share / No / Keep it simple]
    → User taps chips or types answers
    → Emma: "Perfect, I'll build a clean B2B landing page. Here's my approach..."
    → [Skip: "Just get started →" button at bottom]

  Input/Output Mapping:
  ┌──────────────────┬──────────────────────────────┬─────────────────────────┬────────────────────────┐
  │    App Input     │         App Function         │       App Output        │      User Benefit      │
  ├──────────────────┼──────────────────────────────┼─────────────────────────┼────────────────────────┤
  │                  │ Employee analyzes            │ 1-3 contextual          │ Output matches intent  │
  │ Task description │ description, generates       │ questions with          │ — no "that's not what  │
  │                  │ clarifying questions         │ quick-reply chips       │ I wanted"              │
  ├──────────────────┼──────────────────────────────┼─────────────────────────┼────────────────────────┤
  │ User answers     │ Append context to task       │ Enriched task brief     │ Better quality work on │
  │ (chips or text)  │ description, refine scope    │ passed to execution     │  first attempt         │
  ├──────────────────┼──────────────────────────────┼─────────────────────────┼────────────────────────┤
  │ "Skip" action    │ Mark clarify stage complete, │ Immediate execution     │ Power users aren't     │
  │                  │  advance to plan/execute     │                         │ slowed down            │
  └──────────────────┴──────────────────────────────┴─────────────────────────┴────────────────────────┘
  What's missing from current build: Entirely missing. Currently, task submission goes straight to
  chat.send → execute. The StageIndicatorView shows stages but they're static. Need: a ClarificationView
  that intercepts between task assignment and execution, with a chat-like Q&A interface.

  ---
  Feature 3: Plan Presentation (The "Plan" Stage)

  UX promise it serves: Phase 1 — "Emma works, user sees progress" and the explicit lifecycle Clarify →
  Plan → Execute → Review → Deliver. The doc's "Quality Gates" section describes checks before delivery —
   plan approval is the first gate.

  User Story: As a user, I want the employee to show me their step-by-step plan before doing the work, so
   that I can approve the approach, suggest changes, or redirect before time is wasted.

  Frontend Interaction Flow:
  1. After clarification (or immediately if skipped), the employee generates a plan
  2. Plan appears as a structured checklist: "1. Set up HTML structure, 2. Design responsive layout, 3.
  Add content sections..."
  3. Each step has an estimated effort indicator (light/medium/heavy)
  4. Bottom: "Approve Plan" / "Suggest Changes" / "Cancel"
  5. If user suggests changes → inline edit or comment → employee revises plan
  6. Approved → transitions to Execute stage

  Exact App Flow:
  Clarify complete (or skipped)
    → Plan View appears
    → Emma: "Here's how I'll approach this:"
    → Checklist:
        ☐ 1. Create HTML structure with semantic markup
        ☐ 2. Design responsive CSS with your blue/white palette
        ☐ 3. Add hero section, features, and CTA
        ☐ 4. Test cross-browser compatibility
        ☐ 5. Final review and optimization
    → [Approve Plan ✓] [Suggest Changes ✏️] [Cancel ✕]

  Input/Output Mapping:
  ┌───────────────────┬───────────────────────┬───────────────────────────┬─────────────────────────────┐
  │     App Input     │     App Function      │        App Output         │        User Benefit         │
  ├───────────────────┼───────────────────────┼───────────────────────────┼─────────────────────────────┤
  │ Agent's           │ Parse into checklist  │ Visual step-by-step plan  │ Transparency — user sees    │
  │ structured plan   │ items                 │ with effort indicators    │ exactly what will happen    │
  │ text              │                       │                           │                             │
  ├───────────────────┼───────────────────────┼───────────────────────────┼─────────────────────────────┤
  │                   │ Mark plan stage       │ Progress view with plan   │ Confidence that work is on  │
  │ "Approve" tap     │ complete, begin       │ steps as milestones       │ track                       │
  │                   │ execute               │                           │                             │
  ├───────────────────┼───────────────────────┼───────────────────────────┼─────────────────────────────┤
  │ "Suggest Changes" │ Send revision to      │ Updated plan for          │ Control without             │
  │  + comment        │ agent, regenerate     │ re-approval               │ micro-managing              │
  │                   │ plan                  │                           │                             │
  └───────────────────┴───────────────────────┴───────────────────────────┴─────────────────────────────┘
  What's missing from current build: Entirely missing. The plan stage exists in the model
  (TaskStage.plan) but there's no UI for presenting or approving plans. Need: a PlanApprovalView shown
  between clarify and execute.

  ---
  Feature 4: Output Viewer & Delivery Moment

  UX promise it serves: Phase 1 — "Emma delivers website, user is delighted". The doc explicitly states:
  "Output-First UX: Workspace-centric, artifacts prominent" vs. OpenClaw's "Chat-centric".

  User Story: As a user whose task just completed, I want to see the actual deliverables front-and-center
   — with previews, thumbnails, and one-click open actions — so that the completion feels like receiving
  a finished product, not scrolling through a chat log.

  Frontend Interaction Flow:
  1. Task reaches "Deliver" stage → progress view transforms into Delivery view
  2. Hero section: success animation + "Task Complete" with time taken
  3. Output gallery: grid of deliverables with visual previews
    - Website → screenshot thumbnail → "Open in Browser"
    - Document → text excerpt → "Open in Finder"
    - Image → image thumbnail → "Quick Look"
  4. Activity log collapses to a "View Work Log" expandable section
  5. Below outputs: Feedback section (rating + comment)

  Exact App Flow:
  Progress View → Task completes
    → Transition animation: progress bar fills to 100%, checkmark appears
    → View transforms to Delivery View:
        ┌────────────────────────────────────────┐
        │ ✓ Task Complete — 12 minutes           │
        │ Emma built your landing page           │
        ├────────────────────────────────────────┤
        │ DELIVERABLES                           │
        │ ┌──────────┐  ┌──────────┐            │
        │ │ [thumb]  │  │ [thumb]  │            │
        │ │index.html│  │styles.css│            │
        │ │Open in ↗ │  │ Finder ↗ │            │
        │ └──────────┘  └──────────┘            │
        ├────────────────────────────────────────┤
        │ ▸ View Work Log (14 steps)             │
        ├────────────────────────────────────────┤
        │ Rate this work: ☆☆☆☆☆                 │
        │ [Request Changes] [Mark Complete]       │
        └────────────────────────────────────────┘

  Input/Output Mapping:
  ┌──────────────┬────────────────────────────────────────┬───────────────────────┬─────────────────────┐
  │  App Input   │              App Function              │      App Output       │    User Benefit     │
  ├──────────────┼────────────────────────────────────────┼───────────────────────┼─────────────────────┤
  │ Task         │                                        │ Visual grid of        │ Feels like          │
  │ completion   │ Detect outputs from agent tool calls   │ deliverables with     │ receiving finished  │
  │ event        │ (files created)                        │ type-specific         │ work, not reading   │
  │              │                                        │ previews              │ logs                │
  ├──────────────┼────────────────────────────────────────┼───────────────────────┼─────────────────────┤
  │ "Open in     │ NSWorkspace.shared.open(url)           │ File opens in default │ Immediate use of    │
  │ Browser" tap │                                        │  app                  │ deliverable         │
  ├──────────────┼────────────────────────────────────────┼───────────────────────┼─────────────────────┤
  │ "Open in     │ NSWorkspace.shared.selectFile(path)    │ Finder window with    │ Easy file           │
  │ Finder" tap  │                                        │ file selected         │ management          │
  ├──────────────┼────────────────────────────────────────┼───────────────────────┼─────────────────────┤
  │ "Quick Look" │                                        │                       │ Instant preview     │
  │  tap         │ QLPreviewPanel integration             │ Native macOS preview  │ without app         │
  │              │                                        │                       │ switching           │
  └──────────────┴────────────────────────────────────────┴───────────────────────┴─────────────────────┘
  What's missing from current build: Entirely missing. TaskProgressView shows the activity log +
  controls, but there's no output detection, no deliverable gallery, no delivery celebration moment.
  Need: OutputViewerView, OutputCardView, OutputPreviewView, and a delivery transition in
  TaskProgressView.

  ---
  Feature 5: Feedback & Revision System

  UX promise it serves: Phase 2 — "They learned my style" and Phase 4 — "User rarely needs to correct or
  clarify". The doc's table says: "Preference tracking, feedback loops".

  User Story: As a user reviewing a completed task, I want to rate the work, leave feedback, and
  optionally request specific changes that get applied with full context, so that the employee improves
  over time and I get exactly what I want.

  Frontend Interaction Flow:
  1. Delivery view shows rating stars (1-5) + comment field
  2. User taps stars → optional comment → "Submit Feedback"
  3. If unsatisfied → "Request Changes" reveals a revision input
  4. User describes what to change: "Make the hero section larger and add a testimonials section"
  5. Employee starts a revision in the same session (full context preserved)
  6. Progress view reappears for the revision cycle
  7. On re-delivery, previous feedback is visible as history

  Exact App Flow:
  Delivery View → Rate: ★★★☆☆
    → Comment: "Love the layout, but hero is too small"
    → [Request Changes]
    → Revision Input: "Make the hero section 2x larger, add testimonials"
    → [Send Revision →]
    → Progress View reappears (Stage: Execute → Review → Deliver)
    → Revised delivery shows updated outputs
    → Previous attempt visible in "Revision History" expandable

  Input/Output Mapping:
  ┌──────────────────┬──────────────────────┬──────────────────────────────┬───────────────────────────┐
  │    App Input     │     App Function     │          App Output          │       User Benefit        │
  ├──────────────────┼──────────────────────┼──────────────────────────────┼───────────────────────────┤
  │ Star rating      │ Store rating in task │ Rating visible on task       │ Future work quality       │
  │ (1-5)            │  manifest + employee │ history                      │ improves from tracked     │
  │                  │  memory              │                              │ satisfaction              │
  ├──────────────────┼──────────────────────┼──────────────────────────────┼───────────────────────────┤
  │                  │ Store as feedback,   │ Employee references feedback │ Progressive improvement — │
  │ Comment text     │ surface in employee  │  in future: "I'll make it    │  employee learns          │
  │                  │ memory               │ larger this time"            │ preferences               │
  ├──────────────────┼──────────────────────┼──────────────────────────────┼───────────────────────────┤
  │ Revision request │ Start new agent run  │ New execution cycle with     │ Efficient iteration — no  │
  │  + description   │ in same session      │ full prior context           │ re-explaining the whole   │
  │                  │                      │                              │ task                      │
  └──────────────────┴──────────────────────┴──────────────────────────────┴───────────────────────────┘
  What's missing from current build: Entirely missing. Need: FeedbackView (star rating + comment +
  revision input), revision flow in TaskService, and history display for multiple revision cycles.

  ---
  Feature 6: Employee Memory Display

  UX promise it serves: Phase 2 — "Employees remember preferences: 'Last time you preferred blue...'" and
   Phase 4 — "Employees have learned user's style deeply".

  User Story: As a user selecting an employee, I want to see what they remember about my preferences and
  past work, so that I trust the employee retains context and I don't have to repeat myself.

  Frontend Interaction Flow:
  1. Employee card shows a subtle "memory" indicator (small brain icon if memories exist)
  2. Clicking employee → greeting references memories naturally
  3. Employee detail popover (long-press or info button): shows memory summary
  4. Memory items are editable: user can correct or delete incorrect memories
  5. In task progress, when employee references a memory, it's highlighted

  Exact App Flow:
  Gallery → Long-press Emma's card → Popover:
    ┌────────────────────────────────────┐
    │ 🌐 Emma — Web Builder             │
    │                                    │
    │ WHAT I REMEMBER                    │
    │ • Prefers React + Tailwind         │
    │ • Brand colors: #1A365D, #FFFFFF   │
    │ • Deploys to Vercel                │
    │ • Likes minimal, clean designs     │
    │ • Past: Built landing page (Jan)   │
    │                                    │
    │ [Edit Memories] [Clear All]        │
    └────────────────────────────────────┘

  Input/Output Mapping:
  ┌───────────────┬─────────────────────────────────┬────────────────────────┬──────────────────────────┐
  │   App Input   │          App Function           │       App Output       │       User Benefit       │
  ├───────────────┼─────────────────────────────────┼────────────────────────┼──────────────────────────┤
  │ Employee      │ Fetch memory summary from       │ Structured memory list │ Trust — user sees the    │
  │ selection     │ workforce.employees.memory      │  (preferences, past    │ employee retains context │
  │               │                                 │ work, style notes)     │                          │
  ├───────────────┼─────────────────────────────────┼────────────────────────┼──────────────────────────┤
  │ Memory        │ Update/remove memory entries    │ Updated memory,        │ Control — user corrects  │
  │ edit/delete   │ via gateway                     │ reflected in future    │ misunderstandings        │
  │               │                                 │ task execution         │                          │
  ├───────────────┼─────────────────────────────────┼────────────────────────┼──────────────────────────┤
  │ Task          │ Employee system prompt includes │ Output reflects        │ Efficiency — no          │
  │ execution     │  memories                       │ learned preferences    │ re-explaining            │
  │ context       │                                 │ without being asked    │ preferences every time   │
  └───────────────┴─────────────────────────────────┴────────────────────────┴──────────────────────────┘
  What's missing from current build: Entirely missing. Need: EmployeeMemoryView popover, memory fetch
  integration in EmployeeService, editable memory list UI.

  ---
  Feature 7: Notification System

  UX promise it serves: Phase 2 — The doc shows: "Phone notification: 'Emma completed 3 tasks
  overnight'". Also: "Push notification: 'All tasks complete'" when queued tasks finish.

  User Story: As a user who assigned work and stepped away, I want to receive macOS notifications when
  tasks complete, fail, or need my attention, so that I know when deliverables are ready without keeping
  the app in the foreground.

  Frontend Interaction Flow:
  1. Task completes → macOS notification: "Emma finished: Landing page for consulting"
  2. Task fails → notification with recovery action: "David's task failed. [View Error]"
  3. Task needs input (clarification question) → "Emma has a question about your task"
  4. Clicking notification → opens app to the relevant task
  5. Menu bar badge shows count of pending items (completions to review, questions to answer)

  Exact App Flow:
  User closes app / switches to another app
    → Task completes in background
    → macOS Notification Center:
        ┌────────────────────────────────────┐
        │ Workforce                          │
        │ ✓ Emma finished your landing page  │
        │ Tap to review deliverables         │
        └────────────────────────────────────┘
    → User clicks notification → App activates → Delivery View

  Input/Output Mapping:
  ┌───────────────┬───────────────────────────────┬────────────────────────────┬───────────────────────┐
  │   App Input   │         App Function          │         App Output         │     User Benefit      │
  ├───────────────┼───────────────────────────────┼────────────────────────────┼───────────────────────┤
  │ Task          │                               │                            │ Awareness without     │
  │ completion    │ UNUserNotificationCenter push │ macOS notification with    │ monitoring — "fire    │
  │ event         │                               │ task summary               │ and forget" task      │
  │               │                               │                            │ assignment            │
  ├───────────────┼───────────────────────────────┼────────────────────────────┼───────────────────────┤
  │ Task failure  │ Notification with error       │ "[employee] couldn't       │ Quick triage of       │
  │ event         │ summary                       │ complete [task]. Tap to    │ failures              │
  │               │                               │ see details."              │                       │
  ├───────────────┼───────────────────────────────┼────────────────────────────┼───────────────────────┤
  │ Notification  │ Deep link to specific task    │ App opens to that task's   │ Instant navigation to │
  │ tap           │                               │ delivery/progress view     │  relevant context     │
  ├───────────────┼───────────────────────────────┼────────────────────────────┼───────────────────────┤
  │ Menu bar      │ Count unreviewed completions  │ Badge number on dock icon  │ Ambient awareness of  │
  │ badge         │ + unanswered questions        │                            │ pending work          │
  └───────────────┴───────────────────────────────┴────────────────────────────┴───────────────────────┘
  What's missing from current build: Entirely missing. Need: UNUserNotificationCenter integration in
  TaskService, notification scheduling on task state changes, deep linking from notification to specific
  task, dock badge management.

  ---
  Feature 8: Task Queue with Tier Visibility

  UX promise it serves: Phase 2 — "Tasks ready (Tier 4 - Local needed): ⏸ Website preview (needs your
  browser to test)". The doc's Stratified Execution Model shows 4 tiers of task capability.

  User Story: As a user reviewing my task list, I want to see which tasks can run now, which are queued
  waiting for my laptop, and why — so that I understand the "always-on" model and can unblock tasks when
  I choose.

  Frontend Interaction Flow:
  1. Dashboard shows tasks grouped by executability, not just status
  2. Cloud-ready tasks (Tier 1-2): running or ready to run, green indicator
  3. Local-only tasks (Tier 3-4): queued with explanation chip: "Needs browser" / "Needs local files"
  4. When laptop comes online → queued tasks auto-start → notification: "3 queued tasks starting"
  5. Suggestion nudge: "Move this file to Google Drive so Emma can work on it anytime"

  Exact App Flow:
  Dashboard:
    RUNNING NOW (cloud-capable)
    │ 🌐 Emma: Draft follow-up emails        [API] ██████░░ 72%
    │ 🔍 Sarah: Research competitor pricing   [API] ███░░░░░ 35%

    QUEUED (needs your Mac)
    │ 🌐 Emma: Preview website locally        [Browser] ⏸ Waiting
    │     → "Needs your browser to test. Will run when you're back."
    │ 📊 David: Export from Figma             [App] ⏸ Waiting
    │     → "Needs Figma access. Will run when Figma is available."
    │     💡 "Use Google Slides instead for 24/7 access"

  Input/Output Mapping:
  ┌─────────────────┬──────────────────────────────────┬──────────────────────┬─────────────────────────┐
  │    App Input    │           App Function           │      App Output      │      User Benefit       │
  ├─────────────────┼──────────────────────────────────┼──────────────────────┼─────────────────────────┤
  │ Task            │ Route task to execution tier     │ Tier badge +         │ Transparency — user     │
  │ requirements    │ (API/file/browser/local)         │ explanation on each  │ understands what needs  │
  │ analysis        │                                  │ task                 │ their laptop            │
  ├─────────────────┼──────────────────────────────────┼──────────────────────┼─────────────────────────┤
  │ Laptop online   │ Detect queued tasks, auto-start  │ Queued tasks begin   │ Seamless continuation — │
  │ event           │ local-only work                  │ executing +          │  no manual intervention │
  │                 │                                  │ notification         │                         │
  ├─────────────────┼──────────────────────────────────┼──────────────────────┼─────────────────────────┤
  │ "Move to cloud" │ Suggest cloud alternative for    │ Migration prompt     │ Progressive 24/7        │
  │  suggestion     │ frequently blocked tasks         │ with one-click       │ capability — less       │
  │                 │                                  │ action               │ waiting over time       │
  └─────────────────┴──────────────────────────────────┴──────────────────────┴─────────────────────────┘
  What's missing from current build: Entirely missing. This is a Phase B+ feature requiring backend task
  routing intelligence. Frontend needs: tier indicator on TaskRowView, queue explanation chips,
  auto-start trigger on reconnect, migration suggestion UI.

  ---
  Feature 9: Onboarding & First-Run Experience

  UX promise it serves: Phase 1 — "Quick setup: connect Google/Microsoft account" and "Sees: 'Meet your
  AI Employees' - gallery of specialists".

  User Story: As a first-time user, I want a guided walkthrough that introduces me to my AI employees,
  helps me connect to the gateway, and gets me to my first successful task in under 2 minutes, so that I
  immediately see the value of the product.

  Frontend Interaction Flow:
  1. First launch → Welcome screen: "Meet Your AI Workforce"
  2. Step 1: Gateway auto-detection (scans localhost:18789). If found → green check. If not → setup
  instructions.
  3. Step 2: Employee introduction carousel — each employee introduces themselves
  4. Step 3: First task prompt — "Try assigning your first task to Emma"
  5. Guided task assignment with inline hints
  6. Success → celebration + "You've got a team. Explore on your own."

  Exact App Flow:
  First launch:
    ┌────────────────────────────────────────────┐
    │         Welcome to Workforce               │
    │                                            │
    │   Meet your AI employees — specialists     │
    │   who work in your digital workspace.      │
    │                                            │
    │   [Get Started →]                          │
    └────────────────────────────────────────────┘
    → Step 1: Detecting gateway... ✓ Connected
    → Step 2: Employee carousel (swipe through Emma, David, Sarah)
    → Step 3: "Try it! Ask Emma to build something."
    → User types task → submits → sees progress
    → "You're all set. Your workforce is ready."

  Input/Output Mapping:
  ┌────────────────┬──────────────────────────────┬────────────────────────┬────────────────────────────┐
  │   App Input    │         App Function         │       App Output       │        User Benefit        │
  ├────────────────┼──────────────────────────────┼────────────────────────┼────────────────────────────┤
  │ First launch   │ Check UserDefaults for       │ Onboarding flow vs     │ Guided experience — not    │
  │ detection      │ onboarding-complete flag     │ normal gallery         │ dropped into empty app     │
  ├────────────────┼──────────────────────────────┼────────────────────────┼────────────────────────────┤
  │ Gateway        │ Attempt WebSocket connection │ Status: connected/not  │ Zero-config when gateway   │
  │ auto-scan      │  to default port             │ found + setup help     │ is running                 │
  ├────────────────┼──────────────────────────────┼────────────────────────┼────────────────────────────┤
  │ First task     │                              │ Onboarding complete    │ Immediate value            │
  │ completion     │ Track in UserDefaults        │ flag + celebration     │ demonstration — "this      │
  │                │                              │                        │ works" moment              │
  └────────────────┴──────────────────────────────┴────────────────────────┴────────────────────────────┘
  What's missing from current build: Entirely missing. Need: OnboardingView with multi-step flow, gateway
   auto-detection step, employee carousel, first-task guidance overlay.

  ---
  Feature 10: Employee Customization

  UX promise it serves: Phase 4 — "My team, my way" and "Customizable employee behaviors".

  User Story: As a user who's been working with my employees for a while, I want to adjust their
  personality, communication style, and tool permissions, so that they work exactly how I prefer.

  Frontend Interaction Flow:
  1. Settings → Employees tab → list of all employees
  2. Click employee → edit form: name, persona description, communication style
  3. Tool permissions: toggles for browser, shell, file system, etc.
  4. Communication preferences: verbose/concise, formal/casual
  5. Save → changes apply to next task

  Exact App Flow:
  Settings → Employees tab:
    ┌──────────────────────────────────────────┐
    │ EMPLOYEES                                │
    │                                          │
    │ 🌐 Emma — Web Builder          [Edit]   │
    │ 📊 David — Deck Maker          [Edit]   │
    │ 🔍 Sarah — Research Analyst    [Edit]   │
    └──────────────────────────────────────────┘
    → Click "Edit" on Emma:
    ┌──────────────────────────────────────────┐
    │ Edit: Emma                               │
    │                                          │
    │ Personality: [Professional, warm, asks   │
    │ clarifying questions before starting]    │
    │                                          │
    │ Style:  ○ Verbose  ● Concise             │
    │ Tone:   ○ Formal   ● Casual              │
    │                                          │
    │ Tool Access:                             │
    │ ☑ Browser     ☑ File System              │
    │ ☑ Shell       ☐ System Commands          │
    │                                          │
    │ [Save Changes]                           │
    └──────────────────────────────────────────┘

  Input/Output Mapping:
  ┌──────────────────┬───────────────────────┬──────────────────────────┬───────────────────────────────┐
  │    App Input     │     App Function      │        App Output        │         User Benefit          │
  ├──────────────────┼───────────────────────┼──────────────────────────┼───────────────────────────────┤
  │ Personality text │ Write to IDENTITY.md  │ Updated agent system     │ Employee behaves according to │
  │  edit            │ via gateway           │ prompt                   │  user's preferences           │
  ├──────────────────┼───────────────────────┼──────────────────────────┼───────────────────────────────┤
  │ Tool permission  │ Update config.yaml    │ Agent tool allowlist     │ Control over what employees   │
  │ toggles          │ via gateway           │ changes                  │ can do on the system          │
  ├──────────────────┼───────────────────────┼──────────────────────────┼───────────────────────────────┤
  │ Style/tone       │ Append to identity    │ Adjusted communication   │ Output matches preferred      │
  │ selectors        │ instructions          │ in future tasks          │ communication style           │
  └──────────────────┴───────────────────────┴──────────────────────────┴───────────────────────────────┘
  What's missing from current build: Entirely missing. Need: EmployeeSettingsView with edit form,
  workforce.employees.update gateway integration, tool permission toggle UI.

  ---
  Feature 11: Task History & Search

  UX promise it serves: Phase 3 — the "manager with a capable team" feeling requires being able to review
   past work across employees and time periods.

  User Story: As a user managing multiple employees over time, I want to search and filter my task
  history by employee, date, and status, so that I can find past deliverables and track productivity.

  Frontend Interaction Flow:
  1. Tasks sidebar section shows search bar at top
  2. Type to search task descriptions: "landing page" → filters to matching tasks
  3. Filter chips: employee (Emma/David/Sarah), status (active/completed/failed), date range
  4. Results show grouped by date with employee avatars
  5. Click any historical task → opens its delivery view with outputs

  Exact App Flow:
  Tasks → Dashboard:
    ┌────────────────────────────────────────────┐
    │ [🔍 Search tasks...]                       │
    │ [Emma ✕] [David] [Sarah] [All Statuses ▾] │
    ├────────────────────────────────────────────┤
    │ TODAY                                      │
    │ 🌐 Landing page for consulting  ✓ 12min   │
    │ 📊 Q4 investor deck             ✓ 8min    │
    │                                            │
    │ YESTERDAY                                  │
    │ 🔍 Competitor pricing analysis   ✓ 22min   │
    │ 🌐 Portfolio website update      ✗ Failed  │
    │                                            │
    │ LAST WEEK                                  │
    │ ...                                        │
    └────────────────────────────────────────────┘

  Input/Output Mapping:
  ┌──────────────────┬─────────────────────────┬─────────────────────────────┬──────────────────────────┐
  │    App Input     │      App Function       │         App Output          │       User Benefit       │
  ├──────────────────┼─────────────────────────┼─────────────────────────────┼──────────────────────────┤
  │ Search query     │ Filter tasks by         │ Filtered task list          │ Find past deliverables   │
  │ text             │ description match       │                             │ quickly                  │
  ├──────────────────┼─────────────────────────┼─────────────────────────────┼──────────────────────────┤
  │ Employee filter  │ Filter by employeeId    │ Tasks from selected         │ Review one employee's    │
  │                  │                         │ employee only               │ track record             │
  ├──────────────────┼─────────────────────────┼─────────────────────────────┼──────────────────────────┤
  │ Date range       │ Filter by createdAt     │ Time-scoped results         │ "What did my team do     │
  │ filter           │ range                   │                             │ this week?"              │
  ├──────────────────┼─────────────────────────┼─────────────────────────────┼──────────────────────────┤
  │ Task tap         │ Load task detail with   │ Delivery view with files    │ Access past deliverables │
  │ (historical)     │ outputs                 │ still accessible            │  anytime                 │
  └──────────────────┴─────────────────────────┴─────────────────────────────┴──────────────────────────┘
  What's missing from current build: Dashboard exists but has no search, no filters, no date grouping.
  Need: search bar in TaskDashboardView, filter chips, date-grouped sections, workforce.tasks.list filter
   params.

  ---
  Feature 12: Rich Progress View (Enhanced "Watching Someone Work")

  UX promise it serves: Phase 1 — "Emma works, user sees progress". The doc says this is the "watching
  someone work" moment. The current activity log is functional but needs to feel alive.

  User Story: As a user watching an employee work, I want to see rich, contextual progress — not just
  "tool call" entries, but what they're actually doing with meaningful descriptions and visual cues — so
  that it feels like watching a contractor work on my project.

  Frontend Interaction Flow:
  1. Progress view with plan steps as milestones (from Feature 3)
  2. Current step highlighted with animated indicator
  3. Activity entries are contextualized: "Creating index.html" not "write_file called"
  4. File previews inline as they're created (live thumbnails)
  5. When executing shell commands: live terminal output snippet
  6. Progress bar ties to plan steps (1 of 5 → 20%, 2 of 5 → 40%)
  7. Elapsed time counter + estimated time remaining (based on plan)

  Input/Output Mapping:
  ┌──────────────┬─────────────────────────────────┬──────────────────────────┬────────────────────────┐
  │  App Input   │          App Function           │        App Output        │      User Benefit      │
  ├──────────────┼─────────────────────────────────┼──────────────────────────┼────────────────────────┤
  │ Agent        │ Contextualize:                  │ Human-readable activity  │ Understandable         │
  │ tool_call    │ write_file(index.html) →        │ descriptions             │ progress, not raw      │
  │ events       │ "Creating index.html"           │                          │ technical events       │
  ├──────────────┼─────────────────────────────────┼──────────────────────────┼────────────────────────┤
  │ File         │ Generate inline                 │ Live file preview as     │ Excitement — watching  │
  │ creation     │ thumbnail/preview               │ work progresses          │ deliverables           │
  │ events       │                                 │                          │ materialize            │
  ├──────────────┼─────────────────────────────────┼──────────────────────────┼────────────────────────┤
  │ Plan step    │ Map activity to plan steps,     │ Milestone-based progress │ Accurate progress      │
  │ completion   │ advance progress bar            │  (not activity-count     │ estimation tied to     │
  │              │                                 │ heuristic)               │ actual plan            │
  └──────────────┴─────────────────────────────────┴──────────────────────────┴────────────────────────┘
  What's partially built: ActivityLogView exists with type-specific icons and auto-scrolling. But:
  activity messages come from raw event names, no plan-step mapping, no file previews, no milestone
  progress. Need: enhanced activity mapping in TaskService, plan-step progress binding, inline preview
  loading.

  ---
  Summary: Feature Priority by UX Phase
  ┌──────────┬──────────────────────────────┬───────────┬────────┬─────────────────┐
  │ Priority │           Feature            │ UX Phase  │ Effort │ Current Status  │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P0       │ F4: Output Viewer & Delivery │ Phase 1   │ Medium │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P0       │ F2: Clarification Flow       │ Phase 1   │ Medium │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P0       │ F3: Plan Presentation        │ Phase 1   │ Medium │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P0       │ F12: Rich Progress           │ Phase 1   │ Low    │ Partially built │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P1       │ F1: Employee Greeting        │ Phase 1   │ Low    │ Partially built │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P1       │ F5: Feedback & Revision      │ Phase 2   │ Medium │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P1       │ F7: Notifications            │ Phase 2   │ Low    │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P1       │ F9: Onboarding               │ Phase 1   │ Medium │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P2       │ F6: Memory Display           │ Phase 2   │ Low    │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P2       │ F11: Task History & Search   │ Phase 3   │ Low    │ Partially built │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P2       │ F10: Employee Customization  │ Phase 4   │ Medium │ Not built       │
  ├──────────┼──────────────────────────────┼───────────┼────────┼─────────────────┤
  │ P3       │ F8: Task Queue Tiers         │ Phase 2-3 │ High   │ Not built       │
  └──────────┴──────────────────────────────┴───────────┴────────┴─────────────────┘
  The P0 features (Output Viewer, Clarification, Plan, Rich Progress) are the gap between "functional
  app" and the Phase 1 experience promise. Without them, the app is a task submission form + activity
  log. With them, it's the "hiring a capable contractor" experience the UX doc describes.
