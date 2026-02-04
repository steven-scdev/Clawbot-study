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
  if (!isWorkforceSessionKey(evt.sessionKey)) {
    return;
  }

  const task = getTaskBySessionKey(evt.sessionKey);
  if (!task) {
    return;
  }

  const taskId = task.id;
  const agentId = parseWorkforceSessionKey(evt.sessionKey)?.agentId;

  switch (evt.stream) {
    case "tool": {
      const activity = buildToolActivity(evt);
      if (activity) {
        appendActivity(taskId, activity);
        broadcast("workforce.task.activity", { taskId, activity });
      }
      const output = detectOutput(evt, agentId);
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
          message: text,
          timestamp: new Date().toISOString(),
        };
        appendActivity(taskId, activity);
        broadcast("workforce.task.activity", { taskId, activity });
      }
      // Detect file outputs mentioned in assistant text as fallback
      for (const output of detectOutputsFromText(text, task, agentId)) {
        appendOutput(taskId, output);
        broadcast("workforce.task.output", { taskId, output });
      }
      // Detect localhost URLs in assistant text
      const urlFromText = text.match(/https?:\/\/localhost:\d+/);
      if (urlFromText) {
        const urlOutput: TaskOutput = {
          id: `out-${crypto.randomUUID().slice(0, 8)}`,
          type: "website",
          title: "Preview",
          url: urlFromText[0],
          createdAt: new Date().toISOString(),
        };
        const existing = task.outputs.find((o) => o.url === urlOutput.url);
        if (!existing) {
          appendOutput(taskId, urlOutput);
          broadcast("workforce.task.output", { taskId, output: urlOutput });
        }
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

const FILE_WRITE_TOOLS = new Set([
  "write_file", "Write", "create_file",
  "str_replace_editor", "file_editor", "edit_file",
  "save_file", "write", "create",
]);

function detectOutput(evt: AgentEvent, agentId?: string): TaskOutput | null {
  const toolName = (evt.data?.name as string) ?? "";
  const result = (evt.data?.result as string) ?? "";
  const args = (evt.data?.args ?? evt.data?.input) as Record<string, unknown> | string | undefined;

  // Extract file path from tool args (nested) or top-level data
  if (FILE_WRITE_TOOLS.has(toolName)) {
    const filePath = extractFilePath(evt.data, args);
    if (filePath) {
      return buildFileOutput(filePath, agentId);
    }
  }

  // Detect first file path from bash/command tool results
  if (toolName === "bash" || toolName === "Bash" || toolName === "execute_command") {
    const firstPath = extractFilePathFromText(result);
    if (firstPath) { return buildFileOutput(firstPath, agentId); }
  }

  // Detect localhost URLs from any tool result
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

function extractFilePath(data: Record<string, unknown> | undefined, args: Record<string, unknown> | string | undefined): string | null {
  // Check top-level data fields
  for (const key of ["path", "filePath", "file_path", "filename"]) {
    if (typeof data?.[key] === "string") { return data[key] as string; }
  }
  // Check nested args object
  if (args && typeof args === "object") {
    for (const key of ["path", "filePath", "file_path", "filename"]) {
      if (typeof (args as Record<string, unknown>)[key] === "string") { return (args as Record<string, unknown>)[key] as string; }
    }
  }
  // Check stringified args for file path
  if (typeof args === "string") {
    const match = args.match(/(?:path|filePath|file_path)["']?\s*[:=]\s*["']([^"']+)/);
    if (match) { return match[1]; }
  }
  return null;
}

const KNOWN_EXT = String.raw`(?:html?|css|js|ts|jsx|tsx|py|md|txt|pdf|png|jpg|svg|csv|json|xml|yaml|yml|sh|rb|go|rs|swift|java|c|cpp|pptx?|xlsx?|mp[34]|mov|wav)`;

/** Extract all file paths from text — both absolute and relative with known extensions */
function extractFilePathsFromText(text: string): string[] {
  if (!text) { return []; }
  const paths: string[] = [];
  const seen = new Set<string>();
  // Absolute paths
  for (const m of text.matchAll(new RegExp(String.raw`(\/[\w./-]+\.${KNOWN_EXT})\b`, "gi"))) {
    if (!seen.has(m[1].toLowerCase())) { seen.add(m[1].toLowerCase()); paths.push(m[1]); }
  }
  // Relative filenames (word chars, hyphens, underscores before extension)
  for (const m of text.matchAll(new RegExp(String.raw`(?:^|[\s"'=:])([A-Za-z][\w.-]*\.${KNOWN_EXT})\b`, "gim"))) {
    if (!seen.has(m[1].toLowerCase())) { seen.add(m[1].toLowerCase()); paths.push(m[1]); }
  }
  return paths;
}

/** Extract a single file path from text (backward-compat helper) */
function extractFilePathFromText(text: string): string | null {
  return extractFilePathsFromText(text)[0] ?? null;
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

/** Detect file outputs from assistant text — handles `backtick`, **bold**, and bare filenames */
function detectOutputsFromText(text: string, task: TaskManifest, agentId?: string): TaskOutput[] {
  if (!text) { return []; }
  const outputs: TaskOutput[] = [];
  const seen = new Set<string>();

  function addIfNew(filename: string): void {
    const resolved = resolveFilePath(filename, agentId);
    const key = resolved.toLowerCase();
    if (seen.has(key)) { return; }
    seen.add(key);
    const existing = task.outputs.find((o) =>
      o.filePath?.toLowerCase() === key || o.title?.toLowerCase() === filename.toLowerCase()
    );
    if (existing) { return; }
    outputs.push(buildFileOutput(filename, agentId));
  }

  // Backtick-quoted: `filename.ext`
  for (const m of text.matchAll(new RegExp(String.raw`\x60([^\x60]+\.${KNOWN_EXT})\x60`, "gi"))) {
    addIfNew(m[1]);
  }
  // Bold markdown: **filename.ext**
  for (const m of text.matchAll(new RegExp(String.raw`\*\*([^*]+\.${KNOWN_EXT})\*\*`, "gi"))) {
    addIfNew(m[1]);
  }
  // Absolute paths and relative filenames
  for (const p of extractFilePathsFromText(text)) {
    addIfNew(p);
  }

  return outputs;
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

/**
 * Detect outputs from the `after_tool_call` plugin hook.
 * This fires regardless of verbose level, unlike `agent_stream` tool events
 * which are gated by `shouldEmitToolEvents`.
 */
export function handleToolCall(
  taskId: string,
  toolName: string,
  params: Record<string, unknown>,
  result: string | undefined,
  broadcast: Broadcaster,
): void {
  // Extract agentId from the task's session key for workspace-relative paths
  const taskForAgent = getTask(taskId);
  const agentId = taskForAgent ? parseWorkforceSessionKey(taskForAgent.sessionKey)?.agentId : undefined;

  // Detect file output from write tools
  if (FILE_WRITE_TOOLS.has(toolName)) {
    const filePath = extractFilePath(params, params);
    if (filePath) {
      const output = buildFileOutput(filePath, agentId);
      appendOutput(taskId, output);
      broadcast("workforce.task.output", { taskId, output });
      return;
    }
  }

  // Detect file paths from bash/command tool results
  if (result && (toolName === "bash" || toolName === "Bash" || toolName === "execute_command")) {
    const task = getTask(taskId);
    for (const filePath of extractFilePathsFromText(result)) {
      const resolved = resolveFilePath(filePath, agentId);
      const existing = task?.outputs.find((o) => o.filePath?.toLowerCase() === resolved.toLowerCase());
      if (!existing) {
        const output = buildFileOutput(filePath, agentId);
        appendOutput(taskId, output);
        broadcast("workforce.task.output", { taskId, output });
      }
    }
  }

  // Detect localhost URLs from any tool result
  if (result) {
    const urlMatch = result.match(/https?:\/\/localhost:\d+/);
    if (urlMatch) {
      const task = getTask(taskId);
      const existing = task?.outputs.find((o) => o.url === urlMatch[0]);
      if (!existing) {
        const output: TaskOutput = {
          id: `out-${crypto.randomUUID().slice(0, 8)}`,
          type: "website",
          title: "Preview",
          url: urlMatch[0],
          createdAt: new Date().toISOString(),
        };
        appendOutput(taskId, output);
        broadcast("workforce.task.output", { taskId, output });
      }
    }
  }
}
