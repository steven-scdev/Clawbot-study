import { describe, expect, it } from "vitest";
import {
  buildWorkforceSessionKey,
  parseWorkforceSessionKey,
  isWorkforceSession,
  isWorkforceSessionKey,
} from "./session-keys.js";
import type { EmployeeConfig } from "./employees.js";

const EMPLOYEES: EmployeeConfig[] = [
  { id: "emma-web", name: "Emma", title: "Creative Strategist", emoji: "🌐", description: "", agentId: "emma-web", capabilities: [] },
  { id: "phil-ppt", name: "Phil", title: "Presentation Designer", emoji: "🎬", description: "", agentId: "phil-ppt", capabilities: [] },
];

describe("buildWorkforceSessionKey", () => {
  it("produces agent-prefixed format", () => {
    const key = buildWorkforceSessionKey("emma-web");
    expect(key).toMatch(/^agent:emma-web:workforce-[a-f0-9]{8}$/);
  });

  it("uses employee id as agent id", () => {
    const key = buildWorkforceSessionKey("phil-ppt");
    expect(key.startsWith("agent:phil-ppt:")).toBe(true);
  });
});

describe("parseWorkforceSessionKey", () => {
  it("parses valid key", () => {
    const result = parseWorkforceSessionKey("agent:emma-web:workforce-abc12345");
    expect(result).toEqual({ agentId: "emma-web", tag: "workforce-abc12345" });
  });

  it("returns null for old format", () => {
    expect(parseWorkforceSessionKey("workforce-emma-web-abc12345")).toBeNull();
  });

  it("returns null for undefined", () => {
    expect(parseWorkforceSessionKey(undefined)).toBeNull();
  });

  it("returns null for empty string", () => {
    expect(parseWorkforceSessionKey("")).toBeNull();
  });

  it("returns null for non-workforce agent key", () => {
    expect(parseWorkforceSessionKey("agent:main:chat-abc")).toBeNull();
  });
});

describe("isWorkforceSession", () => {
  it("validates against employee list", () => {
    expect(isWorkforceSession("agent:emma-web:workforce-abc12345", EMPLOYEES)).toBe(true);
  });

  it("rejects unknown agent ids", () => {
    expect(isWorkforceSession("agent:unknown:workforce-abc12345", EMPLOYEES)).toBe(false);
  });

  it("rejects old format", () => {
    expect(isWorkforceSession("workforce-emma-web-abc12345", EMPLOYEES)).toBe(false);
  });

  it("rejects undefined", () => {
    expect(isWorkforceSession(undefined, EMPLOYEES)).toBe(false);
  });
});

describe("isWorkforceSessionKey", () => {
  it("checks format only without employee list", () => {
    expect(isWorkforceSessionKey("agent:any-id:workforce-abc12345")).toBe(true);
  });

  it("rejects non-workforce agent keys", () => {
    expect(isWorkforceSessionKey("agent:main:chat-abc")).toBe(false);
  });

  it("rejects old format", () => {
    expect(isWorkforceSessionKey("workforce-emma-web-abc")).toBe(false);
  });

  it("rejects undefined", () => {
    expect(isWorkforceSessionKey(undefined)).toBe(false);
  });
});
