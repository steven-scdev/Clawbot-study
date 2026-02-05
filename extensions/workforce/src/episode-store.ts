import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { resolveEmployeeWorkspaceDir } from "./agent-workspaces.js";
import type { TaskEpisode } from "./memory-writer.js";

const EPISODES_DIR = "memory/episodes";

export type { TaskEpisode };

export type ListEpisodesOptions = {
  limit?: number;
  status?: "completed" | "failed" | "cancelled";
};

/**
 * List episodes for an employee, sorted by completion time (newest first).
 */
export function listEmployeeEpisodes(
  employeeId: string,
  opts?: ListEpisodesOptions
): TaskEpisode[] {
  const workspaceDir = resolveEmployeeWorkspaceDir(employeeId);
  const episodesDir = join(workspaceDir, EPISODES_DIR);

  if (!existsSync(episodesDir)) {
    return [];
  }

  const files = readdirSync(episodesDir).filter((f) => f.endsWith(".json"));

  let episodes: TaskEpisode[] = files
    .map((f) => {
      try {
        return JSON.parse(readFileSync(join(episodesDir, f), "utf-8")) as TaskEpisode;
      } catch {
        return null;
      }
    })
    .filter((e): e is TaskEpisode => e !== null)
    .toSorted(
      (a, b) => new Date(b.completedAt).getTime() - new Date(a.completedAt).getTime()
    );

  // Filter by status if specified
  if (opts?.status) {
    episodes = episodes.filter((e) => e.status === opts.status);
  }

  // Apply limit
  const limit = opts?.limit ?? 50;
  return episodes.slice(0, limit);
}

/**
 * Get a specific episode by task ID.
 */
export function getEmployeeEpisode(
  employeeId: string,
  taskId: string
): TaskEpisode | null {
  const workspaceDir = resolveEmployeeWorkspaceDir(employeeId);
  const episodePath = join(workspaceDir, EPISODES_DIR, `${taskId}.json`);

  if (!existsSync(episodePath)) {
    return null;
  }

  try {
    return JSON.parse(readFileSync(episodePath, "utf-8")) as TaskEpisode;
  } catch {
    return null;
  }
}

/**
 * Get episode count for an employee.
 */
export function countEmployeeEpisodes(employeeId: string): number {
  const workspaceDir = resolveEmployeeWorkspaceDir(employeeId);
  const episodesDir = join(workspaceDir, EPISODES_DIR);

  if (!existsSync(episodesDir)) {
    return 0;
  }

  return readdirSync(episodesDir).filter((f) => f.endsWith(".json")).length;
}
