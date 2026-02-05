import { writeFileSync, readFileSync, mkdirSync, existsSync } from "node:fs";
import { join } from "node:path";
import { resolveEmployeeWorkspaceDir } from "./agent-workspaces.js";
import type { TaskManifest, TaskOutput } from "./task-store.js";

const MEMORY_FILENAME = "MEMORY.md";
const EPISODES_DIR = "memory/episodes";
const MAX_MEMORY_CHARS = 18_000; // Leave room for header (OpenClaw truncates at 20K)
const MAX_RECENT_TASKS = 10;

/**
 * Episode record stored in memory/episodes/{taskId}.json
 */
export type TaskEpisode = {
  taskId: string;
  employeeId: string;
  brief: string;
  status: "completed" | "failed" | "cancelled";
  startedAt: string;
  completedAt: string;
  outputs: Array<{
    type: TaskOutput["type"];
    title: string;
    path?: string;
  }>;
};

/**
 * Write a task episode to memory/episodes/{taskId}.json
 * Returns the episode for chaining.
 */
export function writeTaskEpisode(task: TaskManifest): TaskEpisode {
  const workspaceDir = resolveEmployeeWorkspaceDir(task.employeeId);
  const episodesDir = join(workspaceDir, EPISODES_DIR);
  mkdirSync(episodesDir, { recursive: true });

  const episode: TaskEpisode = {
    taskId: task.id,
    employeeId: task.employeeId,
    brief: task.brief.slice(0, 500), // Truncate long briefs
    status: task.status as "completed" | "failed" | "cancelled",
    startedAt: task.createdAt,
    completedAt: task.completedAt ?? new Date().toISOString(),
    outputs: task.outputs.slice(0, 20).map((o) => ({
      type: o.type,
      title: o.title,
      path: o.filePath,
    })),
  };

  const episodePath = join(episodesDir, `${task.id}.json`);
  writeFileSync(episodePath, JSON.stringify(episode, null, 2));
  return episode;
}

/**
 * Update the employee's MEMORY.md with the latest task summary.
 * - Reads existing MEMORY.md (or creates new)
 * - Adds new task to "## Recent Tasks" section
 * - Keeps last MAX_RECENT_TASKS tasks
 * - Truncates to stay under MAX_MEMORY_CHARS
 */
export function updateEmployeeMemory(task: TaskManifest): void {
  const workspaceDir = resolveEmployeeWorkspaceDir(task.employeeId);
  const memoryPath = join(workspaceDir, MEMORY_FILENAME);

  // Load existing MEMORY.md or start fresh
  let existingContent = "";
  if (existsSync(memoryPath)) {
    existingContent = readFileSync(memoryPath, "utf-8");
  }

  // Parse existing sections
  const sections = parseMemorySections(existingContent);

  // Add new task to recent tasks (at the beginning)
  const newEntry = formatTaskEntry(task);
  sections.recentTasks = [newEntry, ...sections.recentTasks].slice(0, MAX_RECENT_TASKS);

  // Rebuild MEMORY.md
  const newContent = buildMemoryContent(sections, task.employeeId);

  // Truncate if needed (keep most recent content)
  const finalContent = truncateMemory(newContent, MAX_MEMORY_CHARS);
  writeFileSync(memoryPath, finalContent);
}

type MemorySections = {
  recentTasks: string[];
  notes: string;
  preferences: string;
};

/**
 * Parse MEMORY.md into sections for manipulation.
 * Preserves Notes and Preferences sections that might have been
 * manually added or written by the employee.
 */
function parseMemorySections(content: string): MemorySections {
  if (!content.trim()) {
    return { recentTasks: [], notes: "", preferences: "" };
  }

  // Extract ## Recent Tasks section
  const recentMatch = content.match(/## Recent Tasks\n([\s\S]*?)(?=\n## |$)/);
  const recentContent = recentMatch ? recentMatch[1].trim() : "";

  // Split recent tasks by ### headers
  const recentTasks = recentContent
    .split(/(?=\n### )/)
    .map((t) => t.trim())
    .filter((t) => t.startsWith("### "));

  // Extract ## Notes section (preserve user/employee notes)
  const notesMatch = content.match(/## Notes\n([\s\S]*?)(?=\n## |$)/);
  const notes = notesMatch ? notesMatch[1].trim() : "";

  // Extract ## Preferences section (preserve learned preferences)
  const prefsMatch = content.match(/## Preferences\n([\s\S]*?)(?=\n## |$)/);
  const preferences = prefsMatch ? prefsMatch[1].trim() : "";

  return { recentTasks, notes, preferences };
}

/**
 * Format a single task entry for the Recent Tasks section.
 */
function formatTaskEntry(task: TaskManifest): string {
  const date = formatDate(task.completedAt ?? task.updatedAt);
  const statusIcon = getStatusIcon(task.status);
  const briefTruncated = task.brief.slice(0, 80).replace(/\n/g, " ");

  const lines = [`### ${date} ${statusIcon} ${briefTruncated}`];

  if (task.outputs.length > 0) {
    const outputNames = task.outputs
      .slice(0, 5)
      .map((o) => o.title)
      .join(", ");
    lines.push(`Outputs: ${outputNames}`);
  }

  if (task.status === "failed" && task.errorMessage) {
    lines.push(`Error: ${task.errorMessage.slice(0, 100)}`);
  }

  return lines.join("\n");
}

function formatDate(isoString: string): string {
  try {
    const d = new Date(isoString);
    return d.toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  } catch {
    return isoString.slice(0, 10);
  }
}

function getStatusIcon(status: string): string {
  switch (status) {
    case "completed":
      return "[done]";
    case "failed":
      return "[failed]";
    case "cancelled":
      return "[cancelled]";
    default:
      return "[?]";
  }
}

/**
 * Build the full MEMORY.md content from sections.
 */
function buildMemoryContent(sections: MemorySections, employeeId: string): string {
  const parts: string[] = [];

  // Header
  parts.push(`# ${employeeId} Working Memory\n`);
  parts.push(`*Last updated: ${new Date().toISOString()}*\n`);

  // Recent Tasks section
  parts.push("## Recent Tasks\n");
  if (sections.recentTasks.length > 0) {
    parts.push(sections.recentTasks.join("\n\n"));
  } else {
    parts.push("*No tasks completed yet.*");
  }
  parts.push("");

  // Notes section (preserve if exists)
  if (sections.notes) {
    parts.push("## Notes\n");
    parts.push(sections.notes);
    parts.push("");
  }

  // Preferences section (preserve if exists)
  if (sections.preferences) {
    parts.push("## Preferences\n");
    parts.push(sections.preferences);
    parts.push("");
  }

  return parts.join("\n");
}

/**
 * Truncate memory content to fit within max chars.
 * Keeps header and most recent content, truncates middle if needed.
 */
function truncateMemory(content: string, maxChars: number): string {
  if (content.length <= maxChars) {
    return content;
  }

  // Split by lines and keep header + as many recent tasks as fit
  const lines = content.split("\n");

  // Keep first 5 lines (header) always
  const headerLines = lines.slice(0, 5);
  const restLines = lines.slice(5);

  const headerLength = headerLines.join("\n").length;
  const availableChars = maxChars - headerLength - 100; // Leave some margin

  // Build rest from most recent content
  let restContent = "";
  for (const line of restLines) {
    if (restContent.length + line.length + 1 <= availableChars) {
      restContent += (restContent ? "\n" : "") + line;
    } else {
      break;
    }
  }

  return headerLines.join("\n") + "\n" + restContent + "\n\n*[Memory truncated]*";
}
