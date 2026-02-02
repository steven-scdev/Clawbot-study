codex
I read both docs. Here’s a Phase A ticket plan to build the macOS Workforce app on top of the current
Gateway without backend changes. Each ticket includes scope, tests, and acceptance criteria.

Assumptions

- Transport: JSON-RPC over WebSocket to ws://127.0.0.1:18789/ws?token=<token>.
- Existing Gateway methods to use: agents.list, agent (run), sessions.list, logs.tail, health.
- No new Gateway code in Phase A; Workforce RPC comes in Phase B.
- Attachments: copy to per-task folder under ~/.openclaw/workspace and reference file paths in the
message.

A1 — JSON-RPC Client

- Scope: Swift WebSocketClient.swift with:
    - Connect/reconnect with token param, heartbeat/ping, backoff.
    - call(method:params:) with id correlation and error mapping.
    - Event envelope support (ignore unknown events; Phase A uses only responses).
- Tests:
    - Unit: encode/decode request/response; id correlation; error path (-32000).
    - Integration: mock WS server echoes a request and sends a final response.
- Accept: App connects, authenticates (invalid token surfaced), and round-trips a simple call.

A2 — GatewayService

- Scope: GatewayService.swift wrapping JSON-RPC:
    - connect(token, port), disconnect(), health(), status.
    - Connection state publisher (connected, reconnecting, error).
- Tests:
    - Unit: reconnection/backoff timing; state transitions.
    - Integration: call health, observe connected state flips on server drop.
- Accept: UI shows connected/error; retries work; health returns version.

A3 — EmployeeService (Phase A binding)

- Scope: EmployeeService.swift with:
    - fetch() via agents.list (fallback: static in-app JSON if method not present).
    - Status derivation: “online” when connected; “busy” if sessions.list has recent sessions for that
agent; “offline” when disconnected.
    - Map minimal display fields (name/title/emoji/description) from config or static attribution map.
- Tests:
    - Unit: mapping and status computation (busy vs online).
    - Integration: decode agents.list real shape; combine with sessions.list.
- Accept: Gallery populates; busy indicators reflect active sessions.

A4 — Employee Gallery UI

- Scope: EmployeeGalleryView + EmployeeCardView:
    - Grid of employees, presence dot, hover details, tap to open Task Input.
- Tests:
    - UI snapshot tests for cards; interaction test triggers Task Panel.
- Accept: Gallery renders with live statuses and opens Task Input on click.

A5 — Task Model & Per‑Task Workspace

- Scope: Task.swift and simple TaskStore:
    - In-memory list with persistence stub; per-task folder under ~/.openclaw/workspace/<taskId>.
    - Attachment ingest: copy files into the task folder; pass file paths to the agent run message.
- Tests:
    - Unit: path handling, copy errors; task lifecycle transitions (queued, running, done).
- Accept: Creating a task builds its folder, attachments copied, paths visible to Output viewer.

A6 — TaskService: Submit & Track

- Scope: TaskService.swift:
    - submitTask(employeeId, description, attachments) → agent RPC with idempotencyKey, sessionKey
derived (main by agent).
    - Track accepted and final responses; map to Task status.
    - Progress: primary path=logs.tail (WS method); fallback=poll sessions.list for recent activity.
- Tests:
    - Integration: mock agent returns accepted then final; ensure state updates and idempotency.
    - Unit: logs.tail parsing and progress heuristics (line count/token-like events).
- Accept: Submitting creates a run; UI shows “accepted” then “completed/failed”; basic progress lines
appear.

A7 — Task Input UI

- Scope: TaskInputView:
    - Rich text input, employee header, attachments picker, “Assign” button.
    - Shows validation (non-empty prompt), error toast, and opens Progress on submit.
- Tests:
    - UI: validation and submit flow; attachment pick and copy.
- Accept: Can assign a task; see immediate transition to progress view.

A8 — Progress View (Logs‑based)

- Scope: TaskProgressView:
    - Shows current activity lines via logs.tail (channel “gateway” and runId filter if present; else
agent/session filter).
    - Progress heuristics: % unknown; display latest action/tool/info.
    - Minimal pause/cancel UI disabled for Phase A (stub only).
- Tests:
    - UI: append-only log stream; autoscroll behavior; empty-state handling.
- Accept: Live activity visible within a few seconds of run start; no UI freezes on reconnect.

A9 — Output Viewer (Placeholder)

- Scope: OutputViewerView:
    - Lists output paths observed in logs or returned summary (Phase A: parse “Output:” lines or tool
echo paths).
    - Open in Finder/File preview; simple image/text preview when feasible.
- Tests:
    - Unit: output path extraction; image/text preview decode.
- Accept: Outputs show as file links; clicking opens Finder/preview.

A10 — Settings Panel

- Scope: SettingsService.swift and SettingsView:
    - Token/port persistence (Keychain for token), connection test, save/restore.
    - Shared folders UI stub; no-op storage in Phase A.
- Tests:
    - Unit: persistence; connection test success/failure; invalid token message.
    - UI: save roundtrip.
- Accept: Users can set token/port, connect, and see connection health.

A11 — Error Handling & UX Polish

- Scope: Timeouts, gateway down states, invalid session key paths, attachment failures.
    - Uniform error banners; retry affordances; logger integration for diagnostics.
- Tests:
    - Unit: map gateway errors (-32600.. etc.) to user-friendly text; ensure retries bounded.
- Accept: App degrades gracefully; no silent failures; actionable messages.

A12 — E2E Manual Script (Operator)

- Scope: Document and validate the full loop against a local Gateway:
    - Start gateway: npx -y openclaw@latest gateway run --bind loopback --port 18789 --force.
    - Connect app with token; gallery shows employees.
    - Assign a task to an employee; observe logs-based progress; output files linked.
- Tests:
    - Checklist run on a clean machine; record timing and edge behavior (disconnect/reconnect).
- Accept: The script passes consistently; demo-ready flow.

A13 — Minimal Docs

- Scope: Mintlify page stubs (or README inside the app folder) with:
    - Setup, token entry, troubleshooting (invalid token, port busy), how progress works (logs.tail
fallback).
- Tests:
    - pnpm docs:build if integrating with docs; otherwise lint and content review.
- Accept: Clear onboarding steps for QA and internal users.

Verification Criteria (Phase A)

- Connects and authenticates to Gateway; handles token errors and recovers from disconnect.
- Employee gallery lists agents and reflects “busy” via sessions.list.
- Task submit triggers agent RPC; accepted → final lifecycle visible; retries idempotent.
- Progress view shows rolling activity via logs.tail; no UI hangs during reconnects.
- Outputs render as file links; double-click opens Finder/preview.
- Settings persist token/port and report connection status.

Tech Notes

- agent RPC flow: first response “accepted” with runId; final response “ok” or “error”. No token
streaming from Gateway; use logs.tail and sessions.list as per spec.
- sessions.list filtering: derive agent’s main session key, then filter recent entries to mark “busy”.
- Attachments: copy into ~/.openclaw/workspace/<taskId>/attachments/* for stable references; include
paths in the prompt for Phase A.
- Security: keep token only in Keychain; never log full token; show masked in UI.
