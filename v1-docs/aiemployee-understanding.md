The Fundamental Gap

  After reading through the entire workforce extension, here's what I see:

  OpenClaw is a powerful general-purpose agent runtime. It can execute code, access
  the filesystem, run terminal commands, use MCP tools, read skills, browse the web,
   generate files. The raw capability to build websites, analyze data, write code,
  and create presentations already exists.

  But the workforce extension currently treats the agent as a black box. Look at
  what happens when a task is created:

  1. Task gets a sessionKey like "workforce-emma-web-<uuid>"
  2. before_agent_start hook fires — it only updates task status to running
  3. The agent starts with no employee-specific instructions whatsoever
  4. The agent gets the user's brief as a plain message
  5. Events come back, get categorized by text heuristics
  6. Agent finishes, task marked complete

  Emma, David, and Sarah are labels on the same agent. They have different names and
   emojis in the UI, but the AI behind them is identical. No system prompt
  differentiation. No tool configuration. No personality. No quality standards. No
  domain expertise injection. The agentId field on EmployeeConfig exists but is
  never consumed.

  The gap is not capability — it's channeling. The raw power is there. What's
  missing is the architecture that turns a general-purpose agent into something that
   feels like a specific, competent, human employee.

  ---
  First Principles: What Makes a Great Employee

  Think about the best employee you've ever worked with, or the best contractor
  you've ever hired. What made them great wasn't just skill. It was a combination of
   things:

  1. They know their craft deeply

  A great web designer doesn't just "make websites." They think in terms of visual
  hierarchy, conversion rates, whitespace, mobile-first layouts, page load
  performance. When you say "build me a landing page," they automatically consider
  what a landing page needs: hero section, value proposition, social proof, CTA.
  They don't need you to tell them this. It's built into how they think.

  The current state: The agent gets "build me a landing page" and approaches it as a
   general AI task. It might produce something decent, but it won't think like a
  specialist.

  2. They know your business

  After working with you for a week, a great employee knows your brand colors, your
  tone of voice, your target audience, what you liked and didn't like about their
  previous work. They don't start from scratch every time.

  The current state: Every task is a fresh conversation. No memory of preferences.
  No brand context. No learning from feedback.

  3. They have judgment about when to ask vs. act

  A junior employee asks about everything — it's exhausting. A bad employee assumes
  everything — it's dangerous. A great employee makes expert decisions autonomously
  (picks the right font, chooses the right chart type) and only asks when the
  decision is genuinely subjective or high-stakes ("Should the hero section feature
  your product or a lifestyle image?").

  The current state: The agent's clarification behavior is entirely up to the
  generic AI. No calibration per domain, no policy about what's worth asking.

  4. They check their own work

  A great employee doesn't show you the first draft. They review it, find the
  obvious issues, fix them, then present a polished result. They have internal
  quality standards.

  The current state: The agent generates output and delivers it immediately. No
  self-review step. No quality gate before the user sees the work.

  5. They present their work, not just deliver it

  There's a difference between dropping a file on your desk and presenting work:

  - AI behavior: "Here is the file: landing-page.html"
  - Employee behavior: "I built the landing page based on your brief. I went with a
  minimal design — clean typography, lots of whitespace — since your brand seems to
  lean that way. The hero section uses your product screenshot rather than a stock
  photo because I think it builds more trust with your audience. I'm not 100% sure
  about the green CTA button; would you prefer something that matches your primary
  brand color instead? Here's the live preview."

  The difference: context awareness, decision transparency, self-assessment,
  specific feedback invitation.

  The current state: Output delivery is a file path or URL with a generic completion
   message. No explanation of decisions, no presentation of work.

  6. They get better over time

  A great employee applies feedback from task #1 to task #5. They learn your
  preferences. They develop new skills when needed.

  The current state: No feedback persistence. No memory across tasks. No capability
  growth.

  ---
  The Architecture: Three Layers

  To bridge the gap between "general-purpose agent" and "great digital employee," I
  think we need three layers:

  Layer 1: Employee Blueprint (Who they are)

  A comprehensive configuration that transforms a generic OpenClaw agent into a
  specific employee. This is the "soul" of each employee — their identity,
  expertise, and behavioral parameters.

  EmployeeBlueprint
  ├── identity
  │   ├── name, emoji, title
  │   ├── personality traits (e.g., methodical, creative, thorough)
  │   └── communication style (e.g., visual-first, data-driven, technical)
  │
  ├── expertise (the system prompt core)
  │   ├── domain knowledge (what they know deeply)
  │   ├── methodology (how they approach work in their field)
  │   ├── quality standards (what "good" looks like in their domain)
  │   └── common patterns (templates, structures they default to)
  │
  ├── tool configuration
  │   ├── primary tools (what they use most)
  │   ├── skills to auto-load (domain-specific SKILL.md files)
  │   └── tool preferences (e.g., Emma prefers Vite over Webpack)
  │
  ├── judgment calibration
  │   ├── autonomous decisions (things they never ask about)
  │   ├── ask-first decisions (things they always verify)
  │   └── escalation triggers (when to flag something as concerning)
  │
  └── output behavior
      ├── self-review checklist (domain-specific quality checks)
      ├── delivery format (how they present their work)
      └── feedback prompts (what specific feedback they request)

  Where this lives technically: The EmployeeConfig type in employees.ts expands from
   a display-data struct to a comprehensive blueprint. The before_agent_start hook
  reads the blueprint and composes a rich system prompt that gets injected into the
  agent session.

  Layer 2: Task Execution Pipeline (How they work)

  The current pipeline is: brief → (maybe clarify) → execute → deliver. A great
  employee's pipeline is richer:

  Brief received
      ↓
  [Internalization]
  Employee restates the task in their own domain language.
  "So you want a landing page for your SaaS product —
  I'll focus on conversion optimization with a clean,
  modern design."
      ↓
  [Smart Clarification]
  Employee asks ONLY what they genuinely need, based on
  their calibrated judgment. Domain-expert questions, not
  generic ones.
      ↓
  [Planning]
  Employee creates a plan that reflects their methodology.
  Emma's plan looks different from David's — different
  vocabulary, different structure, different deliverables.
      ↓
  [Execution with Self-Monitoring]
  Employee works through the plan, applying their expertise.
  They leverage domain-specific skills and tools.
      ↓
  [Self-Review] ← THIS IS NEW AND CRITICAL
  Employee reviews their own output against:
  - The original brief
  - Their domain quality standards
  - Known user preferences (from memory)
  Fixes issues before presenting.
      ↓
  [Structured Delivery]
  Employee presents the work with:
  - Summary of what was built
  - Key decisions and rationale
  - Things they're uncertain about
  - Specific questions for feedback
      ↓
  [Feedback Integration]
  User feedback gets stored in memory for future tasks.

  Where this lives technically: The execution pipeline is orchestrated by the system
   prompt itself. The system prompt tells the agent: "Before you present your
  output, review it against these criteria. If you find issues, fix them. When you
  present, explain your decisions." This is prompt engineering, not code.

  The self-review step is the single highest-leverage addition. It turns a "first
  draft" into a "polished deliverable."

  Layer 3: Memory & Context (What they know about you)

  Each employee maintains persistent context that gets richer over task:

  EmployeeMemory
  ├── user preferences
  │   ├── style preferences ("likes minimal design")
  │   ├── content preferences ("prefers data-driven arguments")
  │   └── workflow preferences ("wants to approve plans before execution")
  │
  ├── business context
  │   ├── company name and industry
  │   ├── brand identity (colors, tone, audience)
  │   └── competitive landscape
  │
  ├── feedback history
  │   ├── positive ("loved the chart style in last report")
  │   ├── corrective ("don't use stock photos")
  │   └── directional ("next time include mobile mockups")
  │
  └── learned patterns
      ├── what worked well in past tasks
      ├── common requests ("always include a mobile view")
      └── tools/approaches that the user prefers

  Where this lives technically: This maps to F11 (Memory Bank) in the roadmap.
  Stored as structured data per employee in ~/.openclaw/workforce/memory/. Injected
  into the system prompt at the start of each task: "Here's what you know about this
   user: [preferences]. Here's feedback from previous tasks: [learnings]."

  ---
  Harnessing OpenClaw's Untapped Power

  The user specifically said the power of OpenClaw hasn't been fully harnessed.
  Here's what I see as underutilized:

  Skills System → Employee Specialization

  OpenClaw agents can read SKILL.md files to gain specialized knowledge. Currently
  this is generic — agents discover skills on their own. For Workforce, we should
  create employee-specific skill packs:

  - skills/web-design/SKILL.md — Modern web design patterns, responsive layouts, CSS
   frameworks, accessibility standards
  - skills/data-analysis/SKILL.md — Data visualization best practices, chart
  selection guide, statistical analysis patterns
  - skills/presentation/SKILL.md — Slide design principles, storytelling with data,
  PowerPoint/Keynote generation techniques
  - skills/copywriting/SKILL.md — Brand voice guidelines, conversion copywriting,
  SEO principles

  Each employee's blueprint specifies which skills to auto-load. Emma starts every
  task with web design knowledge already available. David starts with data analysis
  expertise.

  Full Computer Access → Real Output Generation

  OpenClaw agents can run terminal commands, install packages, write files, launch
  servers. This means employees can produce real, production-quality output:

  - Emma can run npm create vite@latest, build actual React/HTML sites, serve them
  on localhost for live preview
  - David can run Python scripts with pandas/matplotlib, generate actual .xlsx files
   with openpyxl, create actual .pptx with python-pptx
  - Sarah can clone repos, run test suites, deploy to staging environments

  The current implementation doesn't guide the agent toward producing specific file
  types. The system prompt should instruct each employee: "Your deliverables should
  be actual files the user can use: .html/.css for websites, .xlsx for spreadsheets,
   .pptx for presentations."

  Self-Reinventing Skills → Employee Growth

  OpenClaw agents can write their own skill files. This means employees could
  develop new capabilities over time:

  - After building several websites, Emma could write a skills/user-brand/SKILL.md
  that encodes the user's specific brand preferences
  - After repeated data analysis tasks, David could create reusable analysis
  templates

  This is advanced (probably post-v1) but it's a powerful differentiator: employees
  that literally get better at their job over time.

  MCP Tool Ecosystem → Specialized Capabilities

  The MCP server architecture gives agents access to browser automation, web search,
   and more. Each employee can leverage different tools:

  - Emma: Browser preview (see the site she built), web search (find design
  inspiration)
  - David: File system (read user's data files), web search (find benchmark data)
  - Sarah: GitHub integration, deployment tools, testing frameworks

  ---
  What Makes Each Employee Feel Real

  Let me sketch what the system prompt core looks like for each employee type. This
  is the most important piece — it's what turns a generic agent into a specialist:

  Emma — Creative Strategist

  You are Emma, a creative strategist and web designer at Workforce.

  HOW YOU THINK:
  You approach every project as a design problem first. Before writing
  a line of code, you consider: Who is the audience? What action should
  they take? What feeling should the page evoke? You think in terms of
  visual hierarchy, conversion funnels, and user journeys.

  YOUR EXPERTISE:
  - Modern web design (responsive, mobile-first, accessible)
  - Brand identity and visual consistency
  - Conversion optimization (CTAs, social proof, value propositions)
  - Typography, color theory, whitespace
  - HTML/CSS/JavaScript, React, Tailwind, Vite

  DECISIONS YOU MAKE AUTONOMOUSLY (never ask about these):
  - Font pairings and typography choices
  - Responsive breakpoint strategies
  - CSS framework and build tool selection
  - Code architecture and file structure
  - Accessibility best practices

  DECISIONS YOU ALWAYS VERIFY WITH THE USER:
  - Brand direction (colors, mood, tone)
  - Content priorities (what's most important on the page)
  - Target audience characteristics
  - Whether to use real content vs. placeholder
  - Design style (minimal vs. bold vs. playful)

  YOUR QUALITY STANDARDS (check these before delivering):
  - Does it look good on mobile AND desktop?
  - Is the visual hierarchy clear (can you tell what's most important)?
  - Is the CTA prominent and compelling?
  - Does it load fast (no unnecessary dependencies)?
  - Is the code clean and maintainable?

  HOW YOU DELIVER WORK:
  When presenting output, explain your design decisions. Point out
  what you chose and why. Flag anything you're uncertain about.
  Ask for specific feedback rather than "do you like it?"

  David — Data Analyst

  You are David, a data analyst at Workforce.

  HOW YOU THINK:
  You approach every project as a story told through data. Before
  creating any visualization, you ask: What question are we answering?
  What's the narrative? What should the reader take away? You believe
  in simplicity — one chart should convey one insight clearly.

  YOUR EXPERTISE:
  - Data analysis and statistical interpretation
  - Data visualization (chart selection, color coding, labeling)
  - Presentation design (slide structure, data storytelling)
  - Python (pandas, matplotlib, openpyxl, python-pptx)
  - Excel/spreadsheet design and formatting

  DECISIONS YOU MAKE AUTONOMOUSLY:
  - Chart type selection (you pick the right chart for the data)
  - Statistical methods and calculations
  - Data cleaning and transformation approaches
  - Color schemes for data visualization
  - Slide layout and structure

  DECISIONS YOU ALWAYS VERIFY:
  - What business question to answer
  - Which data sources to use
  - Level of detail (executive summary vs. deep dive)
  - Key metrics and KPIs to highlight
  - Audience for the deliverable

  YOUR QUALITY STANDARDS:
  - Does each chart convey a single clear insight?
  - Are axes labeled and data points explained?
  - Is the narrative logical (beginning → insight → recommendation)?
  - Are numbers accurate (double-check calculations)?
  - Would a non-technical person understand this?

  HOW YOU DELIVER WORK:
  When presenting, walk through your key findings first. Explain
  what the data shows and what it means for the user's business.
  Highlight anything surprising or concerning. Recommend next steps.

  Each employee type gets this kind of rich, behavioral prompt. It's not a character
   sheet — it's an operational manual for how the AI should think, decide, and
  communicate in that specific domain.

  ---
  The Implementation Path

  Connecting all of this back to practical code changes:

  Phase 1: Employee Blueprint System (P0 — the foundation)

  What to build:
  - Expand EmployeeConfig with systemPrompt, skills, toolConfig,
  clarificationPolicy, qualityChecklist, deliveryInstructions
  - Write comprehensive system prompts for each default employee (Emma, David,
  Sarah)
  - Modify the before_agent_start hook to inject the full system prompt
  - Create employee-specific skill files under skills/

  Impact: This single change transforms the product. The employees go from identical
   agents with different names to specialized workers with distinct expertise.

  Phase 2: Self-Review Loop (P0 — quality differentiator)

  What to build:
  - Add self-review instructions to the system prompt: "Before presenting your
  deliverable, review it against your quality checklist. Fix any issues. Then
  present with a summary of decisions made."
  - Modify event-bridge to detect the self-review phase
  - Emit a workforce.task.stage event for the review stage so the UI shows it

  Impact: Output quality jumps dramatically. Users receive polished work, not first
  drafts.

  Phase 3: Structured Delivery (P0 — the human feel)

  What to build:
  - System prompt instructions for how to present output (explain decisions, ask for
   specific feedback)
  - Backend parsing of structured delivery messages (separate the "presentation"
  from the "files")
  - Frontend rendering of the delivery message alongside the output preview

  Impact: The interaction stops feeling like "AI generated a file" and starts
  feeling like "my employee is presenting their work to me."

  Phase 4: Smart Clarification Calibration (P1)

  What to build:
  - Per-employee clarification rules in the blueprint
  - System prompt section that explicitly lists autonomous vs. ask-first decisions
  - Brief analysis that respects the employee's calibration

  Impact: Clarification feels natural and domain-appropriate, not generic.

  Phase 5: Memory & Learning (P1-P2)

  What to build:
  - Persistent memory store per employee
  - Feedback extraction from user responses
  - Memory injection into system prompt at task start

  Impact: Employees get better over time. The product becomes more valuable the
  longer you use it.

  ---
  The Core Insight

  The entire "great employee" experience can be built primarily through system
  prompt architecture and execution pipeline design, not new AI capabilities.
  OpenClaw's agent runtime is already powerful enough. The work is:

  1. Write exceptional system prompts that encode identity, expertise, judgment, and
   behavior (this is the highest-leverage work)
  2. Add the self-review loop (a system prompt instruction + one new execution
  phase)
  3. Structure the delivery (system prompt instructions + frontend rendering)
  4. Persist memory (a storage layer + prompt injection)

  The most expensive engineering work is not building new infrastructure — it's the
  prompt engineering and behavioral tuning that makes each employee feel like a
  specialist rather than a chatbot with a name tag.

  ---
  Where would you like to go deeper? I see a few paths:
  - Detailed spec for the Employee Blueprint system (the EmployeeConfig expansion +
  system prompts)
  - Specific system prompt designs for Emma, David, Sarah (the actual prompt text)
  - Self-review architecture (how the execution pipeline changes)
  - Memory system design (persistence, retrieval, prompt injection)
