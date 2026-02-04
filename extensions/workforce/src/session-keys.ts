import type { EmployeeConfig } from "./employees.js";

/**
 * Parse a workforce session key in the multi-agent format `agent:{agentId}:workforce-{tag}`.
 * Returns null for keys that don't match the expected pattern.
 * Re-implements the trivial parsing inline since plugins can't import from core src/.
 */
export function parseWorkforceSessionKey(
  sessionKey: string | undefined,
): { agentId: string; tag: string } | null {
  if (!sessionKey) return null;
  const parts = sessionKey.split(":");
  if (parts.length < 3 || parts[0] !== "agent") return null;
  const agentId = parts[1]?.trim();
  const rest = parts.slice(2).join(":");
  if (!agentId || !rest.startsWith("workforce")) return null;
  return { agentId, tag: rest };
}

/**
 * Build a session key that routes to the employee's dedicated agent workspace.
 * Format: `agent:{employeeId}:workforce-{uuid}` — parsed by OpenClaw's
 * `parseAgentSessionKey()` to resolve workspace `~/.openclaw/workspace-{employeeId}/`.
 */
export function buildWorkforceSessionKey(employeeId: string): string {
  return `agent:${employeeId}:workforce-${crypto.randomUUID().slice(0, 8)}`;
}

/**
 * Strict check: session key is a valid workforce key AND the agentId matches
 * a known employee. Used by hooks in index.ts.
 */
export function isWorkforceSession(
  sessionKey: string | undefined,
  employees: EmployeeConfig[],
): boolean {
  const parsed = parseWorkforceSessionKey(sessionKey);
  if (!parsed) return false;
  return employees.some((e) => e.id === parsed.agentId);
}

/**
 * Format-only check: session key matches the `agent:*:workforce-*` pattern.
 * Does not validate against the employee roster. Used by event-bridge.ts
 * as a fast-path filter before the task-store lookup.
 */
export function isWorkforceSessionKey(sessionKey: string | undefined): boolean {
  return parseWorkforceSessionKey(sessionKey) !== null;
}
