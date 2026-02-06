# Workforce AI Employee Memory Architecture

## Core Insight

**The entire system is really just two things:**
1. **Memory Storage** - Where we keep different types of information at different scopes
2. **Context Injection** - Loading the right memory layers at runtime when an agent does work

The UI we build is simply friendly channels for users to add to each memory layer.

---

## The Four Memory Layers

### Layer 1: User Library (Global)
**Scope:** Transferable across all projects and employees

**What it stores:**
- Style templates ("write like this", "design in this aesthetic")
- Global contacts and reference people
- User preferences and working style
- Reusable assets (logos, brand guidelines, voice samples)

**Key characteristic:** Skills and templates that transfer regardless of project context.

**User mental model:** "My personal library of things I've learned and collected"

---

### Layer 2: Project Memory
**Scope:** Everything related to a specific project

**What it stores:**
- Project documents (briefs, specs, references)
- Previous outputs and deliverables
- Project-specific contacts and stakeholders
- History of what's been done
- Project context and goals

**Key characteristic:** Shared across all employees working on the same project.

**User mental model:** "Everything about this project lives here"

---

### Layer 3: Employee Memory
**Scope:** Individual employee's identity and learned preferences

**What it stores:**
- Employee identity and personality (IDENTITY.md)
- Learned preferences from working with user
- Skills and specialized knowledge
- Past successful approaches
- User feedback and corrections

**Key characteristic:** Persists across all tasks the employee has done.

**User mental model:** "What this employee knows about me and how I like things done"

---

### Layer 4: Task Memory (Ephemeral)
**Scope:** Single task execution

**What it stores:**
- Current task brief and requirements
- Active working files
- Task-specific context
- Intermediate outputs

**Key characteristic:** Ephemeral - valuable learnings roll up into Project or Employee memory after task completion.

**User mental model:** "The current thing we're working on right now"

---

## Context Injection Flow

When a task runs, the system injects memory in layers:

```
Task Execution Context =
    User Library (global preferences, style templates)
    + Project Memory (project docs, history, context)
    + Employee Memory (identity, learned preferences)
    + Task Memory (current brief, active files)
```

The runtime decides what to inject based on:
- Which project the task belongs to
- Which employee is assigned
- What the task needs

---

## Proposed Storage Structure

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
│   └── memory/
│       └── episodes/           # Task records
│
└── tasks/                      # Layer 4: Task Memory (ephemeral)
    └── {task-id}/
        ├── brief.md
        └── working/
```

---

## Design Principles for Non-Technical Users

### 1. Think in Relationships, Not Files
Users don't think about folders and paths. They think:
- "I want Sarah to know about this document"
- "This belongs to the website project"
- "All my employees should know my brand voice"

**Implication:** UI should speak in terms of Projects, Employees, and "teaching" - not files and directories.

### 2. Learning from Past Work
Users often want to teach AI employees by showing past work:
- "Here's a presentation I did - make similar ones"
- "Here's how I write emails - match my style"
- "Here's an example of what I want"

**Implication:** Need a clear way to add "reference examples" that become templates/style guides.

### 3. Context Should Be Invisible
Users shouldn't have to think about "context injection" or "token limits". The system should:
- Automatically pull relevant context based on task
- Summarize/compress when needed
- Never make users manually manage what gets loaded

### 4. Progressive Disclosure
- **Simple:** Assign document to employee/project
- **Advanced:** Fine-tune what context loads when
- **Power user:** Direct workspace access

---

## Implementation Phases

### Phase 1: Employee Memory (Current Focus)
- [x] MEMORY.md written after tasks
- [x] Episode JSON storage
- [x] Memory guidance in IDENTITY.md
- [ ] Surface memory status in UI

### Phase 2: Project Memory
- Introduce Projects as first-class entities
- Project document storage
- Employees assigned to Projects
- Context injection includes project context

### Phase 3: User Library
- Global style templates
- Cross-project preferences
- Brand/voice assets
- Transferable contacts

### Phase 4: Smart Context Injection
- Intelligent context selection
- Compression and summarization
- Semantic relevance scoring
- Token budget management

---

## Key Questions to Resolve

1. **Project-Employee relationship:** Can an employee belong to multiple projects? Does their memory stay unified or split?

2. **Document ownership:** If a document is added to an employee, does it also belong to their current project?

3. **Memory consolidation:** How do we roll up task learnings into employee/project memory? Automatic vs prompted?

4. **UI entry points:** Where in the chat UI do users add documents? Drag-drop? Attachment? Special command?

5. **Visibility:** How do users see what an employee "knows"? Memory browser? Summary panel?

---

## Relationship to OpenClaw Architecture

OpenClaw already provides:
- **Agent workspaces:** `~/.openclaw/workspace-{agentId}/`
- **Bootstrap files:** IDENTITY.md, MEMORY.md, BOOTSTRAP.md loaded into context
- **Memory tools:** `memory_search`, `memory_get` for semantic search
- **Session management:** Per-task sessions with history

What we're adding:
- **Projects layer:** Organization above employees
- **User Library:** Global cross-project layer
- **UI for memory management:** Friendly way to add documents
- **Smarter context injection:** Pull from multiple layers based on task

---

## Current Problem: Cluttered Employee Workspaces

Looking at Sarah's workspace (`~/.openclaw/workspace-sarah-research/`), we found files from unrelated tasks all mixed together:
- index.html (from one task)
- Various PPT files (from another)
- node_modules (from a third)
- Random scripts

This happens because there's no project separation. Every task dumps into the same employee workspace.

**Solution:** Task outputs should live in Project folders, not Employee workspaces. Employee workspaces should only contain:
- Identity (IDENTITY.md)
- Memory (MEMORY.md + episodes/)
- Possibly a `current-task/` symlink

---

## The Hierarchy

```
OpenClaw (Platform)
    └── User Account
        └── User Library (global assets, styles)
        └── Projects
            └── Project A
                ├── Documents
                ├── Outputs
                └── Assigned Employees
                    ├── Sarah (research)
                    └── David (decks)
            └── Project B
                └── ...
```

Each employee has their own persistent memory, but works within project contexts.

---

## Next Steps

1. Complete Phase 1 (Employee Memory) - currently in progress
2. Design Project entity schema and storage
3. Build UI for document attachment to employees
4. Plan context injection system that pulls from multiple layers
5. User test with non-technical users to validate mental model

---

*Document created: 2026-02-06*
*Purpose: Capture architectural discussion for Workforce AI Employee memory system*
