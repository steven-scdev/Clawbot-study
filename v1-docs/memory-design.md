# Employee Memory Architecture Design

> **Status**: Design Phase
> **Target**: Production in 2 days
> **Last Updated**: 2026-02-05

## Executive Summary

Memory is the critical component that transforms AI employees from stateless tools into human-like collaborators. This document outlines a hybrid memory architecture that combines the best patterns from SimpleMem, Mirix, Letta, mem0, and OpenClaw's existing infrastructure.

**Key Principles**:
- Local-first, cloud-ready
- Compression prevents context overflow
- Employees can learn and improve over time
- Privacy-preserving with user control

---

## Part I: The Problem

### Why Memory Matters

An AI employee without memory is like a human with amnesia — technically capable but unable to:
- Remember user preferences
- Learn from past tasks
- Build expertise over time
- Provide continuity across sessions

### Current State (OpenClaw)

```
~/.openclaw/workspace-{employeeId}/
├── IDENTITY.md      ✅ Employee mind (lens + standards + principles)
├── SOUL.md          ✅ Tone guidance
├── USER.md          ✅ User preferences (static)
├── TOOLS.md         ✅ Tool guidelines
├── MEMORY.md        ❌ EXISTS IN SCHEMA BUT NEVER WRITTEN
└── memory/          ❌ DIRECTORY NEVER CREATED
```

**The Gap**: Tasks complete, but nothing persists. Each session starts fresh.

### Scale Requirements

| Metric | Target |
|--------|--------|
| Users | Millions |
| Employees per user | 4-10 |
| Tasks per employee/day | 5-50 |
| Memory entries/employee | 100-10,000 |
| Access pattern | Phone/tablet/desktop |
| Availability | 99.9% (cloud sync) |

---

## Part II: Research Analysis

### Comparative Study

| System | Stars | Architecture | Compression | Cloud | Best Feature |
|--------|-------|--------------|-------------|-------|--------------|
| **SimpleMem** | 2.7K | 3-stage pipeline | Semantic Structured | GCS/S3/Azure | Lossless compression |
| **Mirix** | 3.5K | 6-component stores | Decay (30/90 days) | API available | Specialized memory types |
| **Letta** | 21K | Stateful blocks | Self-managing | Hosted platform | Self-improving memory |
| **mem0** | 46.6K | Multi-level | Auto-dedup | Cloud-first | Universal memory layer |
| **OpenClaw** | — | 3-tier | Summarization | Local-only | Always-on MEMORY.md |

### What We Learn From Each

#### SimpleMem: Semantic Structured Compression (SSC)

```
Raw Episode → Semantic Extraction → Structured Format → Compressed Storage
```

- 91% faster than full-context retrieval
- 43.24% F1 score on benchmarks
- Key insight: Compress semantically, not just textually

#### Mirix: Specialized Memory Stores

```
┌─────────────┬─────────────┬─────────────┐
│   Core      │  Episodic   │  Semantic   │
│  (identity) │ (events)    │ (knowledge) │
├─────────────┼─────────────┼─────────────┤
│ Procedural  │  Resource   │  Knowledge  │
│  (skills)   │  (files)    │  (facts)    │
└─────────────┴─────────────┴─────────────┘
```

- Memory decay prevents infinite growth
- Dedicated agents per memory component
- Key insight: Different memories need different handling

#### Letta: Self-Improving Memory

```python
# Agent can modify its own memory
agent.update_memory_block("persona", new_content)
agent.update_memory_block("human", user_preferences)
```

- Memory blocks the agent owns and modifies
- Enables emergence: agent learns what matters
- Key insight: Let the AI decide what to remember

#### mem0: Multi-Level Memory

```
┌─────────────────────────────────────┐
│           User Memory               │  ← Persists across all sessions
├─────────────────────────────────────┤
│         Session Memory              │  ← Current conversation
├─────────────────────────────────────┤
│          Agent Memory               │  ← Agent-specific state
└─────────────────────────────────────┘
```

- +26% accuracy vs OpenAI Memory
- 91% faster, 90% fewer tokens
- Key insight: Layer memories by scope and lifetime

---

## Part III: Hybrid Architecture

### Four-Layer Memory Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    WORKFORCE MEMORY ARCHITECTURE                         │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     LAYER 1: WORKING MEMORY                       │   │
│  │                                                                    │   │
│  │  Location: ~/.openclaw/workspace-{id}/MEMORY.md                   │   │
│  │  Size: 20K chars (≈5K tokens)                                     │   │
│  │  Lifetime: Always loaded in context                               │   │
│  │  Contents:                                                         │   │
│  │    - Current goals and active tasks                               │   │
│  │    - Recent learnings (last 5-10 tasks)                          │   │
│  │    - User preferences (frequently accessed)                       │   │
│  │    - Self-notes from the employee                                 │   │
│  │                                                                    │   │
│  │  Source: OpenClaw's existing MEMORY.md pattern                    │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     LAYER 2: EPISODIC MEMORY                      │   │
│  │                                                                    │   │
│  │  Location: ~/.openclaw/workspace-{id}/memory/episodes/            │   │
│  │  Format: JSON files per task                                      │   │
│  │  Lifetime: 30 days active, 90 days archived, then compressed      │   │
│  │  Contents:                                                         │   │
│  │    - Task ID, brief, timestamps                                   │   │
│  │    - Outputs produced                                             │   │
│  │    - Key decisions made                                           │   │
│  │    - What worked / what didn't                                    │   │
│  │    - Conversation highlights                                      │   │
│  │                                                                    │   │
│  │  Source: Mirix's episodic store + mem0's session memory           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     LAYER 3: SEMANTIC MEMORY                      │   │
│  │                                                                    │   │
│  │  Location: ~/.openclaw/workspace-{id}/memory/semantic.md          │   │
│  │  Format: Structured markdown (searchable)                         │   │
│  │  Lifetime: Persistent, self-updating                              │   │
│  │  Contents:                                                         │   │
│  │    - Accumulated expertise by domain                              │   │
│  │    - User preference patterns                                     │   │
│  │    - Learned workflows and shortcuts                              │   │
│  │    - Common pitfalls to avoid                                     │   │
│  │    - Facts and reference information                              │   │
│  │                                                                    │   │
│  │  Source: SimpleMem's SSC + Letta's self-improvement               │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                  │                                       │
│                                  ▼                                       │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                     LAYER 4: CLOUD SYNC LAYER                     │   │
│  │                                                                    │   │
│  │  Technology: Turso (libSQL) — SQLite-compatible edge database     │   │
│  │  Sync: Automatic background sync when online                      │   │
│  │  Encryption: Client-side AES-256-GCM                              │   │
│  │  Conflict: Last-write-wins with vector clock                      │   │
│  │                                                                    │   │
│  │  Source: mem0's multi-level + SimpleMem's cloud storage           │   │
│  │                                                                    │   │
│  │  DEFERRED: Implement in Phase 3 after local memory stable         │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Memory Flow

```
Task Starts
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  MEMORY RECALL (automatic, pre-task)                            │
│                                                                  │
│  1. Load MEMORY.md (Layer 1) into context                       │
│  2. Search episodic memory for relevant past tasks              │
│  3. Search semantic memory for domain knowledge                 │
│  4. Inject relevant memories into system prompt                 │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
Task Executes (employee works with memory context)
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  MEMORY CONSOLIDATION (automatic, post-task)                    │
│                                                                  │
│  1. Extract task summary and outcomes                           │
│  2. Write episode to Layer 2 (episodic memory)                  │
│  3. Update MEMORY.md with recent learnings (Layer 1)            │
│  4. Schedule semantic extraction for background processing      │
└─────────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────────┐
│  MEMORY MAINTENANCE (periodic background)                       │
│                                                                  │
│  • Compress episodes older than 30 days into semantic memory    │
│  • Archive episodes older than 90 days                          │
│  • Prune MEMORY.md to stay under 20K chars                      │
│  • Sync to cloud (when Layer 4 implemented)                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part IV: Data Structures

### Episode Record (Layer 2)

```typescript
interface Episode {
  id: string;                    // "ep-{uuid}"
  taskId: string;                // Reference to task manifest
  employeeId: string;            // "sarah-research", "emma-web", etc.

  // Task metadata
  brief: string;                 // What was requested
  startedAt: string;             // ISO timestamp
  completedAt: string;           // ISO timestamp
  status: "completed" | "failed" | "cancelled";

  // Outcomes
  outputs: Array<{
    type: string;                // "document", "website", "code", etc.
    title: string;
    path?: string;
  }>;

  // Learning extraction
  summary: string;               // 2-3 sentence summary
  keyDecisions: string[];        // Important choices made
  whatWorked: string[];          // Successful approaches
  whatDidntWork: string[];       // Things to avoid
  userFeedback?: string;         // If user provided feedback

  // Retrieval metadata
  tags: string[];                // For filtering
  embedding?: number[];          // For semantic search (computed async)
}
```

### Semantic Memory Structure (Layer 3)

```markdown
# Semantic Memory: {Employee Name}

## User Preferences
- Prefers concise responses over detailed explanations
- Uses dark mode in all applications
- Timezone: PST (UTC-8)

## Domain Expertise

### Web Development
- User's stack: Next.js, TypeScript, Tailwind CSS
- Deployment: Vercel
- Testing: Vitest + Playwright

### Research
- Preferred sources: Academic papers, official docs
- Citation style: APA
- Always verify with primary sources

## Learned Workflows
- When creating components, always add TypeScript types first
- User prefers mobile-first responsive design
- Always run tests before marking task complete

## Common Pitfalls
- Don't use `any` type — user is strict about TypeScript
- Avoid inline styles — always use Tailwind classes
- Never commit without running lint

## Facts & References
- Company name: Acme Corp
- Product name: WidgetPro
- Main repository: github.com/acme/widgetpro
```

### Working Memory Template (Layer 1 — MEMORY.md)

```markdown
# Memory: {Employee Name}

## Current State
- Last active: {timestamp}
- Active goals: {if any ongoing work}

## Recent Tasks (Last 5)

### Task: Create landing page hero section
- Completed: 2026-02-04
- Outcome: Success — user approved design
- Learned: User prefers gradient backgrounds over solid colors

### Task: Research competitor pricing
- Completed: 2026-02-03
- Outcome: Success — compiled pricing matrix
- Learned: Include screenshots with research reports

## Quick Notes
- User mentioned they're preparing for a product launch next week
- Prefer early morning availability (9am-12pm PST)

## Self-Reminders
- Review semantic memory monthly for accuracy
- Ask for feedback on complex tasks
```

---

## Part V: Implementation

### Memory Tools for Employees

```typescript
// Tools available to employees during task execution

interface MemoryTools {
  // Write to working memory (MEMORY.md)
  memory_note(content: string): Promise<void>;

  // Search past experiences
  memory_search(query: string, options?: {
    layers?: ("episodic" | "semantic")[];
    limit?: number;
    dateRange?: { from: string; to: string };
  }): Promise<MemorySearchResult[]>;

  // Update semantic memory (self-improvement)
  memory_learn(category: string, content: string): Promise<void>;

  // Explicit forget (GDPR compliance)
  memory_forget(pattern: string): Promise<{ deleted: number }>;
}
```

### Integration Points

#### 1. Post-Task Consolidation (event-bridge.ts)

```typescript
// When task completes, extract and store memory
api.on("agent_end", async (_event, ctx) => {
  const task = getTaskBySessionKey(ctx.sessionKey);
  if (!task || task.status !== "completed") return;

  // Create episode record
  const episode = await extractEpisode(task);
  await writeEpisode(task.employeeId, episode);

  // Update working memory
  await updateWorkingMemory(task.employeeId, {
    lastTask: {
      brief: task.brief,
      completedAt: task.completedAt,
      summary: episode.summary,
    }
  });
});
```

#### 2. Pre-Task Memory Recall (system-prompt injection)

```typescript
// In agent-workspaces.ts or system-prompt composition
function buildMemoryContext(employeeId: string, taskBrief: string): string {
  // 1. Load MEMORY.md (always)
  const workingMemory = readWorkingMemory(employeeId);

  // 2. Search relevant episodes
  const relevantEpisodes = searchEpisodes(employeeId, taskBrief, { limit: 3 });

  // 3. Search semantic memory
  const relevantKnowledge = searchSemantic(employeeId, taskBrief, { limit: 5 });

  return formatMemoryContext(workingMemory, relevantEpisodes, relevantKnowledge);
}
```

#### 3. Memory Maintenance (background scheduler)

```typescript
// Run periodically (e.g., daily at 3am local time)
async function runMemoryMaintenance(employeeId: string) {
  // Compress old episodes into semantic memory
  const oldEpisodes = await getEpisodesOlderThan(employeeId, 30);
  for (const episode of oldEpisodes) {
    await compressToSemantic(employeeId, episode);
    await archiveEpisode(employeeId, episode.id);
  }

  // Prune working memory if over limit
  await pruneWorkingMemory(employeeId, MAX_WORKING_MEMORY_CHARS);

  // Delete episodes older than 90 days (keep semantic extractions)
  await deleteArchivedEpisodesOlderThan(employeeId, 90);
}
```

---

## Part VI: Phased Rollout

### Phase 1: Foundation (Day 1-2) ← PRODUCTION TARGET

**Scope**: Basic memory that persists across sessions

| Component | Priority | Effort |
|-----------|----------|--------|
| Write episodes on task completion | P0 | 2h |
| Load MEMORY.md into context | P0 | Already done |
| Update MEMORY.md with recent task | P0 | 2h |
| memory_note tool for employees | P1 | 2h |
| memory_search tool (basic) | P1 | 3h |

**Success Criteria**:
- Employee remembers last 5 completed tasks
- User can ask "what did we work on yesterday?" and get answer
- No manual memory management required

### Phase 2: Intelligence (Week 2)

**Scope**: Semantic extraction and smart retrieval

| Component | Priority | Effort |
|-----------|----------|--------|
| Episode → Semantic compression | P0 | 4h |
| Hybrid search (vector + BM25) | P0 | 4h |
| memory_learn tool | P1 | 2h |
| Memory decay scheduler | P1 | 2h |
| Working memory auto-pruning | P1 | 2h |

**Success Criteria**:
- Employee builds expertise over time
- Retrieval returns relevant context 80%+ of time
- Memory stays bounded (no infinite growth)

### Phase 3: Cloud Sync (Week 3-4)

**Scope**: Multi-device access

| Component | Priority | Effort |
|-----------|----------|--------|
| Turso integration | P0 | 8h |
| Sync protocol | P0 | 6h |
| Client-side encryption | P0 | 4h |
| Conflict resolution | P1 | 4h |
| Mobile SDK hooks | P1 | 4h |

**Success Criteria**:
- Memory syncs across devices in <5s
- Works offline with eventual consistency
- User can access employee from phone

### Phase 4: Emergence (Month 2+)

**Scope**: Self-improving employees

| Component | Priority | Effort |
|-----------|----------|--------|
| Self-modification of semantic memory | P1 | 6h |
| Cross-employee knowledge sharing | P2 | 8h |
| Proactive memory retrieval | P2 | 6h |
| Memory analytics dashboard | P2 | 4h |

---

## Part VII: Storage Recommendation

### Why Turso (libSQL)

| Requirement | Turso Solution |
|-------------|----------------|
| SQLite-compatible | ✅ Drop-in replacement, existing code works |
| Local-first | ✅ Embedded mode for offline |
| Cloud sync | ✅ Built-in replication to edge |
| Global scale | ✅ 30+ edge locations |
| Vector search | ✅ Via sqlite-vec extension |
| Cost | ✅ Free tier: 9GB storage, 1B reads/month |

### Alternative Options

| Option | When to Choose |
|--------|----------------|
| **Supabase** | If already using Postgres, need realtime subscriptions |
| **Cloudflare D1** | If heavily invested in Cloudflare ecosystem |
| **PlanetScale** | If need MySQL compatibility |
| **Self-hosted Postgres** | If data sovereignty is critical |

---

## Part VIII: Privacy & Security

### Data Classification

| Data Type | Sensitivity | Encryption | Retention |
|-----------|-------------|------------|-----------|
| Working memory | Medium | At-rest | Indefinite |
| Episodes | High | At-rest + in-transit | 90 days |
| Semantic memory | Medium | At-rest | Indefinite |
| Embeddings | Low | None | With source |

### User Controls

```typescript
// Available via UI or API
interface MemoryControls {
  // View what employee remembers
  viewMemory(employeeId: string): Promise<MemorySnapshot>;

  // Delete specific memories
  forgetTask(taskId: string): Promise<void>;
  forgetDateRange(from: Date, to: Date): Promise<void>;
  forgetAll(employeeId: string): Promise<void>;

  // Export for portability
  exportMemory(employeeId: string): Promise<MemoryExport>;

  // Import from backup
  importMemory(employeeId: string, data: MemoryExport): Promise<void>;
}
```

### GDPR Compliance

- Right to access: `viewMemory()` + `exportMemory()`
- Right to erasure: `forgetAll()` with cascade delete
- Right to portability: `exportMemory()` in standard JSON format
- Data minimization: Auto-delete after 90 days

---

## Part IX: Metrics & Monitoring

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Memory recall accuracy | >80% | User satisfaction surveys |
| Retrieval latency | <200ms | P95 response time |
| Storage per employee | <10MB | Average after 30 days |
| Context utilization | <80% | Tokens used vs available |
| Compression ratio | >5:1 | Episodes vs semantic |

### Monitoring Points

```typescript
// Emit metrics on key operations
metrics.increment("memory.episode.created", { employeeId });
metrics.timing("memory.search.latency", duration, { layer });
metrics.gauge("memory.storage.bytes", size, { employeeId });
metrics.increment("memory.compression.run", { episodeCount });
```

---

## Appendix A: File Structure

```
~/.openclaw/workspace-{employeeId}/
├── IDENTITY.md              # Employee mind (existing)
├── SOUL.md                  # Tone (existing)
├── USER.md                  # User prefs (existing)
├── TOOLS.md                 # Tool guidance (existing)
├── MEMORY.md                # Layer 1: Working memory (NEW)
└── memory/                  # (NEW directory)
    ├── episodes/            # Layer 2: Episodic memory
    │   ├── ep-abc123.json
    │   ├── ep-def456.json
    │   └── ...
    ├── semantic.md          # Layer 3: Semantic memory
    └── archive/             # Compressed old episodes
        └── 2026-01.json.gz
```

## Appendix B: Episode Extraction Prompt

```
Given the following completed task, extract a memory episode:

Task Brief: {task.brief}
Started: {task.createdAt}
Completed: {task.completedAt}
Status: {task.status}
Outputs: {task.outputs}

Conversation highlights:
{relevantMessages}

Extract:
1. A 2-3 sentence summary
2. Key decisions made (list)
3. What worked well (list)
4. What didn't work or to avoid (list)
5. Relevant tags for future retrieval

Format as JSON matching the Episode interface.
```

## Appendix C: References

- SimpleMem: https://github.com/aiming-lab/SimpleMem
- Mirix: https://github.com/Mirix-AI/MIRIX
- Letta: https://github.com/letta-ai/letta
- mem0: https://github.com/mem0ai/mem0
- Turso: https://turso.tech
- OpenClaw memory system: `src/agents/workspace.ts`, `src/memory/`
