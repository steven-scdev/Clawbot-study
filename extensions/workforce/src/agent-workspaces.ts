import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import type { EmployeeConfig } from "./employees.js";
import { composeMind } from "./mind-composer.js";
import { updateCapabilities } from "./capabilities.js";

type Logger = {
  info: (msg: string) => void;
  error: (msg: string) => void;
  warn: (msg: string) => void;
};

/**
 * Resolve the workspace directory for an employee agent.
 * Mirrors `resolveAgentWorkspaceDir` in `src/agents/agent-scope.ts:167` for
 * non-default agents: `~/.openclaw/workspace-{employeeId}`.
 */
export function resolveEmployeeWorkspaceDir(employeeId: string): string {
  return join(homedir(), ".openclaw", `workspace-${employeeId}`);
}

/**
 * Write IDENTITY.md to each employee's agent workspace directory.
 * Composes mind content from lens/standards/principles markdown files,
 * creates the workspace dir if missing, and overwrites IDENTITY.md on
 * every gateway start to keep minds fresh.
 *
 * Employees without mind files are skipped (no error, no file written).
 */
export async function setupAgentWorkspaces(
  employees: EmployeeConfig[],
  mindsDir: string,
  logger: Logger,
): Promise<void> {
  let count = 0;
  for (const emp of employees) {
    const mindContent = composeMind(emp.id, mindsDir);
    if (!mindContent) continue;

    const workspaceDir = resolveEmployeeWorkspaceDir(emp.id);
    mkdirSync(workspaceDir, { recursive: true });
    mkdirSync(join(workspaceDir, "references", "originals"), { recursive: true });
    mkdirSync(join(workspaceDir, "skill-usage"), { recursive: true });
    writeFileSync(join(workspaceDir, "IDENTITY.md"), mindContent, "utf-8");

    // Generate initial CAPABILITIES.md with role + pre-installed skills
    updateCapabilities(emp.id, {
      role: emp.role,
      preInstalledSkills: emp.preInstalledSkills ?? [],
    });

    count++;
  }
  logger.info(`[workforce] Set up ${count} agent workspaces with IDENTITY.md`);
}
