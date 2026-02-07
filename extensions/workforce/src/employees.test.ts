import { describe, it, expect } from "vitest";
import { resolveEmployees, buildEmployeeList, type EmployeeConfig } from "./employees.js";

describe("resolveEmployees", () => {
  it("returns default employees when no config", () => {
    const result = resolveEmployees(undefined);
    expect(result).toHaveLength(4);
    expect(result[0].id).toBe("emma-web");
  });

  it("returns default employees when config has empty array", () => {
    const result = resolveEmployees({ employees: [] });
    expect(result).toHaveLength(4);
  });

  it("returns custom employees when provided", () => {
    const custom: EmployeeConfig[] = [
      {
        id: "test-1",
        name: "Test",
        title: "Tester",
        emoji: "T",
        description: "Testing",
        agentId: "test-1",
        capabilities: ["testing"],
      },
    ];
    const result = resolveEmployees({ employees: custom });
    expect(result).toHaveLength(1);
    expect(result[0].id).toBe("test-1");
  });
});

describe("buildEmployeeList", () => {
  const employees: EmployeeConfig[] = [
    {
      id: "emma-web",
      name: "Emma",
      title: "Creative Strategist",
      emoji: "G",
      description: "Creates websites",
      agentId: "emma-web",
      capabilities: ["Web Design"],
    },
  ];

  it("maps config to response shape", () => {
    const list = buildEmployeeList(employees);
    expect(list).toHaveLength(1);
    expect(list[0]).toEqual({
      id: "emma-web",
      name: "Emma",
      title: "Creative Strategist",
      emoji: "G",
      description: "Creates websites",
      capabilities: ["Web Design"],
      status: "online",
      currentTaskId: null,
      avatarSystemName: "person.circle.fill",
      preInstalledSkills: [],
    });
  });

  it("defaults avatarSystemName when not provided", () => {
    const list = buildEmployeeList(employees);
    expect(list[0].avatarSystemName).toBe("person.circle.fill");
  });

  it("uses custom avatarSystemName when provided", () => {
    const withAvatar = [{ ...employees[0], avatarSystemName: "star.circle" }];
    const list = buildEmployeeList(withAvatar);
    expect(list[0].avatarSystemName).toBe("star.circle");
  });
});
