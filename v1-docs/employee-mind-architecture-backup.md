 Plan: Employee Mind Architecture — Thesis & Implementation Document

     Goal

     Create one comprehensive document in v1-docs/employee-mind-architecture.md that captures:

     1. The hypothesis we're betting on (top-down, from first principles)
     2. The principles we draw from (biology, Kevin Kelly's emergence theory)
     3. The architecture that connects hypothesis to implementation
     4. The exact technical implementation on the current codebase
     5. The minimum experiment to validate the hypothesis
     6. The scaling path if the experiment succeeds

     Audience: Engineers and PMs who were not part of the design conversation. They need to
     understand the WHY (hypothesis, principles), the WHAT (architecture), and the HOW (code
     changes, testing).

     ---
     Document Structure

     Part I: The Hypothesis (~400 words)

     The bet: A "minimal viable mind" (lens + standards + principles + memory) combined with
     OpenClaw's general-purpose agentic runtime produces emergent specialized employee behavior —
     without hard-coded workflows, scripted procedures, or complex engineering.

     - What we believe
     - What we're NOT building (and why)
     - The falsifiable claim: same task given to an agent with a mind vs. without produces
     measurably better, more specialized output

     Part II: Where the Hypothesis Comes From (~600 words)

     Biological cognition parallel:
     - Shared brain hardware (prefrontal cortex, motor cortex, etc.) = OpenClaw runtime
     - Specialized learned knowledge = Employee mind
     - Three types of knowledge: semantic (expertise), procedural (skills), episodic (experience)
     - Mapping table: brain region → OpenClaw capability

     Kevin Kelly's "Out of Control" — emergence principles:
     - "Grow, don't build" — seeds, not trees
     - Swarm logic — simple rules → complex behavior
     - Co-evolution — employee and user adapt to each other
     - Bottom-up control — behavior emerges from principles, not scripts

     Engineering implications from biology:
     1. Fuse, don't append — expertise shapes perception (load lens BEFORE task brief)
     2. Consolidate, don't accumulate — synthesize feedback into patterns (like sleep)
     3. Separate stable from fluid — three storage tiers with different lifecycles

     Part III: The Architecture (~500 words)

     Two-layer model:
     - OpenClaw Agentic Runtime = shared capability layer (reasoning, tool use, execution, language
      adaptation)
     - Employee Mind = per-employee differentiation layer

     Mind structure (the four elements):
     ┌────────────┬────────────────────────────────┬───────────────────────────────────────┬───────
     ──────┐
     │  Element   │           Bio Analog           │                Content                │
     Scale     │
     ├────────────┼────────────────────────────────┼───────────────────────────────────────┼───────
     ──────┤
     │ Lens       │ Semantic memory (trained       │ How they see problems in their domain │ ~500
     words   │
     │            │ perception)                    │                                       │
           │
     ├────────────┼────────────────────────────────┼───────────────────────────────────────┼───────
     ──────┤
     │ Standards  │ Taste / quality instinct       │ What "good" means in their domain     │ ~200
     words   │
     ├────────────┼────────────────────────────────┼───────────────────────────────────────┼───────
     ──────┤
     │ Principles │ Judgment / character           │ Decision rules, communication style,  │ ~300
     words   │
     │            │                                │ autonomy                              │
           │
     ├────────────┼────────────────────────────────┼───────────────────────────────────────┼───────
     ──────┤
     │ Memory     │ Episodic memory                │ User preferences, feedback, business  │ Grows
     over   │
     │            │                                │ context                               │ time
           │
     └────────────┴────────────────────────────────┴───────────────────────────────────────┴───────
     ──────┘



     System prompt composition order (perception-first):
     1. Identity + Lens → shapes how agent perceives incoming task
     2. Standards → defines quality expectations
     3. Principles → calibrates judgment and communication
     4. Memory (consolidated) → adds user-specific context
     5. Task brief → interpreted through all of the above

     Memory lifecycle:
     - Raw: stored after each task (full episodic record)
     - Consolidated: synthesized periodically (distilled patterns injected into prompt)
     - Promoted: strong patterns that become part of core expertise (rare)

     Part IV: Technical Implementation (~1200 words)

     Current state (what exists today):
     - EmployeeConfig type: 8 display-only fields, NO system prompt, NO tools, NO behavior
     (employees.ts:3-12)
     - before_agent_start hook: only updates task status, does NOT inject any employee context
     (index.ts:300-312)
     - agentId field: exists on every employee but is never consumed by agent runtime
     - Every employee runs the identical generic agent — no differentiation

     Three injection points discovered in OpenClaw:
     1. before_agent_start hook → return prependContext string to inject into system prompt
     (src/plugins/hooks.ts, consumed at src/agents/pi-embedded-runner/run/attempt.ts:710-726)
     2. Plugin skill directories → register in openclaw.plugin.json, loaded at
     src/agents/skills/workspace.ts:130-134
     3. SOUL.md pattern → built-in workspace file for persona injection
     (src/agents/system-prompt.ts:543-546): "embody its persona and tone"

     What to modify:
     File: extensions/workforce/src/employees.ts
     Change: Expand EmployeeConfig with mind field containing lens, standards, principles
     ────────────────────────────────────────
     File: extensions/workforce/index.ts:300-312
     Change: Modify before_agent_start hook to compose and inject employee mind via prependContext
     ────────────────────────────────────────
     File: extensions/workforce/src/minds/
     Change: NEW directory — mind files for each default employee
     ────────────────────────────────────────
     File: extensions/workforce/src/mind-composer.ts
     Change: NEW — reads mind files + memory, composes system prompt section
     ────────────────────────────────────────
     File: extensions/workforce/src/memory-store.ts
     Change: NEW — persistent memory per employee-user pair at ~/.openclaw/workforce/memory/
     The Mind Composer (the critical new component):
     composeMind(employeeId, sessionKey) → string
       1. Load employee mind files (lens.md, standards.md, principles.md)
       2. Load consolidated memory for this user (if exists)
       3. Compose into single prepend string with clear sections
       4. Return for injection via prependContext

     The before_agent_start hook change (the smallest code change with the largest impact):
     Current (index.ts:300-312):
       - Checks sessionKey prefix
       - Updates task status → running
       - Broadcasts stage event

     New:
       - Same checks
       - Same status update
       - ALSO: calls composeMind(employeeId)
       - Returns { prependContext: composedMind }

     Part V: The Minimum Experiment (~400 words)

     What we test: Give Emma a mind. Run the same task with and without the mind. Compare.

     Setup:
     1. Write Emma's mind files (lens.md ~500 words, standards.md ~200 words, principles.md ~300
     words)
     2. Modify before_agent_start to inject Emma's mind via prependContext
     3. Run identical task: "Build me a landing page for a productivity app"

     Control: Current behavior (no mind, generic agent)
     Treatment: Emma with mind injected

     What to measure (qualitative assessment by the team):
     - Does Emma ask different/better clarification questions?
     - Does she approach the task with visible design thinking?
     - Does the output quality differ?
     - Does her communication feel more like a specialist?
     - Does she self-review before delivering?

     Success criteria:
     - Noticeable qualitative difference in at least 3 of 5 dimensions
     - No regression in task completion (still produces working output)
     - System prompt injection works cleanly (no errors, no prompt conflicts)

     What we learn regardless of outcome:
     - If it works: scale to David, Sarah, and the memory system
     - If the mind is too vague: make principles more specific
     - If the mind is too rigid: make principles more abstract
     - If prompt injection causes issues: investigate alternative injection points

     Part VI: Scaling Path (~300 words)

     If the experiment succeeds (Phase 2+):
     Phase: Phase 1 (experiment)
     What: Emma's mind + prompt injection
     Builds On: Current codebase, no new infra
     ────────────────────────────────────────
     Phase: Phase 2
     What: All three employee minds
     Builds On: Phase 1 pattern, replicate for David + Sarah
     ────────────────────────────────────────
     Phase: Phase 3
     What: Memory store
     Builds On: JSON files at ~/.openclaw/workforce/memory/, injected into prompt
     ────────────────────────────────────────
     Phase: Phase 4
     What: Memory consolidation
     Builds On: Periodic LLM call to synthesize raw feedback into patterns
     ────────────────────────────────────────
     Phase: Phase 5
     What: Employee-specific skills
     Builds On: Plugin skill directories per employee type
     ────────────────────────────────────────
     Phase: Phase 6
     What: Custom employee creation
     Builds On: User describes role → system generates initial mind
     ────────────────────────────────────────
     Phase: Phase 7
     What: Dedicated database
     Builds On: Migrate from JSON files to SQLite/Postgres for memory at scale
     Infrastructure grows with validation — each phase only built after the previous phase proves
     the hypothesis at that scale.

     Appendix: Reference Material

     - Emma's mind content (the actual lens, standards, principles text)
     - David's mind content
     - Sarah's mind content
     - Memory store schema
     - Consolidation prompt template

     ---
     Key Files to Reference
     File: EmployeeConfig
     Path: extensions/workforce/src/employees.ts
     Relevant Lines: 3-12
     Purpose: Type to expand
     ────────────────────────────────────────
     File: Default employees
     Path: extensions/workforce/src/employees.ts
     Relevant Lines: 15-43
     Purpose: Emma, David, Sarah definitions
     ────────────────────────────────────────
     File: before_agent_start
     Path: extensions/workforce/index.ts
     Relevant Lines: 300-312
     Purpose: Hook to modify
     ────────────────────────────────────────
     File: Hook system
     Path: src/plugins/hooks.ts
     Relevant Lines: 185-201
     Purpose: How hooks return prependContext
     ────────────────────────────────────────
     File: Hook consumption
     Path: src/agents/pi-embedded-runner/run/attempt.ts
     Relevant Lines: 710-726
     Purpose: Where prependContext is injected
     ────────────────────────────────────────
     File: SOUL.md pattern
     Path: src/agents/system-prompt.ts
     Relevant Lines: 543-546
     Purpose: Existing persona injection
     ────────────────────────────────────────
     File: Skills loading
     Path: src/agents/skills/workspace.ts
     Relevant Lines: 130-134
     Purpose: Plugin skill directories
     ────────────────────────────────────────
     File: Plugin skills
     Path: src/agents/skills/plugin-skills.ts
     Relevant Lines: 14-74
     Purpose: How plugins register skills
     ────────────────────────────────────────
     File: Task store
     Path: extensions/workforce/src/task-store.ts
     Relevant Lines: 22-37, 39
     Purpose: TaskManifest, storage path
     ────────────────────────────────────────
     File: Event bridge
     Path: extensions/workforce/src/event-bridge.ts
     Relevant Lines: 23-114
     Purpose: Agent event routing
     Execution Plan

     1. Write the document to v1-docs/employee-mind-architecture.md
     2. Include ALL sections (Part I through Part VI + Appendix with actual mind content)
     3. Include the actual Emma/David/Sarah mind text as appendix (not just placeholders)
     4. Reference exact file paths and line numbers from the codebase
     5. Verify swift build still passes (documentation only, no code changes)
