import { describe, it, expect } from "vitest";
import { resolveMemorySearchConfig } from "../../../src/agents/memory-search.js";
import {
  resolveSessionAgentId,
  resolveAgentWorkspaceDir,
} from "../../../src/agents/agent-scope.js";
import { parseAgentSessionKey } from "../../../src/sessions/session-key-utils.js";
import type { OpenClawConfig } from "../../../src/config/config.js";
import { buildWorkforceSessionKey } from "./session-keys.js";

/**
 * These tests verify that workforce employees get proper memory tool support.
 *
 * Key invariants:
 * 1. Workforce session keys parse correctly to extract the employee agentId
 * 2. Memory search is enabled by default (even for employees not in agents.list)
 * 3. The workspace directory resolves to the employee-specific workspace
 */

describe("workforce memory tools integration", () => {
  describe("session key parsing", () => {
    it("extracts agentId from workforce session key", () => {
      const sessionKey = buildWorkforceSessionKey("sarah-research");
      const parsed = parseAgentSessionKey(sessionKey);

      expect(parsed).not.toBeNull();
      expect(parsed!.agentId).toBe("sarah-research");
      expect(parsed!.rest).toMatch(/^workforce-[a-f0-9]{8}$/);
    });

    it("resolves agentId from session key", () => {
      const sessionKey = buildWorkforceSessionKey("emma-web");
      const agentId = resolveSessionAgentId({ sessionKey });

      expect(agentId).toBe("emma-web");
    });
  });

  describe("memory search config", () => {
    it("enables memory search by default for unlisted agents", () => {
      // Empty config - no agents.list
      const cfg: OpenClawConfig = {};
      const resolved = resolveMemorySearchConfig(cfg, "sarah-research");

      expect(resolved).not.toBeNull();
      expect(resolved!.enabled).toBe(true);
    });

    it("enables memory search when only defaults are set", () => {
      const cfg: OpenClawConfig = {
        agents: {
          defaults: {
            memorySearch: {
              provider: "auto",
            },
          },
        },
      };
      const resolved = resolveMemorySearchConfig(cfg, "sarah-research");

      expect(resolved).not.toBeNull();
      expect(resolved!.enabled).toBe(true);
      expect(resolved!.provider).toBe("auto");
    });

    it("uses employee-specific store path", () => {
      const cfg: OpenClawConfig = {};
      const resolved = resolveMemorySearchConfig(cfg, "sarah-research");

      expect(resolved).not.toBeNull();
      expect(resolved!.store.path).toContain("sarah-research");
    });
  });

  describe("workspace directory resolution", () => {
    it("resolves employee workspace directory", () => {
      const cfg: OpenClawConfig = {};
      const workspace = resolveAgentWorkspaceDir(cfg, "sarah-research");

      expect(workspace).toMatch(/\.openclaw\/workspace-sarah-research$/);
    });

    it("uses session key to resolve workspace", () => {
      const sessionKey = buildWorkforceSessionKey("emma-web");
      const agentId = resolveSessionAgentId({ sessionKey });
      const workspace = resolveAgentWorkspaceDir({}, agentId);

      expect(workspace).toMatch(/\.openclaw\/workspace-emma-web$/);
    });
  });

  describe("end-to-end workforce memory flow", () => {
    it("resolves memory config from workforce session key", () => {
      // Simulate what happens when a workforce employee session starts
      const employeeId = "sarah-research";
      const sessionKey = buildWorkforceSessionKey(employeeId);

      // Step 1: Parse session key
      const parsed = parseAgentSessionKey(sessionKey);
      expect(parsed).not.toBeNull();
      expect(parsed!.agentId).toBe(employeeId);

      // Step 2: Resolve agentId for tool creation
      const agentId = resolveSessionAgentId({ sessionKey });
      expect(agentId).toBe(employeeId);

      // Step 3: Check memory search is enabled (this is what createMemorySearchTool does)
      const cfg: OpenClawConfig = {};
      const memoryConfig = resolveMemorySearchConfig(cfg, agentId);
      expect(memoryConfig).not.toBeNull();
      expect(memoryConfig!.enabled).toBe(true);

      // Step 4: Verify workspace for memory files
      const workspace = resolveAgentWorkspaceDir(cfg, agentId);
      expect(workspace).toContain(`workspace-${employeeId}`);
    });
  });
});
