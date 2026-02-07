// SECURITY: execFileSync and trackSkillEvent disabled to prevent external skill operations.
// import { execFileSync } from "node:child_process";
// import { trackSkillEvent, readSkillLog } from "./skill-tracker.js";
import { readSkillLog } from "./skill-tracker.js";
import { resolveEmployeeWorkspaceDir } from "./agent-workspaces.js";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

export type SkillSearchResult = {
  skillId: string;
  name: string;
  repo: string;
  url: string;
};

type SkillToolContext = {
  employeeId: string;
  taskId?: string;
  logger: { info: (msg: string) => void; error: (msg: string) => void };
};

/**
 * Search for skills via external marketplace.
 *
 * SECURITY: Disabled — external skill search is blocked to prevent
 * supply-chain attacks (e.g. AMOS malware distributed via fake ClawHub skills).
 * Will be re-enabled once a verified skill marketplace is implemented.
 */
export function skillSearch(
  ctx: SkillToolContext,
  _query: string,
): SkillSearchResult[] {
  ctx.logger.info("[skills] External skill search is disabled for security");
  return [];
  // --- Original implementation (commented out for security) ---
  // try {
  //   const output = execFileSync("npx", ["skills", "find", query], {
  //     encoding: "utf-8",
  //     timeout: 30_000,
  //   });
  //   const results = parseSkillSearchOutput(output);
  //   trackSkillEvent(ctx.employeeId, {
  //     skillId: query,
  //     action: "search",
  //     taskId: ctx.taskId,
  //     query,
  //     success: true,
  //   });
  //   ctx.logger.info(`[skills] Search "${query}": ${results.length} results`);
  //   return results;
  // } catch (err) {
  //   trackSkillEvent(ctx.employeeId, {
  //     skillId: query,
  //     action: "search",
  //     taskId: ctx.taskId,
  //     query,
  //     success: false,
  //   });
  //   ctx.logger.error(`[skills] Search failed: ${err}`);
  //   return [];
  // }
}

/**
 * Install a skill from an external marketplace.
 *
 * SECURITY: Disabled — external skill installation is blocked to prevent
 * supply-chain attacks (e.g. AMOS malware distributed via fake ClawHub skills).
 * Will be re-enabled once a verified skill marketplace is implemented.
 */
export function skillInstall(
  ctx: SkillToolContext,
  _skillId: string,
): { success: boolean; message: string } {
  ctx.logger.info("[skills] External skill installation is disabled for security");
  return {
    success: false,
    message: "External skill installation is disabled for security. Use only pre-installed skills listed in CAPABILITIES.md.",
  };
  // --- Original implementation (commented out for security) ---
  // try {
  //   const output = execFileSync("npx", ["skills", "add", skillId, "-g", "-y"], {
  //     encoding: "utf-8",
  //     timeout: 60_000,
  //   });
  //   trackSkillEvent(ctx.employeeId, {
  //     skillId,
  //     action: "install",
  //     taskId: ctx.taskId,
  //     success: true,
  //   });
  //   ctx.logger.info(`[skills] Installed: ${skillId}`);
  //   return { success: true, message: output.trim() };
  // } catch (err) {
  //   trackSkillEvent(ctx.employeeId, {
  //     skillId,
  //     action: "install",
  //     taskId: ctx.taskId,
  //     success: false,
  //   });
  //   const msg = err instanceof Error ? err.message : String(err);
  //   ctx.logger.error(`[skills] Install failed: ${msg}`);
  //   return { success: false, message: msg };
  // }
}

/**
 * List installed skills for an employee.
 * Reads from the skill usage log (install events).
 */
export function skillList(ctx: SkillToolContext): string[] {
  const installs = readSkillLog(ctx.employeeId, { action: "install" });
  const installed = new Set<string>();
  for (const record of installs) {
    if (record.success) {
      installed.add(record.skillId);
    }
  }

  // Also check CAPABILITIES.md for pre-installed skills
  const capPath = join(resolveEmployeeWorkspaceDir(ctx.employeeId), "CAPABILITIES.md");
  if (existsSync(capPath)) {
    const content = readFileSync(capPath, "utf-8");
    const preInstalledMatch = content.match(/## Pre-installed Skills\n([\s\S]*?)(?=\n##|\n$|$)/);
    if (preInstalledMatch) {
      const lines = preInstalledMatch[1].split("\n").filter((l) => l.startsWith("- "));
      for (const line of lines) {
        const skillId = line.replace(/^-\s*`?/, "").replace(/`?\s*$/, "").trim();
        if (skillId) installed.add(skillId);
      }
    }
  }

  return [...installed];
}

// --- Original parseSkillSearchOutput (commented out for security) ---
// /**
//  * Parse the output of `npx skills find <query>` into structured results.
//  * Handles various output formats from the skills.sh CLI.
//  */
// function parseSkillSearchOutput(output: string): SkillSearchResult[] {
//   const results: SkillSearchResult[] = [];
//   const lines = output.split("\n").filter((l) => l.trim().length > 0);
//   for (const line of lines) {
//     const match = line.match(/^(\S+\/\S+@\S+)\s/);
//     if (match) {
//       const skillId = match[1];
//       const parts = skillId.split("@");
//       const repo = parts[0] ?? "";
//       const name = parts[1] ?? skillId;
//       results.push({
//         skillId,
//         name,
//         repo,
//         url: `https://skills.sh/skills/${skillId}`,
//       });
//     }
//   }
//   return results;
// }
