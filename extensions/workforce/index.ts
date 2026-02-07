import { resolveEmployees, buildEmployeeList, type EmployeeConfig } from "./src/employees.js";
import {
  newTaskManifest,
  createTask,
  getTask,
  updateTask,
  listTasks,
  getTaskBySessionKey,
  type TaskManifest,
} from "./src/task-store.js";
import { handleAgentEvent, appendOutput, createFileOutput, createUrlOutput } from "./src/event-bridge.js";
import { setupAgentWorkspaces } from "./src/agent-workspaces.js";
import { buildWorkforceSessionKey, isWorkforceSession } from "./src/session-keys.js";
import { writeTaskEpisode, updateEmployeeMemory } from "./src/memory-writer.js";
import {
  addReference,
  listReferences,
  removeReference,
  formatReferencesForPrompt,
} from "./src/reference-store.js";
import { skillSearch, skillInstall, skillList } from "./src/skill-tools.js";
import {
  startEmbeddedBrowser,
  stopEmbeddedBrowser,
  dispatchMouseEvent,
  dispatchKeyEvent,
  getEmbeddedSession,
  setEmbeddedBroadcast,
  captureScreenshot,
  evaluateScript,
  getPageInfo,
} from "./src/embedded-browser.js";
import { fileURLToPath } from "url";

type GatewayMethodOpts = {
  params: Record<string, unknown>;
  respond: (ok: boolean, payload?: unknown) => void;
  context: { broadcast: (event: string, payload: unknown) => void };
};

type PluginApi = {
  pluginConfig?: unknown;
  logger: { info: (msg: string) => void; error: (msg: string) => void; warn: (msg: string) => void };
  registerGatewayMethod: (method: string, handler: (opts: GatewayMethodOpts) => Promise<void> | void) => void;
  on: (hook: string, handler: (event: Record<string, unknown>, ctx: Record<string, unknown>) => Promise<unknown> | unknown) => void;
};

// Store broadcast on globalThis so it survives plugin re-registration.
// When the agent session starts, the plugin is re-loaded with a fresh closure,
// losing the closure-scoped cachedBroadcast. globalThis persists across re-loads
// within the same Node process.
const BROADCAST_KEY = Symbol.for("workforce.broadcast");
const PENDING_BROWSER_REQUESTS_KEY = Symbol.for("workforce.browser.pendingRequests");

type PendingBrowserRequest = {
  resolve: (result: unknown) => void;
  reject: (error: Error) => void;
  timeout: ReturnType<typeof setTimeout>;
};

function getSharedBroadcast(): ((event: string, payload: unknown) => void) | null {
  return (globalThis as Record<symbol, unknown>)[BROADCAST_KEY] as ((event: string, payload: unknown) => void) | null ?? null;
}

function setSharedBroadcast(broadcast: (event: string, payload: unknown) => void): void {
  (globalThis as Record<symbol, unknown>)[BROADCAST_KEY] = broadcast;
  // Also update the embedded browser module's broadcast reference
  setEmbeddedBroadcast(broadcast);
}

function getPendingBrowserRequests(): Map<string, PendingBrowserRequest> {
  const globalMap = globalThis as Record<symbol, unknown>;
  if (!globalMap[PENDING_BROWSER_REQUESTS_KEY]) {
    globalMap[PENDING_BROWSER_REQUESTS_KEY] = new Map<string, PendingBrowserRequest>();
  }
  return globalMap[PENDING_BROWSER_REQUESTS_KEY] as Map<string, PendingBrowserRequest>;
}

/** Convert internal TaskManifest to the wire shape consumed by the Swift frontend. */
function taskToWire(t: TaskManifest) {
  return {
    id: t.id,
    employeeId: t.employeeId,
    description: t.brief,
    status: t.status,
    stage: t.stage,
    progress: t.progress,
    sessionKey: t.sessionKey,
    createdAt: t.createdAt,
    completedAt: t.completedAt ?? null,
    errorMessage: t.errorMessage ?? null,
    activities: t.activities,
    outputs: t.outputs,
  };
}

function parseConfig(value: unknown): { employees: EmployeeConfig[] } {
  const raw =
    value && typeof value === "object" && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {};
  return { employees: resolveEmployees(raw) };
}

const workforcePlugin = {
  id: "workforce",
  name: "Workforce",
  description: "AI employee management: task creation, employee roster, and structured task lifecycle",

  register(api: PluginApi) {
    const config = parseConfig(api.pluginConfig);
    const mindsDir = fileURLToPath(new URL("./minds", import.meta.url));
    api.logger.info(`[workforce] Registered with ${config.employees.length} employees`);

    // Write IDENTITY.md to each employee's agent workspace directory.
    // Fire-and-forget: safe because task creation is user-initiated and happens later.
    setupAgentWorkspaces(config.employees, mindsDir, api.logger).catch((err) => {
      api.logger.error(`[workforce] Failed to set up agent workspaces: ${err}`);
    });

    // ── workforce.employees.list ────────────────────────────────
    api.registerGatewayMethod("workforce.employees.list", async ({ respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        const employees = buildEmployeeList(config.employees);
        respond(true, { employees });
      } catch (err) {
        api.logger.error(`[workforce] employees.list failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.tasks.create ──────────────────────────────────
    api.registerGatewayMethod("workforce.tasks.create", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        const employeeId = requireString(params, "employeeId");
        const brief = requireString(params, "brief");
        const attachments = (params.attachments as string[] | undefined) ?? [];

        const employee = config.employees.find((e) => e.id === employeeId);
        if (!employee) {
          respond(false, { error: `Unknown employee: ${employeeId}` });
          return;
        }

        // Store attachments as references so the agent can find them
        const storedRefs: string[] = [];
        for (const filePath of attachments) {
          try {
            const doc = addReference(employeeId, filePath, { type: "reference" });
            storedRefs.push(`- ${doc.originalName} → references/originals/${doc.id}${doc.originalName.slice(doc.originalName.lastIndexOf("."))}`);
          } catch (refErr) {
            api.logger.warn(`[workforce] Failed to store attachment as reference: ${refErr}`);
          }
        }

        // Append reference file paths to brief so the agent knows what was attached
        let enrichedBrief = brief;
        if (storedRefs.length > 0) {
          enrichedBrief += `\n\n## Attached Files\nThe user attached these files for you to use as references:\n${storedRefs.join("\n")}\n\nIMPORTANT: Use these attached files as your primary reference — read them from the paths above. Do NOT use other files from past tasks unless specifically relevant.`;
        }

        const sessionKey = buildWorkforceSessionKey(employeeId);
        const manifest = newTaskManifest({ employeeId, brief: enrichedBrief, sessionKey, attachments });
        createTask(manifest);

        // Broadcast employee status change
        context.broadcast("workforce.employee.status", {
          employeeId,
          status: "busy",
          currentTaskId: manifest.id,
        });

        api.logger.info(`[workforce] Task created: ${manifest.id} for ${employeeId}`);
        respond(true, { task: taskToWire(manifest) });
      } catch (err) {
        api.logger.error(`[workforce] tasks.create failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.tasks.clarify ─────────────────────────────────
    api.registerGatewayMethod("workforce.tasks.clarify", async ({ params, respond }) => {
      try {
        const taskId = requireString(params, "taskId");
        const answers = params.answers as Array<{ questionId: string; value: string }> | undefined;
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        // Append answers to brief context and advance to plan stage
        if (answers?.length) {
          const clarificationText = answers.map((a) => `${a.questionId}: ${a.value}`).join("\n");
          updateTask(taskId, {
            brief: `${task.brief}\n\n## Clarifications\n${clarificationText}`,
            stage: "plan",
          });
        } else {
          updateTask(taskId, { stage: "plan" });
        }
        const updated = getTask(taskId)!;
        respond(true, { task: taskToWire(updated) });
      } catch (err) {
        api.logger.error(`[workforce] tasks.clarify failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.tasks.approve ─────────────────────────────────
    api.registerGatewayMethod("workforce.tasks.approve", async ({ params, respond }) => {
      try {
        const taskId = requireString(params, "taskId");
        const approved = params.approved as boolean;
        const feedback = params.feedback as string | undefined;
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        if (approved) {
          updateTask(taskId, { stage: "execute", status: "running" });
        } else if (feedback) {
          // Append feedback and keep in plan stage for re-planning
          updateTask(taskId, {
            brief: `${task.brief}\n\n## Plan Feedback\n${feedback}`,
          });
        }
        const updated = getTask(taskId)!;
        respond(true, { task: taskToWire(updated) });
      } catch (err) {
        api.logger.error(`[workforce] tasks.approve failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.tasks.list ────────────────────────────────────
    api.registerGatewayMethod("workforce.tasks.list", async ({ params, respond }) => {
      try {
        const limit = (params.limit as number | undefined) ?? 50;
        const offset = (params.offset as number | undefined) ?? 0;
        const status = params.status as string[] | undefined;
        const result = listTasks({ limit, offset, status });
        respond(true, {
          tasks: result.tasks.map(taskToWire),
          total: result.total,
          hasMore: offset + limit < result.total,
        });
      } catch (err) {
        api.logger.error(`[workforce] tasks.list failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.tasks.get ─────────────────────────────────────
    api.registerGatewayMethod("workforce.tasks.get", async ({ params, respond }) => {
      try {
        const taskId = requireString(params, "taskId");
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        respond(true, { task: taskToWire(task) });
      } catch (err) {
        api.logger.error(`[workforce] tasks.get failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.tasks.cancel ──────────────────────────────────
    api.registerGatewayMethod("workforce.tasks.cancel", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        const taskId = requireString(params, "taskId");
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        updateTask(taskId, { status: "cancelled", completedAt: new Date().toISOString() });

        // Write memory for cancelled task
        const cancelledTask = getTask(taskId);
        if (cancelledTask) {
          try {
            writeTaskEpisode(cancelledTask);
            updateEmployeeMemory(cancelledTask);
            api.logger.info(`[workforce] Memory updated for cancelled task: ${taskId}`);
          } catch (err) {
            api.logger.warn(`[workforce] Failed to update memory for cancelled task: ${err}`);
          }
        }

        context.broadcast("workforce.employee.status", {
          employeeId: task.employeeId,
          status: "online",
          currentTaskId: null,
        });
        const updated = getTask(taskId)!;
        respond(true, { task: taskToWire(updated) });
      } catch (err) {
        api.logger.error(`[workforce] tasks.cancel failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.tasks.revise ──────────────────────────────────
    api.registerGatewayMethod("workforce.tasks.revise", async ({ params, respond }) => {
      try {
        const taskId = requireString(params, "taskId");
        const feedback = requireString(params, "feedback");
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        updateTask(taskId, {
          brief: `${task.brief}\n\n## Revision Request\n${feedback}`,
          status: "running",
          stage: "execute",
          completedAt: undefined,
          errorMessage: undefined,
        });
        const updated = getTask(taskId)!;
        api.logger.info(`[workforce] Task revision: ${taskId}`);
        respond(true, { task: taskToWire(updated) });
      } catch (err) {
        api.logger.error(`[workforce] tasks.revise failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.outputs.open ──────────────────────────────────
    api.registerGatewayMethod("workforce.outputs.open", async ({ params, respond }) => {
      try {
        const outputId = requireString(params, "outputId");
        const taskId = requireString(params, "taskId");
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        const output = task.outputs.find((o) => o.id === outputId);
        if (!output) {
          respond(false, { error: `Output not found: ${outputId}` });
          return;
        }
        const target = output.url ?? output.filePath;
        if (target) {
          const { execSync } = await import("node:child_process");
          execSync(`open ${JSON.stringify(target)}`);
        }
        respond(true, { success: true });
      } catch (err) {
        api.logger.error(`[workforce] outputs.open failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.outputs.reveal ────────────────────────────────
    api.registerGatewayMethod("workforce.outputs.reveal", async ({ params, respond }) => {
      try {
        const outputId = requireString(params, "outputId");
        const taskId = requireString(params, "taskId");
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        const output = task.outputs.find((o) => o.id === outputId);
        if (!output?.filePath) {
          respond(false, { error: `No file path for output: ${outputId}` });
          return;
        }
        const { execSync } = await import("node:child_process");
        execSync(`open -R ${JSON.stringify(output.filePath)}`);
        respond(true, { success: true });
      } catch (err) {
        api.logger.error(`[workforce] outputs.reveal failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.references.add ───────────────────────────────────
    api.registerGatewayMethod("workforce.references.add", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        const employeeId = requireString(params, "employeeId");
        const filePath = requireString(params, "filePath");
        const type = params.type as string | undefined;
        const tags = params.tags as string[] | undefined;

        const doc = addReference(employeeId, filePath, {
          type: type as "template" | "example" | "style-guide" | "reference" | undefined,
          tags,
        });

        context.broadcast("workforce.reference.added", {
          employeeId,
          reference: doc,
        });

        api.logger.info(`[workforce] Reference added: ${doc.id} for ${employeeId}`);
        respond(true, { reference: doc });
      } catch (err) {
        api.logger.error(`[workforce] references.add failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.references.list ──────────────────────────────────
    api.registerGatewayMethod("workforce.references.list", async ({ params, respond }) => {
      try {
        const employeeId = requireString(params, "employeeId");
        const references = listReferences(employeeId);
        respond(true, { references });
      } catch (err) {
        api.logger.error(`[workforce] references.list failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.references.remove ────────────────────────────────
    api.registerGatewayMethod("workforce.references.remove", async ({ params, respond }) => {
      try {
        const employeeId = requireString(params, "employeeId");
        const refId = requireString(params, "refId");
        const removed = removeReference(employeeId, refId);
        if (!removed) {
          respond(false, { error: `Reference not found: ${refId}` });
          return;
        }
        api.logger.info(`[workforce] Reference removed: ${refId} for ${employeeId}`);
        respond(true, { removed: true });
      } catch (err) {
        api.logger.error(`[workforce] references.remove failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.skills.search ────────────────────────────────────
    api.registerGatewayMethod("workforce.skills.search", async ({ params, respond }) => {
      try {
        const employeeId = requireString(params, "employeeId");
        const query = requireString(params, "query");
        const taskId = params.taskId as string | undefined;

        const results = skillSearch(
          { employeeId, taskId, logger: api.logger },
          query,
        );

        respond(true, { results });
      } catch (err) {
        api.logger.error(`[workforce] skills.search failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.skills.install ───────────────────────────────────
    api.registerGatewayMethod("workforce.skills.install", async ({ params, respond }) => {
      try {
        const employeeId = requireString(params, "employeeId");
        const skillId = requireString(params, "skillId");
        const taskId = params.taskId as string | undefined;

        const result = skillInstall(
          { employeeId, taskId, logger: api.logger },
          skillId,
        );

        respond(true, result);
      } catch (err) {
        api.logger.error(`[workforce] skills.install failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.skills.list ──────────────────────────────────────
    api.registerGatewayMethod("workforce.skills.list", async ({ params, respond }) => {
      try {
        const employeeId = requireString(params, "employeeId");
        const skills = skillList({ employeeId, logger: api.logger });
        respond(true, { skills });
      } catch (err) {
        api.logger.error(`[workforce] skills.list failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.output.present ─────────────────────────────────
    // Explicitly present an output in the preview panel.
    // Called by agents via the `preview` tool after creating/updating files.
    // Accepts either taskId directly or sessionKey (to derive taskId).
    api.registerGatewayMethod("workforce.output.present", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        // Accept taskId directly or derive from sessionKey
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        const filePath = params.filePath as string | undefined;
        const url = params.url as string | undefined;
        const title = params.title as string | undefined;

        if (!filePath && !url) {
          respond(false, { error: "Must provide either filePath or url" });
          return;
        }

        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }

        // Extract agentId from session key for workspace-relative path resolution
        const agentId = task.sessionKey.includes(":") ? task.sessionKey.split(":")[1] : undefined;

        // Create the output object
        const output = filePath
          ? createFileOutput(filePath, agentId, title)
          : createUrlOutput(url!, title);

        // Add to task outputs
        appendOutput(taskId, output);

        // Broadcast with "present" flag to signal UI should switch to this output
        context.broadcast("workforce.output.present", {
          taskId,
          output,
          present: true,
        });

        api.logger.info(`[workforce] Output presented: ${output.title} for task ${taskId}`);
        respond(true, { outputId: output.id, output });
      } catch (err) {
        api.logger.error(`[workforce] output.present failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.output.refresh ─────────────────────────────────
    // Request the preview panel to refresh the current view.
    // Useful when agent has updated a file that's already displayed.
    // Accepts either taskId directly or sessionKey (to derive taskId).
    api.registerGatewayMethod("workforce.output.refresh", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        // Accept taskId directly or derive from sessionKey
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }

        // Broadcast refresh event to UI
        context.broadcast("workforce.output.refresh", { taskId });

        api.logger.info(`[workforce] Output refresh requested for task ${taskId}`);
        respond(true, { success: true });
      } catch (err) {
        api.logger.error(`[workforce] output.refresh failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.browser.execute ────────────────────────────────
    // Execute arbitrary JavaScript in the browser.
    // Returns the result of the script evaluation.
    // Uses CDP directly if embedded browser is active, otherwise falls back to WKWebView.
    api.registerGatewayMethod("workforce.browser.execute", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;
        const script = params.script as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        if (!script) {
          respond(false, { error: "Must provide script to execute" });
          return;
        }

        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }

        // Check if there's an embedded browser session (CDP path)
        const embeddedSession = getEmbeddedSession(taskId);
        if (embeddedSession?.streaming) {
          api.logger.info(`[workforce] Using CDP path for execute, taskId=${taskId}`);
          try {
            const result = await evaluateScript({ taskId, script });
            respond(true, { result });
            return;
          } catch (cdpErr) {
            api.logger.error(`[workforce] CDP execute failed: ${cdpErr}`);
            respond(false, { error: `CDP execute failed: ${errMsg(cdpErr)}` });
            return;
          }
        }

        // Fall back to WKWebView path
        // Check if a WebView exists (has URL output)
        const hasWebView = task.outputs.some((o) => o.type === "url");
        if (!hasWebView) {
          respond(false, {
            error:
              "No browser available. Navigate to a URL first using webview(action='navigate', url='...')",
          });
          return;
        }

        const requestId = crypto.randomUUID();
        const pendingRequests = getPendingBrowserRequests();

        // Create promise that will be resolved when response arrives
        const resultPromise = new Promise<unknown>((resolve, reject) => {
          const timeout = setTimeout(() => {
            pendingRequests.delete(requestId);
            reject(new Error("Browser execute request timed out"));
          }, 30000);

          pendingRequests.set(requestId, { resolve, reject, timeout });
        });

        // Broadcast request to macOS app
        context.broadcast("workforce.browser.execute.request", {
          taskId,
          requestId,
          script,
        });

        api.logger.info(`[workforce] Browser execute request (WKWebView): ${requestId}`);

        try {
          const result = await resultPromise;
          respond(true, { result });
        } catch (err) {
          respond(false, { error: errMsg(err) });
        }
      } catch (err) {
        api.logger.error(`[workforce] browser.execute failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.browser.observe ────────────────────────────────
    // Capture current state of the browser.
    // Returns { dom, screenshot, url, title }.
    // Uses CDP directly if embedded browser is active, otherwise falls back to WKWebView.
    api.registerGatewayMethod("workforce.browser.observe", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }

        // Check if there's an embedded browser session (CDP path)
        const embeddedSession = getEmbeddedSession(taskId);
        if (embeddedSession?.streaming) {
          api.logger.info(`[workforce] Using CDP path for observe, taskId=${taskId}`);
          try {
            // Get page info and screenshot via CDP
            const [pageInfo, screenshot] = await Promise.all([
              getPageInfo({ taskId }),
              captureScreenshot({ taskId }),
            ]);

            respond(true, {
              url: pageInfo.url,
              title: pageInfo.title,
              dom: pageInfo.dom,
              screenshot: screenshot,
            });
            return;
          } catch (cdpErr) {
            api.logger.error(`[workforce] CDP observe failed: ${cdpErr}`);
            respond(false, { error: `CDP observe failed: ${errMsg(cdpErr)}` });
            return;
          }
        }

        // Fall back to WKWebView path
        // Check if a WebView exists (has URL output)
        const hasWebView = task.outputs.some((o) => o.type === "url");
        if (!hasWebView) {
          respond(false, {
            error:
              "No browser available. Navigate to a URL first using webview(action='navigate', url='...')",
          });
          return;
        }

        const requestId = crypto.randomUUID();
        const pendingRequests = getPendingBrowserRequests();

        const resultPromise = new Promise<unknown>((resolve, reject) => {
          const timeout = setTimeout(() => {
            pendingRequests.delete(requestId);
            reject(new Error("Browser observe request timed out"));
          }, 30000);

          pendingRequests.set(requestId, { resolve, reject, timeout });
        });

        context.broadcast("workforce.browser.observe.request", {
          taskId,
          requestId,
        });

        api.logger.info(`[workforce] Browser observe request (WKWebView): ${requestId}`);

        try {
          const result = await resultPromise;
          respond(true, result as Record<string, unknown>);
        } catch (err) {
          respond(false, { error: errMsg(err) });
        }
      } catch (err) {
        api.logger.error(`[workforce] browser.observe failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.browser.navigate ───────────────────────────────
    // Navigate the preview panel to a URL using the embedded browser (CDP screencast).
    // This launches a real Chromium browser and streams frames to the app.
    api.registerGatewayMethod("workforce.browser.navigate", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;
        const url = params.url as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        if (!url) {
          respond(false, { error: "Must provide url to navigate to" });
          return;
        }

        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }

        api.logger.info(`[workforce] Starting embedded browser for task ${taskId}: ${url}`);

        // Use the embedded browser (CDP screencast) for full browser capabilities
        const session = await startEmbeddedBrowser({
          taskId,
          url,
          broadcast: context.broadcast,
          screencastOptions: {
            format: "jpeg",
            quality: 80,
            maxWidth: 1280,
            maxHeight: 720,
            everyNthFrame: 2,
          },
        });

        // Broadcast started event (TaskService will create the output and present it)
        context.broadcast("workforce.embedded.started", {
          taskId,
          targetId: session.targetId,
          profile: "openclaw",
          url: session.url,
        });

        api.logger.info(`[workforce] Embedded browser started: ${session.screencastKey}`);

        // Return session info so agent can use the standard browser() tool
        respond(true, {
          result: {
            url,
            targetId: session.targetId,
            profile: "openclaw",
          },
          message:
            "Browser ready. Use browser(action='snapshot', targetId='" +
            session.targetId +
            "', profile='openclaw') to observe the page.",
        });
      } catch (err) {
        api.logger.error(`[workforce] browser.navigate failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.browser.response ───────────────────────────────
    // Receive response from macOS app for browser requests.
    // Resolves the pending promise for the matching requestId.
    api.registerGatewayMethod("workforce.browser.response", async ({ params, respond }) => {
      try {
        const requestId = params.requestId as string | undefined;
        const success = params.success as boolean;
        const result = params.result;
        const error = params.error as string | undefined;

        if (!requestId) {
          respond(false, { error: "Must provide requestId" });
          return;
        }

        api.logger.info(`[workforce] Browser response received: ${requestId}`);

        const pendingRequests = getPendingBrowserRequests();
        const pending = pendingRequests.get(requestId);

        if (!pending) {
          // Request may have timed out, been handled already, or this is a duplicate
          // response from multiple WebViewCoordinators. This is expected and not an error.
          api.logger.info(`[workforce] No pending request for ${requestId} (already handled or timed out)`);
          respond(true, { handled: false });
          return;
        }

        // Clear timeout and remove from map
        clearTimeout(pending.timeout);
        pendingRequests.delete(requestId);

        if (success) {
          pending.resolve(result);
        } else {
          pending.reject(new Error(error ?? "Browser request failed"));
        }

        respond(true, { handled: true });
      } catch (err) {
        api.logger.error(`[workforce] browser.response failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.embedded.start ─────────────────────────────────
    // Start embedded browser streaming (Atlas/OWL-style CDP Screencast).
    // Launches browser, navigates to URL, streams frames to macOS app.
    api.registerGatewayMethod("workforce.embedded.start", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;
        const url = params.url as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        if (!url) {
          respond(false, { error: "Must provide url to open" });
          return;
        }

        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }

        const session = await startEmbeddedBrowser({
          taskId,
          url,
          broadcast: context.broadcast,
          screencastOptions: {
            format: (params.format as "jpeg" | "png" | undefined) ?? "jpeg",
            quality: (params.quality as number | undefined) ?? 80,
            maxWidth: (params.maxWidth as number | undefined) ?? 1280,
            maxHeight: (params.maxHeight as number | undefined) ?? 720,
            everyNthFrame: (params.everyNthFrame as number | undefined) ?? 2,
          },
        });

        api.logger.info(`[workforce] Embedded browser started for task ${taskId}: ${url}`);

        // Notify the app that embedded browser is active
        context.broadcast("workforce.embedded.started", {
          taskId,
          targetId: session.targetId,
          url: session.url,
        });

        respond(true, {
          taskId,
          targetId: session.targetId,
          url: session.url,
          streaming: true,
        });
      } catch (err) {
        api.logger.error(`[workforce] embedded.start failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.embedded.stop ──────────────────────────────────
    // Stop embedded browser streaming for a task.
    api.registerGatewayMethod("workforce.embedded.stop", async ({ params, respond, context }) => {
      setSharedBroadcast(context.broadcast);
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        await stopEmbeddedBrowser({ taskId });

        api.logger.info(`[workforce] Embedded browser stopped for task ${taskId}`);

        // Notify the app that embedded browser is stopped
        context.broadcast("workforce.embedded.stopped", { taskId });

        respond(true, { taskId, stopped: true });
      } catch (err) {
        api.logger.error(`[workforce] embedded.stop failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.embedded.input.mouse ───────────────────────────
    // Dispatch mouse event to embedded browser (renderer-scoped, not OS-level).
    api.registerGatewayMethod("workforce.embedded.input.mouse", async ({ params, respond }) => {
      api.logger.debug(`[workforce] embedded.input.mouse received: ${JSON.stringify(params)}`);
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          api.logger.warn(`[workforce] embedded.input.mouse - no taskId provided`);
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        const session = getEmbeddedSession(taskId);
        if (!session) {
          api.logger.warn(`[workforce] embedded.input.mouse - no session for task: ${taskId}`);
          respond(false, { error: `No embedded browser session for task: ${taskId}` });
          return;
        }
        api.logger.debug(`[workforce] embedded.input.mouse - session found, targetId: ${session.targetId}`);

        const type = params.type as "mousePressed" | "mouseReleased" | "mouseMoved" | "mouseWheel";
        const x = params.x as number;
        const y = params.y as number;

        if (!type || typeof x !== "number" || typeof y !== "number") {
          respond(false, { error: "Must provide type, x, and y" });
          return;
        }

        await dispatchMouseEvent({
          taskId,
          type,
          x,
          y,
          button: params.button as "none" | "left" | "middle" | "right" | undefined,
          clickCount: params.clickCount as number | undefined,
          deltaX: params.deltaX as number | undefined,
          deltaY: params.deltaY as number | undefined,
          modifiers: params.modifiers as number | undefined,
        });

        api.logger.debug(`[workforce] embedded.input.mouse - dispatched ${type} at (${x}, ${y})`);
        respond(true, { dispatched: true });
      } catch (err) {
        api.logger.error(`[workforce] embedded.input.mouse failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.embedded.input.key ─────────────────────────────
    // Dispatch keyboard event to embedded browser (renderer-scoped, not OS-level).
    api.registerGatewayMethod("workforce.embedded.input.key", async ({ params, respond }) => {
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        const session = getEmbeddedSession(taskId);
        if (!session) {
          respond(false, { error: `No embedded browser session for task: ${taskId}` });
          return;
        }

        const type = params.type as "keyDown" | "keyUp" | "char";
        if (!type) {
          respond(false, { error: "Must provide type (keyDown, keyUp, or char)" });
          return;
        }

        await dispatchKeyEvent({
          taskId,
          type,
          key: params.key as string | undefined,
          code: params.code as string | undefined,
          text: params.text as string | undefined,
          modifiers: params.modifiers as number | undefined,
        });

        respond(true, { dispatched: true });
      } catch (err) {
        api.logger.error(`[workforce] embedded.input.key failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── workforce.embedded.status ────────────────────────────────
    // Get the current embedded browser session status for a task.
    api.registerGatewayMethod("workforce.embedded.status", async ({ params, respond }) => {
      try {
        let taskId = params.taskId as string | undefined;
        const sessionKey = params.sessionKey as string | undefined;

        if (!taskId && sessionKey) {
          const taskBySession = getTaskBySessionKey(sessionKey);
          if (taskBySession) {
            taskId = taskBySession.id;
          }
        }

        if (!taskId) {
          respond(false, { error: "Must provide either taskId or sessionKey" });
          return;
        }

        const session = getEmbeddedSession(taskId);
        if (!session) {
          respond(true, { active: false, taskId });
          return;
        }

        respond(true, {
          active: true,
          taskId,
          targetId: session.targetId,
          url: session.url,
          streaming: session.streaming,
        });
      } catch (err) {
        api.logger.error(`[workforce] embedded.status failed: ${err}`);
        respond(false, { error: errMsg(err) });
      }
    });

    // ── Lifecycle hooks ──────────────────────────────────────────

    api.on("before_agent_start", async (_event, ctx) => {
      const sessionKey = ctx.sessionKey as string | undefined;
      if (!isWorkforceSession(sessionKey, config.employees)) { return; }
      const task = getTaskBySessionKey(sessionKey);
      if (!task) { return; }

      // Inject reference documents into the task brief if available
      const employeeId = task.employeeId;
      const refContext = formatReferencesForPrompt(employeeId);
      if (refContext && !task.brief.includes("## Reference Documents")) {
        updateTask(task.id, {
          brief: `${task.brief}\n\n${refContext}`,
          status: "running",
          stage: "execute",
        });
      } else {
        updateTask(task.id, { status: "running", stage: "execute" });
      }

      api.logger.info(`[workforce] Agent running: ${task.id}`);
      const broadcast = getSharedBroadcast();
      if (broadcast) {
        broadcast("workforce.task.stage", { taskId: task.id, stage: "execute" });
      } else {
        api.logger.warn(`[workforce] No broadcast available for task ${task.id}`);
      }
      // Identity is now provided via IDENTITY.md in the employee's agent workspace
      // (written by setupAgentWorkspaces at gateway start). No runtime injection needed.
    });

    api.on("after_tool_call", async (event, ctx) => {
      const sessionKey = ctx.sessionKey as string | undefined;
      if (!isWorkforceSession(sessionKey, config.employees)) { return; }
      const task = getTaskBySessionKey(sessionKey);
      if (!task) { return; }
      const toolName = (event.toolName as string) ?? "tool";

      const activity = {
        id: `act-${crypto.randomUUID().slice(0, 8)}`,
        type: "toolCall" as const,
        message: `Using ${toolName}`,
        timestamp: new Date().toISOString(),
      };
      const activities = [...task.activities, activity].slice(-100);
      const progress = Math.min(1.0 - 1.0 / (1.0 + activities.length * 0.08), 0.95);
      updateTask(task.id, { activities, progress });
      const broadcast = getSharedBroadcast();
      if (broadcast) {
        broadcast("workforce.task.activity", { taskId: task.id, activity });
        broadcast("workforce.task.progress", { taskId: task.id, progress });
        // Output detection removed — agents must explicitly call workforce.output.present
      } else {
        api.logger.warn(`[workforce] No broadcast available for task ${task.id}`);
      }
    });

    api.on("agent_end", async (_event, ctx) => {
      const sessionKey = ctx.sessionKey as string | undefined;
      if (!isWorkforceSession(sessionKey, config.employees)) { return; }
      const task = getTaskBySessionKey(sessionKey);
      if (!task || task.status === "completed" || task.status === "cancelled") { return; }
      updateTask(task.id, {
        status: "completed",
        stage: "deliver",
        progress: 1.0,
        completedAt: new Date().toISOString(),
      });
      api.logger.info(`[workforce] Task completed: ${task.id}`);

      // Write memory after task completion
      const completedTask = getTask(task.id);
      if (completedTask) {
        try {
          writeTaskEpisode(completedTask);
          updateEmployeeMemory(completedTask);
          api.logger.info(`[workforce] Memory updated for ${completedTask.employeeId}`);
        } catch (err) {
          api.logger.warn(`[workforce] Failed to update memory: ${err}`);
        }
      }

      const broadcast = getSharedBroadcast();
      if (broadcast) {
        broadcast("workforce.task.completed", { taskId: task.id });
        broadcast("workforce.employee.status", {
          employeeId: task.employeeId,
          status: "online",
          currentTaskId: null,
        });
      } else {
        api.logger.warn(`[workforce] No broadcast available for task ${task.id}`);
      }
    });

    // Handle streaming agent events in real-time
    api.on("agent_stream", async (event, ctx) => {
      const sessionKey = ctx.sessionKey as string | undefined;
      if (!isWorkforceSession(sessionKey, config.employees)) { return; }

      const broadcast = getSharedBroadcast();
      if (broadcast) {
        handleAgentEvent(
          {
            sessionKey,
            stream: event.stream as string,
            event: event.event as string | undefined,
            data: event.data as Record<string, unknown> | undefined,
          },
          broadcast
        );
      } else {
        api.logger.warn(`[workforce] agent_stream hook called but no broadcast available (sessionKey=${sessionKey})`);
      }
    });
  },
};

function requireString(params: Record<string, unknown>, key: string): string {
  const val = params[key];
  if (typeof val !== "string" || val.length === 0) {
    throw new Error(`Missing required parameter: ${key}`);
  }
  return val;
}

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

export { getTask, getTaskBySessionKey, updateTask, taskToWire };
export default workforcePlugin;
