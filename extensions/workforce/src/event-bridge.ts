import {
  getTask,
  getTaskBySessionKey,
  updateTask,
  type TaskManifest,
  type TaskActivity,
  type TaskOutput,
} from "./task-store.js";

type AgentEvent = {
  sessionKey?: string;
  stream: string;
  event?: string;
  data?: Record<string, unknown>;
};

type Broadcaster = (event: string, payload: unknown) => void;

/**
 * Maps raw agent events into structured `workforce.task.*` events.
 * Called from the plugin's `onAgentEvent` listener.
 */
export function handleAgentEvent(evt: AgentEvent, broadcast: Broadcaster): void {
  if (!evt.sessionKey?.startsWith("workforce-")) {
    return;
  }

  const task = getTaskBySessionKey(evt.sessionKey);
  if (!task) {
    return;
  }

  const taskId = task.id;

  switch (evt.stream) {
    case "tool": {
      const activity = buildToolActivity(evt);
      if (activity) {
        appendActivity(taskId, activity);
        broadcast("workforce.task.activity", { taskId, activity });
      }
      const output = detectOutput(evt);
      if (output) {
        appendOutput(taskId, output);
        broadcast("workforce.task.output", { taskId, output });
      }
      const progress = computeProgress(taskId);
      updateTask(taskId, { progress });
      broadcast("workforce.task.progress", { taskId, progress });
      break;
    }
    case "assistant": {
      const text = (evt.data?.text as string) ?? "";
      if (text.length > 0) {
        const activity: TaskActivity = {
          id: `act-${crypto.randomUUID().slice(0, 8)}`,
          type: "text",
          message: text.slice(0, 500),
          timestamp: new Date().toISOString(),
        };
        appendActivity(taskId, activity);
        broadcast("workforce.task.activity", { taskId, activity });
      }
      const newStage = detectStageFromText(text, task.stage);
      if (newStage && newStage !== task.stage) {
        updateTask(taskId, { stage: newStage });
        broadcast("workforce.task.stage", { taskId, stage: newStage });
      }
      break;
    }
    case "thinking": {
      const text = (evt.data?.text as string) ?? "Thinking...";
      const activity: TaskActivity = {
        id: `act-${crypto.randomUUID().slice(0, 8)}`,
        type: "thinking",
        message: text.slice(0, 300),
        timestamp: new Date().toISOString(),
      };
      appendActivity(taskId, activity);
      broadcast("workforce.task.activity", { taskId, activity });
      break;
    }
    case "lifecycle": {
      if (evt.event === "complete" || evt.event === "end") {
        updateTask(taskId, {
          status: "completed",
          stage: "deliver",
          progress: 1.0,
          completedAt: new Date().toISOString(),
        });
        broadcast("workforce.task.completed", { taskId });
        broadcast("workforce.employee.status", {
          employeeId: task.employeeId,
          status: "online",
          currentTaskId: null,
        });
      } else if (evt.event === "error") {
        const errorMessage = (evt.data?.message as string) ?? "An error occurred";
        updateTask(taskId, {
          status: "failed",
          errorMessage,
          completedAt: new Date().toISOString(),
        });
        broadcast("workforce.task.failed", { taskId, error: errorMessage, canRetry: true });
        broadcast("workforce.employee.status", {
          employeeId: task.employeeId,
          status: "online",
          currentTaskId: null,
        });
      }
      break;
    }
  }
}

function buildToolActivity(evt: AgentEvent): TaskActivity | null {
  const name = (evt.data?.name as string) ?? "tool";
  const input = evt.data?.input as string | undefined;

  if (evt.event === "tool_call" || evt.event === "call") {
    return {
      id: `act-${crypto.randomUUID().slice(0, 8)}`,
      type: "toolCall",
      message: `Using ${name}`,
      timestamp: new Date().toISOString(),
      detail: input?.slice(0, 500),
    };
  }
  if (evt.event === "tool_result" || evt.event === "result") {
    return {
      id: `act-${crypto.randomUUID().slice(0, 8)}`,
      type: "toolResult",
      message: `${name} finished`,
      timestamp: new Date().toISOString(),
    };
  }
  return null;
}

function detectOutput(evt: AgentEvent): TaskOutput | null {
  const toolName = (evt.data?.name as string) ?? "";
  const result = (evt.data?.result as string) ?? "";

  if (toolName === "write_file" || toolName === "Write" || toolName === "create_file") {
    const filePath = (evt.data?.path as string) ?? (evt.data?.filePath as string);
    if (filePath) {
      const ext = filePath.split(".").pop()?.toLowerCase() ?? "";
      const type = classifyOutputType(ext);
      return {
        id: `out-${crypto.randomUUID().slice(0, 8)}`,
        type,
        title: filePath.split("/").pop() ?? "output",
        filePath,
        createdAt: new Date().toISOString(),
      };
    }
  }

  const urlMatch = result.match(/https?:\/\/localhost:\d+/);
  if (urlMatch) {
    return {
      id: `out-${crypto.randomUUID().slice(0, 8)}`,
      type: "website",
      title: "Preview",
      url: urlMatch[0],
      createdAt: new Date().toISOString(),
    };
  }

  return null;
}

function classifyOutputType(ext: string): TaskOutput["type"] {
  if (["html", "htm"].includes(ext)) { return "website"; }
  if (["png", "jpg", "jpeg", "gif", "svg", "webp"].includes(ext)) { return "image"; }
  if (["md", "txt", "pdf", "doc", "docx"].includes(ext)) { return "document"; }
  return "file";
}

const STAGE_ORDER = ["clarify", "plan", "execute", "review", "deliver"] as const;

function detectStageFromText(text: string, currentStage: string): TaskManifest["stage"] | null {
  const lower = text.toLowerCase();
  const currentIdx = STAGE_ORDER.indexOf(currentStage as typeof STAGE_ORDER[number]);

  if (currentIdx < 1 && (lower.includes("plan") || lower.includes("approach") || lower.includes("i'll"))) {
    return "plan";
  }
  if (currentIdx < 2 && (lower.includes("implement") || lower.includes("creating") || lower.includes("writing"))) {
    return "execute";
  }
  if (currentIdx < 3 && (lower.includes("review") || lower.includes("checking") || lower.includes("testing"))) {
    return "review";
  }
  if (currentIdx < 4 && (lower.includes("complete") || lower.includes("done") || lower.includes("finished"))) {
    return "deliver";
  }
  return null;
}

function computeProgress(taskId: string): number {
  const current = getTask(taskId);
  if (!current) { return 0; }
  const count = current.activities.length;
  return Math.min(1.0 - 1.0 / (1.0 + count * 0.08), 0.95);
}

function appendActivity(taskId: string, activity: TaskActivity): void {
  const current = getTask(taskId);
  if (!current) { return; }
  const activities = [...current.activities, activity].slice(-100);
  updateTask(taskId, { activities });
}

function appendOutput(taskId: string, output: TaskOutput): void {
  const current = getTask(taskId);
  if (!current) { return; }
  updateTask(taskId, { outputs: [...current.outputs, output] });
}
