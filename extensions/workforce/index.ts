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
    // Captured from gateway method context so lifecycle hooks can broadcast events.
    let cachedBroadcast: ((event: string, payload: unknown) => void) | null = null;
    api.logger.info(`[workforce] Registered with ${config.employees.length} employees`);

    // ── workforce.employees.list ────────────────────────────────
    api.registerGatewayMethod("workforce.employees.list", async ({ respond, context }) => {
      if (!cachedBroadcast) { cachedBroadcast = context.broadcast; }
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
      try {
        const employeeId = requireString(params, "employeeId");
        const brief = requireString(params, "brief");
        const attachments = (params.attachments as string[] | undefined) ?? [];

        const employee = config.employees.find((e) => e.id === employeeId);
        if (!employee) {
          respond(false, { error: `Unknown employee: ${employeeId}` });
          return;
        }

        const sessionKey = `workforce-${employeeId}-${crypto.randomUUID().slice(0, 8)}`;
        const manifest = newTaskManifest({ employeeId, brief, sessionKey, attachments });
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
      try {
        const taskId = requireString(params, "taskId");
        const task = getTask(taskId);
        if (!task) {
          respond(false, { error: `Task not found: ${taskId}` });
          return;
        }
        updateTask(taskId, { status: "cancelled", completedAt: new Date().toISOString() });
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

    // ── Lifecycle hooks ──────────────────────────────────────────

    api.on("before_agent_start", async (_event, ctx) => {
      const sessionKey = ctx.sessionKey as string | undefined;
      if (!sessionKey?.startsWith("workforce-")) { return; }
      const task = getTaskBySessionKey(sessionKey);
      if (!task) { return; }
      updateTask(task.id, { status: "running", stage: "execute" });
      api.logger.info(`[workforce] Agent running: ${task.id}`);
      if (cachedBroadcast) {
        cachedBroadcast("workforce.task.stage", { taskId: task.id, stage: "execute" });
      }
    });

    api.on("after_tool_call", async (event, ctx) => {
      const sessionKey = ctx.sessionKey as string | undefined;
      if (!sessionKey?.startsWith("workforce-")) { return; }
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
      if (cachedBroadcast) {
        cachedBroadcast("workforce.task.activity", { taskId: task.id, activity });
        cachedBroadcast("workforce.task.progress", { taskId: task.id, progress });
      }
    });

    api.on("agent_end", async (_event, ctx) => {
      const sessionKey = ctx.sessionKey as string | undefined;
      if (!sessionKey?.startsWith("workforce-")) { return; }
      const task = getTaskBySessionKey(sessionKey);
      if (!task || task.status === "completed" || task.status === "cancelled") { return; }
      updateTask(task.id, {
        status: "completed",
        stage: "deliver",
        progress: 1.0,
        completedAt: new Date().toISOString(),
      });
      api.logger.info(`[workforce] Task completed: ${task.id}`);
      if (cachedBroadcast) {
        cachedBroadcast("workforce.task.completed", { taskId: task.id });
        cachedBroadcast("workforce.employee.status", {
          employeeId: task.employeeId,
          status: "online",
          currentTaskId: null,
        });
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
