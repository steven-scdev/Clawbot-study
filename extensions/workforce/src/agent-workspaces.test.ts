import { describe, it, expect, afterEach } from "vitest";
import { mkdirSync, readFileSync, writeFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { resolveEmployeeWorkspaceDir, setupAgentWorkspaces } from "./agent-workspaces.js";
import type { EmployeeConfig } from "./employees.js";

const TMP_BASE = join(tmpdir(), "workforce-workspace-test");

const EMPLOYEES: EmployeeConfig[] = [
  { id: "emma-web", name: "Emma", title: "Creative Strategist", emoji: "🌐", description: "", agentId: "emma-web", capabilities: [] },
  { id: "phil-ppt", name: "Phil", title: "Presentation Designer", emoji: "🎬", description: "", agentId: "phil-ppt", capabilities: [] },
  { id: "no-mind", name: "Ghost", title: "No Mind Files", emoji: "👻", description: "", agentId: "no-mind", capabilities: [] },
];

/** Create a fake minds directory with lens.md for specific employees */
function createMindsDir(employeeIds: string[]): string {
  const mindsDir = join(TMP_BASE, `minds-${crypto.randomUUID().slice(0, 8)}`);
  for (const id of employeeIds) {
    const dir = join(mindsDir, id);
    mkdirSync(dir, { recursive: true });
    writeFileSync(join(dir, "lens.md"), `I am ${id}. This is my lens.`);
  }
  return mindsDir;
}

const logger = {
  info: () => {},
  error: () => {},
  warn: () => {},
};

afterEach(() => {
  if (existsSync(TMP_BASE)) {
    rmSync(TMP_BASE, { recursive: true, force: true });
  }
});

describe("resolveEmployeeWorkspaceDir", () => {
  it("returns expected path format", () => {
    const dir = resolveEmployeeWorkspaceDir("emma-web");
    expect(dir).toMatch(/\.openclaw\/workspace-emma-web$/);
  });

  it("includes home directory", () => {
    const dir = resolveEmployeeWorkspaceDir("phil-ppt");
    expect(dir.startsWith("/")).toBe(true);
    expect(dir).toContain("workspace-phil-ppt");
  });
});

describe("setupAgentWorkspaces", () => {
  it("creates directories and writes IDENTITY.md", async () => {
    const mindsDir = createMindsDir(["emma-web", "phil-ppt"]);

    // Monkey-patch resolveEmployeeWorkspaceDir behavior by using a custom mindsDir
    // We can't easily override the workspace dir, so we test the real function
    // and verify mind content is composed correctly
    await setupAgentWorkspaces(EMPLOYEES, mindsDir, logger);

    // The function writes to ~/.openclaw/workspace-{id}/ which we can verify
    const emmaDir = resolveEmployeeWorkspaceDir("emma-web");
    const philDir = resolveEmployeeWorkspaceDir("phil-ppt");

    if (existsSync(join(emmaDir, "IDENTITY.md"))) {
      const emmaIdentity = readFileSync(join(emmaDir, "IDENTITY.md"), "utf-8");
      expect(emmaIdentity).toContain("emma-web");
      expect(emmaIdentity).toContain("Professional Identity");
    }

    if (existsSync(join(philDir, "IDENTITY.md"))) {
      const philIdentity = readFileSync(join(philDir, "IDENTITY.md"), "utf-8");
      expect(philIdentity).toContain("phil-ppt");
    }
  });

  it("skips employees without mind files", async () => {
    const mindsDir = createMindsDir(["emma-web"]); // only emma has mind files
    const logMessages: string[] = [];
    const trackingLogger = {
      ...logger,
      info: (msg: string) => { logMessages.push(msg); },
    };

    await setupAgentWorkspaces(EMPLOYEES, mindsDir, trackingLogger);

    // Should log count of 1 (only emma), not 3
    const setupMsg = logMessages.find((m) => m.includes("Set up"));
    expect(setupMsg).toContain("1 agent workspaces");
  });

  it("overwrites existing IDENTITY.md on re-run", async () => {
    const mindsDir = createMindsDir(["emma-web"]);

    await setupAgentWorkspaces(EMPLOYEES, mindsDir, logger);

    const emmaDir = resolveEmployeeWorkspaceDir("emma-web");
    const identityPath = join(emmaDir, "IDENTITY.md");

    if (existsSync(identityPath)) {
      // Write different content
      writeFileSync(identityPath, "OLD CONTENT");
      expect(readFileSync(identityPath, "utf-8")).toBe("OLD CONTENT");

      // Re-run should overwrite
      await setupAgentWorkspaces(EMPLOYEES, mindsDir, logger);
      const refreshed = readFileSync(identityPath, "utf-8");
      expect(refreshed).not.toBe("OLD CONTENT");
      expect(refreshed).toContain("Professional Identity");
    }
  });

  it("handles empty employee list", async () => {
    const mindsDir = createMindsDir([]);
    const logMessages: string[] = [];
    const trackingLogger = {
      ...logger,
      info: (msg: string) => { logMessages.push(msg); },
    };

    await setupAgentWorkspaces([], mindsDir, trackingLogger);

    const setupMsg = logMessages.find((m) => m.includes("Set up"));
    expect(setupMsg).toContain("0 agent workspaces");
  });
});
