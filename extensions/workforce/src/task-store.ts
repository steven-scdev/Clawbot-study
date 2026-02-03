import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

export type TaskManifest = {
  id: string;
  employeeId: string;
  brief: string;
  status: "pending" | "running" | "completed" | "failed" | "cancelled";
  stage: "clarify" | "plan" | "execute" | "review" | "deliver";
  sessionKey: string;
  createdAt: string;
  completedAt?: string;
  errorMessage?: string;
};

const STORE_DIR = join(homedir(), ".openclaw", "workforce", "tasks");

function ensureDir() {
  if (!existsSync(STORE_DIR)) {
    mkdirSync(STORE_DIR, { recursive: true });
  }
}

export function createTask(task: TaskManifest): void {
  ensureDir();
  const path = join(STORE_DIR, `${task.id}.json`);
  writeFileSync(path, JSON.stringify(task, null, 2));
}

export function getTask(id: string): TaskManifest | null {
  const path = join(STORE_DIR, `${id}.json`);
  if (!existsSync(path)) {
    return null;
  }
  return JSON.parse(readFileSync(path, "utf-8")) as TaskManifest;
}

export function updateTask(id: string, updates: Partial<TaskManifest>): TaskManifest | null {
  const task = getTask(id);
  if (!task) {
    return null;
  }
  const updated = { ...task, ...updates };
  const path = join(STORE_DIR, `${id}.json`);
  writeFileSync(path, JSON.stringify(updated, null, 2));
  return updated;
}

export function listTasks(opts?: {
  limit?: number;
  offset?: number;
  status?: string[];
}): { tasks: TaskManifest[]; total: number } {
  ensureDir();
  const files = readdirSync(STORE_DIR).filter((f) => f.endsWith(".json"));
  let tasks = files
    .map((f) => {
      try {
        return JSON.parse(readFileSync(join(STORE_DIR, f), "utf-8")) as TaskManifest;
      } catch {
        return null;
      }
    })
    .filter((t): t is TaskManifest => t !== null)
    .toSorted((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());

  if (opts?.status?.length) {
    tasks = tasks.filter((t) => opts.status!.includes(t.status));
  }

  const total = tasks.length;
  const offset = opts?.offset ?? 0;
  const limit = opts?.limit ?? 50;
  return { tasks: tasks.slice(offset, offset + limit), total };
}

export function getActiveTaskForEmployee(employeeId: string): TaskManifest | null {
  ensureDir();
  const files = readdirSync(STORE_DIR).filter((f) => f.endsWith(".json"));
  for (const f of files) {
    try {
      const task = JSON.parse(readFileSync(join(STORE_DIR, f), "utf-8")) as TaskManifest;
      if (task.employeeId === employeeId && (task.status === "running" || task.status === "pending")) {
        return task;
      }
    } catch {
      // skip corrupt files
    }
  }
  return null;
}

export function isEmployeeBusy(employeeId: string): boolean {
  return getActiveTaskForEmployee(employeeId) !== null;
}

export function getTaskBySessionKey(sessionKey: string): TaskManifest | null {
  ensureDir();
  const files = readdirSync(STORE_DIR).filter((f) => f.endsWith(".json"));
  for (const f of files) {
    try {
      const task = JSON.parse(readFileSync(join(STORE_DIR, f), "utf-8")) as TaskManifest;
      if (task.sessionKey === sessionKey) {
        return task;
      }
    } catch {
      // skip
    }
  }
  return null;
}
