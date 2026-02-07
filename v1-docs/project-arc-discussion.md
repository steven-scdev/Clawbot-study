# Workforce AI Employee Architecture

## Core Insight

**The system is three things:**
1. **Memory** - Where we keep information at different scopes (documents, preferences, history)
2. **Skills** - What the employee can do, and how it learns to do more
3. **Context Injection** - Loading the right memory + skills at runtime when an agent does work

The UI is simply friendly channels for users to interact with each layer.

---

## Part 1: Memory Architecture

### The Four Memory Layers

#### Layer 1: User Library (Global)
**Scope:** Transferable across all projects and employees

**What it stores:**
- Style templates ("write like this", "design in this aesthetic")
- Global contacts and reference people
- User preferences and working style
- Reusable assets (logos, brand guidelines, voice samples)

**Key characteristic:** Skills and templates that transfer regardless of project context.

**User mental model:** "My personal library of things I've learned and collected"

#### Layer 2: Project Memory
**Scope:** Everything related to a specific project

**What it stores:**
- Project documents (briefs, specs, references)
- Previous outputs and deliverables
- Project-specific contacts and stakeholders
- History of what's been done
- Project context and goals

**Key characteristic:** Shared across all employees working on the same project.

**User mental model:** "Everything about this project lives here"

#### Layer 3: Employee Memory
**Scope:** Individual employee's identity and learned preferences

**What it stores:**
- Employee identity and personality (IDENTITY.md)
- Learned preferences from working with user
- Skills and specialized knowledge
- Past successful approaches
- User feedback and corrections
- Reference documents (user-provided examples and templates)
- Installed skills and capability profile

**Key characteristic:** Persists across all tasks the employee has done.

**User mental model:** "What this employee knows about me and how I like things done"

#### Layer 4: Task Memory (Ephemeral)
**Scope:** Single task execution

**What it stores:**
- Current task brief and requirements
- Active working files
- Task-specific context
- Intermediate outputs
- Newly discovered skills for this task

**Key characteristic:** Ephemeral - valuable learnings roll up into Employee memory after task completion.

**User mental model:** "The current thing we're working on right now"

---

### Reference Documents (User-Provided Teaching Materials)

Users primarily teach AI employees by showing examples, not by articulating preferences in words.

**User behaviors observed:**
- "Here's a presentation I did - make similar ones"
- "Here's how I write emails - match my style"
- "Here's an example of what I want"
- Attaching files directly in chat as task context

#### Document Attachment Flow

```
User attaches file in chat
  → Store original (for re-download, re-reference)
  → Extract content (text from PPT/PDF/DOCX/images)
  → Generate digest ("what this document teaches")
  → Index for retrieval (so the agent finds it when relevant)
```

**Two representations are stored:**
- **Original** - raw file, available if the agent needs to inspect specific pages/slides
- **Digest** - compressed summary for lightweight context injection

#### Storage

```
~/.openclaw/workspace-{employeeId}/
├── IDENTITY.md
├── MEMORY.md
├── references/                    # User-provided documents
│   ├── {doc-id}.json             # Metadata + digest
│   └── originals/
│       └── {doc-id}.pptx         # Raw file
└── memory/
    └── episodes/
```

#### Reference Metadata Schema

```json
{
  "id": "ref_abc123",
  "originalName": "Q4-review-deck.pptx",
  "addedAt": "2026-02-06",
  "addedVia": "chat-attachment",
  "type": "template",
  "digest": "Quarterly business review deck. 12 slides. Structure: exec summary → metrics → deep dives → next steps. Style: minimal text, heavy charts, blue/white palette.",
  "tags": ["presentation", "quarterly-review", "template"]
}
```

#### Context Injection at Task Time

Reference documents are summarized into the agent's context:

> **Reference Documents:**
> - Q4-review-deck.pptx (template) - "Quarterly business review, 12 slides, minimal text with charts"
> - Brand-guidelines.pdf (style guide) - "Company colors, fonts, logo usage rules"

Lightweight enough to always include. The agent knows what's available and can dig deeper into originals if needed.

---

### Context Injection Flow

When a task runs, the system injects memory in layers:

```
Task Execution Context =
    User Library (global preferences, style templates)
    + Project Memory (project docs, history, context)
    + Employee Memory (identity, learned preferences, reference digests)
    + Employee Skills (installed + pre-loaded skill instructions)
    + Task Memory (current brief, active files, newly acquired skills)
```

The runtime decides what to inject based on:
- Which project the task belongs to
- Which employee is assigned
- What the task needs
- What skills are relevant

---

### Proposed Storage Structure

```
~/.openclaw/
├── library/                    # Layer 1: User Library (global)
│   ├── styles/
│   ├── templates/
│   ├── contacts/
│   └── preferences.json
│
├── projects/                   # Layer 2: Project Memory
│   ├── {project-id}/
│   │   ├── documents/          # Project docs, references
│   │   ├── outputs/            # Previous deliverables
│   │   ├── history/            # What's been done
│   │   └── PROJECT.md          # Project context/goals
│   │
│   └── {another-project}/
│
├── workspace-{employee-id}/    # Layer 3: Employee Memory
│   ├── IDENTITY.md             # Who they are
│   ├── MEMORY.md               # Learned preferences
│   ├── CAPABILITIES.md         # Skills profile (auto-maintained)
│   ├── references/             # User-provided documents
│   │   ├── {doc-id}.json       # Metadata + digest
│   │   └── originals/          # Raw files
│   ├── skills/                 # Installed skills
│   │   └── {skill-name}/
│   │       └── SKILL.md
│   ├── skill-usage/            # Skill tracking data
│   │   └── usage-log.jsonl
│   └── memory/
│       └── episodes/           # Task records
│
└── tasks/                      # Layer 4: Task Memory (ephemeral)
    └── {task-id}/
        ├── brief.md
        └── working/
```

---

## Part 2: Skill Acquisition System

### Philosophy: The Intelligent, Trainable Employee

The goal is an employee that behaves like a superhuman worker:
- Comes pre-trained with relevant skills for their role
- Assesses their own capabilities before starting a task
- Discovers and learns new skills on the fly when needed
- Retains useful skills permanently
- Gets measurably better over time

### Three Capability Loops

#### Loop 1: Pre-Task Self-Assessment

Before diving into work, the employee pauses and thinks:

```
Task arrives
  → "What does this task require?"
  → Check installed skills: "Do I already have what I need?"
  → Search memory for similar past tasks
  → If skill gap identified:
      → Search skills.sh marketplace
      → Evaluate and install what's needed
  → Pull relevant reference documents
  → Generate plan
  → Begin execution
```

**Current gap:** Agents just start working immediately. No planning phase, no self-assessment.

**What we build:** A planning phase injected before the execution loop in `agent-runner.ts`. The employee evaluates its toolkit against the task requirements.

#### Loop 2: Feedback Extraction

When a user gives feedback, the system should extract and persist it:

```
User says "no, make it more concise"
  → Detect: this is a style preference correction
  → Categorize: { type: "style", preference: "concise over verbose" }
  → Persist to MEMORY.md preferences section
  → Apply immediately in current session
  → Apply automatically in all future sessions
```

**Feedback categories:**
- **Style preference** - "more concise", "use bullet points", "formal tone"
- **Factual correction** - "the budget is $50K not $40K"
- **Approach change** - "don't use that framework, use this one"
- **Quality signal** - "perfect", "good", thumbs up/down

**Current gap:** Feedback lives only in chat context and evaporates after session. MEMORY.md has a "Preferences" section but nothing automatically writes to it.

**What we build:** A post-turn hook that detects user corrections and persists them as structured preferences.

#### Loop 3: Dynamic Skill Acquisition

Employees can discover, install, and retain skills at runtime.

```
Employee identifies skill gap
  → Runs: skill_search("presentation design")
  → Gets: [ anthropics/skills@pptx, vercel-labs/agent-skills@web-design-guidelines, ... ]
  → Evaluates relevance to current task
  → Installs: skill_install("anthropics/skills@pptx")
  → Uses skill for current task
  → After task: skill is retained permanently
  → Next similar task: skill is already available, no search needed
```

---

### Skill Architecture: Pre-installed + Dynamic Discovery

#### Pre-installed Skills (Baseline Competence)

Each employee role ships with skills that make them immediately competent at what we claim they can do.

**Example:**
```yaml
david-decks (Deck Builder):
  pre-installed:
    - anthropics/skills@pptx          # PowerPoint creation
    - vercel-labs/agent-skills@web-design-guidelines  # Design sense
    - anthropics/skills@pdf           # PDF handling

sarah-research (Research Analyst):
  pre-installed:
    - anthropics/skills@pdf           # PDF reading
    - anthropics/skills@xlsx          # Spreadsheet analysis
    - anthropics/skills@docx          # Document creation

marketing-employee:
  pre-installed:
    - coreyhaines31/marketingskills@copywriting       # Copywriting
    - coreyhaines31/marketingskills@seo-audit          # SEO
    - coreyhaines31/marketingskills@marketing-psychology # Psychology
```

These are installed in the employee workspace during employee creation. The employee starts day one already capable.

#### Dynamic Discovery (Growth)

When the pre-installed skills aren't enough, the employee can search for more.

**Integration with skills.sh:**

skills.sh provides a CLI runtime:
```bash
npx skills find [query]       # Search for skills by keyword
npx skills add <skill> -g -y  # Install a skill
npx skills check              # Check for updates
npx skills update             # Update all skills
```

We wrap this in agent-facing tools (not raw bash access):

```typescript
// Agent-facing tools (thin wrappers around skills CLI)
skill_search(query: string)     → { results: SkillResult[] }
skill_install(skillId: string)  → { success: boolean, skillPath: string }
skill_list()                    → { installed: InstalledSkill[] }
```

**Why a wrapper instead of raw CLI:**
1. We can intercept and record every skill operation
2. We can add our own ranking/filtering on top of marketplace results
3. We can enforce security policies (block unsafe skills)
4. We can cache results to reduce latency
5. We own the data

#### The Decision Flow

```
Task arrives
  │
  ├─ Employee checks installed skills (skill_list)
  │   └─ "I have pptx, pdf, web-design-guidelines"
  │
  ├─ Employee evaluates: "Do I need anything else for this task?"
  │   ├─ YES → skill_search("chart generation data visualization")
  │   │        → Evaluate results
  │   │        → skill_install("best-match-skill")
  │   │        → Proceed with full toolkit
  │   │
  │   └─ NO → Proceed immediately (no latency penalty)
  │
  └─ Execute task with all available skills
```

**Key principle:** Already-installed skills skip the search entirely. The employee gets faster over time as its skill library grows.

---

### Skill Usage Tracking (The Data Flywheel)

Every skill operation is recorded for analytics:

```typescript
interface SkillUsageRecord {
  skillId: string;           // "anthropics/skills@pptx"
  skillSource: string;       // "skills.sh" | "clawhub" | "pre-installed"
  employeeId: string;        // "david-decks"
  employeeRole: string;      // "deck-builder"
  taskId: string;            // "task_xyz"
  taskBrief: string;         // "Create quarterly business review deck"
  action: string;            // "search" | "install" | "use"
  installedAt?: string;      // timestamp
  usedInTask: boolean;       // did the employee actually use it?
  taskOutcome: string;       // "completed" | "failed"
  userSatisfaction: string;  // "positive" | "negative" | "neutral" | "unknown"
  retained: boolean;         // kept permanently after task?
}
```

**User satisfaction signals (auto-detected):**
| Signal | Classification |
|--------|---------------|
| User accepts output without edits | positive |
| User says "good/perfect/love it" | strong positive |
| User asks for redo or says "no/wrong" | negative |
| User provides correction but continues | neutral |
| Session ends without clear signal | unknown |

**Storage:** `~/.openclaw/workspace-{employeeId}/skill-usage/usage-log.jsonl`

#### The Flywheel Effect

```
Week 1: Agents discover skills freely, we record everything
         ↓
Week 4: Data shows which skills are popular per role
         ↓
Week 8: We pre-install high-satisfaction skills by default
         ↓
Week 12: New employees start with battle-tested skill bundles
         ↓
         Better baseline → Less search latency → Better UX → More usage → More data
```

**Example insights after data collection:**
- "pptx skill: used in 85% of deck tasks, 92% satisfaction" → pre-install for all deck employees
- "copywriting: 70% satisfaction for marketing" → keep but look for better alternatives
- "seo-audit: frequently searched but rarely installed" → not matching user needs well
- "brainstorming: high satisfaction across ALL employee roles" → make it a universal pre-install

The curated skill bundles become the **output** of the data flywheel, not a starting assumption.

---

### Employee Capability Profile

Auto-maintained file that tracks what the employee can do:

**`CAPABILITIES.md`** (in employee workspace):

```markdown
## Role
Deck Builder - Specialized in presentation design and visual communication

## Pre-installed Skills
- anthropics/skills@pptx (installed: 2026-01-15, source: pre-installed)
- vercel-labs/agent-skills@web-design-guidelines (installed: 2026-01-15, source: pre-installed)
- anthropics/skills@pdf (installed: 2026-01-15, source: pre-installed)

## Acquired Skills
- remotion-dev/skills@remotion-best-practices (installed: 2026-02-03, source: skills.sh, discovered during: "Create animated product demo")
- anthropics/skills@xlsx (installed: 2026-02-06, source: skills.sh, discovered during: "Build financial deck with charts")

## Learned Preferences
- User prefers concise bullet points over paragraphs
- Always use company brand colors (#2563EB, #1E40AF)
- Presentations should be 10-15 slides max
- Charts preferred over tables for numerical data

## Domain Experience
- Marketing presentations: 12 tasks completed
- Financial reports: 3 tasks completed
- Product demos: 5 tasks completed

## Reference Documents
- Q4-review-deck.pptx (template, added 2026-02-01)
- Brand-guidelines.pdf (style guide, added 2026-01-20)
- Competitor-analysis.docx (reference, added 2026-02-04)
```

This file is read by the employee at the start of every task. It's the employee's self-model.

---

## Part 3: User-Visible Planning UX

### The Problem

Right now, users send a task and see a loading state until output appears. They don't know what's happening. This feels like a black box.

### The Opportunity

The planning/skill-acquisition phase is actually a **feature, not a bug**. Showing users what the employee is thinking and doing builds trust and makes the employee feel intelligent.

### What Users Should See

```
User: "Create a quarterly business review deck based on the template I gave you"

┌──────────────────────────────────────────────────┐
│  🧠 David is preparing for your task...          │
│                                                  │
│  ✅ Reviewing your reference documents           │
│     Found: Q4-review-deck.pptx (template)        │
│                                                  │
│  ✅ Checking skills inventory                    │
│     Has: pptx, web-design, pdf                   │
│                                                  │
│  🔍 Searching for additional skills...           │
│     Found: chart-generation (data visualization) │
│                                                  │
│  📦 Installing chart-generation skill            │
│     Ready to use for this task                   │
│                                                  │
│  📋 Planning approach                            │
│     12-slide structure following Q4 template      │
│     Will include data charts + exec summary       │
│                                                  │
│  🚀 Starting work...                             │
└──────────────────────────────────────────────────┘
```

### Why This Matters

1. **Trust** - User sees the employee is thoughtful, not just blindly executing
2. **Transparency** - User understands what tools and references are being used
3. **Intelligence signal** - "It found a new skill it needed and installed it" is impressive
4. **Feedback opportunity** - User can course-correct during planning, not after
5. **Differentiation** - No other AI product shows this level of agent introspection

### Implementation

The event bridge (`extensions/workforce/src/event-bridge.ts`) already maps agent events to task activities. We extend it to emit planning-phase events:

```typescript
// New event types for planning phase
type PlanningEvent =
  | { type: "planning:start" }
  | { type: "planning:check-references", found: string[] }
  | { type: "planning:check-skills", installed: string[] }
  | { type: "planning:skill-search", query: string }
  | { type: "planning:skill-found", skills: string[] }
  | { type: "planning:skill-install", skill: string }
  | { type: "planning:approach", plan: string }
  | { type: "planning:complete" }
```

The chat UI renders these as a collapsible "preparation" section above the task output.

---

## Part 4: The Complete Employee Model

### What Makes an Intelligent, Trainable Employee

```
Employee =
  Identity (who they are, their role)
  + Pre-installed Skills (baseline competence for their role)
  + Acquired Skills (discovered and retained from past tasks)
  + Reference Documents (user-provided examples and templates)
  + Learned Preferences (extracted from user feedback)
  + Task History (episodes of past work)
  + Capability Profile (self-model of what they can do)
```

### The Complete Task Lifecycle

```
1. RECEIVE
   Task arrives from user (possibly with attached documents)

2. PREPARE (visible to user)
   a. Load identity + capability profile
   b. Check reference documents for relevant materials
   c. Search memory for similar past tasks
   d. Evaluate skill inventory against task requirements
   e. If skill gap: search → evaluate → install new skills
   f. Generate approach plan

3. EXECUTE
   a. Work with full context (memory + skills + references)
   b. Show progress to user in real-time
   c. Use available tools and skills

4. DELIVER
   a. Present output to user (with preview)
   b. Wait for feedback

5. LEARN
   a. Extract preferences from user feedback
   b. Store task episode to memory
   c. Update capability profile (new skills, domain experience)
   d. Record skill usage for analytics
   e. Roll up learnings into MEMORY.md

6. RETAIN
   a. Decide which newly acquired skills to keep permanently
   b. Update CAPABILITIES.md
   c. Reference documents remain for future tasks
```

---

## Part 5: Design Principles

### 1. Think in Relationships, Not Files
Users don't think about folders and paths. They think:
- "I want Sarah to know about this document"
- "This belongs to the website project"
- "All my employees should know my brand voice"

**Implication:** UI should speak in terms of Projects, Employees, and "teaching" - not files and directories.

### 2. Learning from Past Work
Users primarily teach by showing examples. The document attachment is the main "teaching" mechanism.

**Implication:** Document attachment in chat must be a first-class feature. Documents need extraction, summarization, and indexing.

### 3. Context Should Be Invisible
Users shouldn't think about "context injection" or "token limits." The system should:
- Automatically pull relevant context based on task
- Summarize/compress when needed
- Never make users manually manage what gets loaded

### 4. Show the Thinking
The planning phase should be visible. Users want to see their employee preparing, thinking, and growing - not a loading spinner.

### 5. Progressive Competence
Employees should start competent (pre-installed skills) and get better over time (dynamic acquisition + feedback learning). Every task should make the employee slightly better at serving this specific user.

---

## Part 6: Implementation Phases

### Phase 1: Employee Memory (Current - In Progress)
- [x] MEMORY.md written after tasks
- [x] Episode JSON storage
- [x] Memory guidance in IDENTITY.md
- [ ] Surface memory status in UI

### Phase 2: Document Attachment
- [ ] File attachment UI in chat
- [ ] Document storage in employee workspace (references/)
- [ ] Content extraction pipeline (PPT/PDF/DOCX → text)
- [ ] Digest generation (summary for context injection)
- [ ] Reference documents injected into agent context at task time

### Phase 3: Skill System
- [ ] Pre-install skills per employee role during employee creation
- [ ] `skill_search` / `skill_install` / `skill_list` wrapper tools
- [ ] Pre-task planning phase in agent-runner.ts
- [ ] CAPABILITIES.md auto-maintained per employee
- [ ] Skill usage tracking (usage-log.jsonl)

### Phase 4: Feedback Loop
- [ ] Post-turn feedback detection hook
- [ ] Preference categorization (style, correction, approach)
- [ ] Automatic persistence to MEMORY.md preferences
- [ ] Satisfaction signal detection for skill analytics

### Phase 5: User-Visible Planning UX
- [ ] Planning phase events emitted from agent
- [ ] Event bridge extended with planning event types
- [ ] Chat UI renders preparation section
- [ ] Collapsible planning detail view

### Phase 6: Data Flywheel
- [ ] Skill usage analytics aggregation
- [ ] Per-role skill popularity tracking
- [ ] Satisfaction correlation analysis
- [ ] Auto-curation: promote high-satisfaction skills to pre-install bundles
- [ ] Dashboard for monitoring skill ecosystem health

### Future: Project Memory + User Library
- Introduce Projects as first-class entities
- Global style templates and cross-project preferences
- Smart context injection with semantic relevance scoring

---

## Relationship to OpenClaw Architecture

**OpenClaw already provides:**
- Agent workspaces: `~/.openclaw/workspace-{agentId}/`
- Bootstrap files: IDENTITY.md, MEMORY.md, BOOTSTRAP.md loaded into context
- Memory tools: `memory_search`, `memory_get` for semantic search
- Session management: per-task sessions with history
- Skills infrastructure: SKILL.md format, workspace skills, `formatSkillsForPrompt()`
- Plugin system: dynamic tool registration via factory pattern
- Event bridge: agent events mapped to task activities
- Tool policies: per-agent/channel/group tool filtering

**What we're building on top:**
- Reference document storage + digest generation
- Dynamic skill discovery via skills.sh CLI wrapper
- Pre-task planning phase with self-assessment
- Feedback extraction pipeline
- Skill usage tracking and analytics
- User-visible planning UX
- Employee capability profiles (CAPABILITIES.md)

---

## Current Problem: Cluttered Employee Workspaces

Looking at Sarah's workspace (`~/.openclaw/workspace-sarah-research/`), we found files from unrelated tasks all mixed together. This happens because there's no project separation.

**Solution:** Employee workspaces should contain:
- Identity (IDENTITY.md)
- Memory (MEMORY.md + episodes/)
- Capability profile (CAPABILITIES.md)
- Reference documents (references/)
- Installed skills (skills/)
- Skill usage data (skill-usage/)

Task outputs should live in task-scoped directories, not the employee workspace root.

---

## The Hierarchy

```
OpenClaw (Platform)
    └── User Account
        └── User Library (global assets, styles) [future]
        └── Projects [future]
        │   └── Project A
        │       ├── Documents
        │       ├── Outputs
        │       └── Assigned Employees
        └── Employees
            └── David (deck-builder)
            │   ├── Identity + Memory
            │   ├── Pre-installed Skills (pptx, web-design, pdf)
            │   ├── Acquired Skills (chart-generation, ...)
            │   ├── Reference Documents (Q4-template.pptx, brand-guide.pdf)
            │   ├── Capability Profile
            │   └── Skill Usage Analytics
            └── Sarah (research-analyst)
                └── ...
```

---

## Key Questions to Resolve

1. **Skill security:** How do we evaluate skill safety before installation? Allowlist? Sandbox?

2. **Skill scope:** Should skills install globally (all employees) or per-employee? Per-employee makes more sense for specialization.

3. **Document size limits:** How large a document can be attached? What's the extraction cost for a 100-slide PPT?

4. **Planning phase latency:** How to keep the planning phase fast (<5 seconds) while still being thorough?

5. **Feedback detection accuracy:** How reliably can we distinguish "this is feedback" from "this is a new instruction"?

6. **Skill marketplace evolution:** When do we start clawhub.ai as our own curated marketplace vs. relying on skills.sh?

---

*Document created: 2026-02-06*
*Last updated: 2026-02-06*
*Purpose: Complete architectural design for Workforce AI Employee system - memory, skills, feedback, and UX*
