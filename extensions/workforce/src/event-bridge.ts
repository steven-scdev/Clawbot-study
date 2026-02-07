import { join } from "node:path";
import { homedir } from "node:os";
import {
  getTask,
  getTaskBySessionKey,
  updateTask,
  type TaskManifest,
  type TaskActivity,
  type TaskOutput,
} from "./task-store.js";
import { isWorkforceSessionKey, parseWorkforceSessionKey } from "./session-keys.js";
import { writeTaskEpisode, updateEmployeeMemory } from "./memory-writer.js";

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
 *
 * NOTE: Output detection has been moved to the explicit `workforce.output.present`
 * gateway method. Agents must now call `preview.present(path, title)` to show outputs.
 */
export function handleAgentEvent(evt: AgentEvent, broadcast: Broadcaster): void {
  if (!isWorkforceSessionKey(evt.sessionKey)) {
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
        // Detect preparation-phase tool calls (skill checks/searches)
        const toolName = (evt.data?.name as string) ?? "";
        if (isPreparationTool(toolName) && activity.type === "toolCall") {
          activity.type = "planning";
        }
        appendActivity(taskId, activity);
        broadcast("workforce.task.activity", { taskId, activity });

        // Auto-detect "prepare" stage from skill-related tool calls
        if (isPreparationTool(toolName) && task.stage === "clarify") {
          updateTask(taskId, { stage: "prepare" });
          broadcast("workforce.task.stage", { taskId, stage: "prepare" });
        }
      }
      // Output detection removed — agents must explicitly call preview.present()
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
          message: text,
          timestamp: new Date().toISOString(),
        };
        appendActivity(taskId, activity);
        broadcast("workforce.task.activity", { taskId, activity });
      }
      // Output detection removed — agents must explicitly call preview.present()
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
        // Write memory for failed task
        const failedTask = getTask(taskId);
        if (failedTask) {
          try {
            writeTaskEpisode(failedTask);
            updateEmployeeMemory(failedTask);
          } catch {
            // Memory write failure should not block task failure handling
          }
        }
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

function resolveFilePath(filePath: string, agentId?: string): string {
  if (filePath.startsWith("/")) { return filePath; }
  // Resolve relative paths against the employee's agent workspace
  const workspaceName = agentId && agentId !== "main" ? `workspace-${agentId}` : "workspace";
  return join(homedir(), ".openclaw", workspaceName, filePath);
}

function buildFileOutput(filePath: string, agentId?: string): TaskOutput {
  const resolved = resolveFilePath(filePath, agentId);
  const ext = resolved.split(".").pop()?.toLowerCase() ?? "";
  const type = classifyOutputType(ext);
  return {
    id: `out-${crypto.randomUUID().slice(0, 8)}`,
    type,
    title: resolved.split("/").pop() ?? "output",
    filePath: resolved,
    createdAt: new Date().toISOString(),
  };
}

function classifyOutputType(ext: string): TaskOutput["type"] {
  if (["html", "htm"].includes(ext)) { return "website"; }
  if (["png", "jpg", "jpeg", "gif", "svg", "webp"].includes(ext)) { return "image"; }
  if (["md", "txt", "pdf", "doc", "docx"].includes(ext)) { return "document"; }
  if (["pptx", "ppt", "key"].includes(ext)) { return "presentation"; }
  if (["xlsx", "xls", "csv", "numbers"].includes(ext)) { return "spreadsheet"; }
  if (["mp4", "mov", "webm", "avi", "mkv"].includes(ext)) { return "video"; }
  if (["mp3", "wav", "aac", "ogg", "flac", "m4a"].includes(ext)) { return "audio"; }
  if (["swift", "ts", "js", "py", "go", "rs", "java", "c", "cpp", "rb"].includes(ext)) { return "code"; }
  return "file";
}

const STAGE_ORDER = ["prepare", "clarify", "plan", "execute", "review", "deliver"] as const;

const PREPARATION_TOOLS = new Set(["skill_search", "skill_install", "skill_list", "memory_search", "memory_get"]);

function isPreparationTool(toolName: string): boolean {
  return PREPARATION_TOOLS.has(toolName);
}

function detectStageFromText(text: string, currentStage: string): TaskManifest["stage"] | null {
  const lower = text.toLowerCase();
  const currentIdx = STAGE_ORDER.indexOf(currentStage as typeof STAGE_ORDER[number]);

  if (currentIdx < 2 && (lower.includes("plan") || lower.includes("approach") || lower.includes("i'll"))) {
    return "plan";
  }
  if (currentIdx < 3 && (lower.includes("implement") || lower.includes("creating") || lower.includes("writing"))) {
    return "execute";
  }
  if (currentIdx < 4 && (lower.includes("review") || lower.includes("checking") || lower.includes("testing"))) {
    return "review";
  }
  if (currentIdx < 5 && (lower.includes("complete") || lower.includes("done") || lower.includes("finished"))) {
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

export function appendOutput(taskId: string, output: TaskOutput): void {
  const current = getTask(taskId);
  if (!current) { return; }
  updateTask(taskId, { outputs: [...current.outputs, output] });
}

/**
 * Create a TaskOutput from a file path.
 * Resolves relative paths against the agent's workspace directory.
 */
export function createFileOutput(filePath: string, agentId?: string, title?: string): TaskOutput {
  const output = buildFileOutput(filePath, agentId);
  if (title) {
    output.title = title;
  }
  return output;
}

/**
 * Create a TaskOutput from a URL.
 */
export function createUrlOutput(url: string, title?: string): TaskOutput {
  return {
    id: `out-${crypto.randomUUID().slice(0, 8)}`,
    type: "website",
    title: title ?? "Preview",
    url,
    createdAt: new Date().toISOString(),
  };
}
