import {
  appendFileSync,
  readFileSync,
  existsSync,
  mkdirSync,
} from "node:fs";
import { join } from "node:path";
import { resolveEmployeeWorkspaceDir } from "./agent-workspaces.js";

/**
 * A single skill usage event. Appended as JSON lines to
 * workspace-{employeeId}/skill-usage/usage-log.jsonl.
 */
export type SkillUsageRecord = {
  skillId: string;
  action: "search" | "install" | "use";
  employeeId: string;
  taskId?: string;
  taskBrief?: string;
  timestamp: string;
  query?: string;
  success: boolean;
};

function skillLogDir(employeeId: string): string {
  return join(resolveEmployeeWorkspaceDir(employeeId), "skill-usage");
}

function skillLogPath(employeeId: string): string {
  return join(skillLogDir(employeeId), "usage-log.jsonl");
}

/**
 * Append a skill usage record to the employee's JSONL log.
 * Creates the directory if missing.
 */
export function trackSkillEvent(
  employeeId: string,
  record: Omit<SkillUsageRecord, "employeeId" | "timestamp">,
): void {
  const dir = skillLogDir(employeeId);
  mkdirSync(dir, { recursive: true });

  const full: SkillUsageRecord = {
    ...record,
    employeeId,
    timestamp: new Date().toISOString(),
  };

  appendFileSync(skillLogPath(employeeId), JSON.stringify(full) + "\n");
}

type ReadSkillLogOpts = {
  limit?: number;
  action?: SkillUsageRecord["action"];
};

/**
 * Read and parse the skill usage log for an employee.
 * Returns records newest-first. Supports optional limit and action filter.
 */
export function readSkillLog(
  employeeId: string,
  opts: ReadSkillLogOpts = {},
): SkillUsageRecord[] {
  const logPath = skillLogPath(employeeId);
  if (!existsSync(logPath)) return [];

  const lines = readFileSync(logPath, "utf-8")
    .split("\n")
    .filter((l) => l.trim().length > 0);

  let records: SkillUsageRecord[] = [];
  for (const line of lines) {
    try {
      records.push(JSON.parse(line) as SkillUsageRecord);
    } catch {
      // Skip malformed lines
    }
  }

  // Newest first
  records.reverse();

  if (opts.action) {
    records = records.filter((r) => r.action === opts.action);
  }

  if (opts.limit && opts.limit > 0) {
    records = records.slice(0, opts.limit);
  }

  return records;
}
