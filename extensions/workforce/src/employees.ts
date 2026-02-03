import { isEmployeeBusy, getActiveTaskForEmployee } from "./task-store.js";

export type EmployeeConfig = {
  id: string;
  name: string;
  title: string;
  emoji: string;
  description: string;
  agentId: string;
  capabilities: string[];
  avatarSystemName?: string;
};

/** Default employees used when no config is provided. */
const DEFAULT_EMPLOYEES: EmployeeConfig[] = [
  {
    id: "emma-web",
    name: "Emma",
    title: "Creative Strategist",
    emoji: "\u{1F310}",
    description: "Creates professional websites and landing pages",
    agentId: "emma-web",
    capabilities: ["Trend Analysis", "Copywriting", "Web Design", "React"],
  },
  {
    id: "david-decks",
    name: "David",
    title: "Data Analyst",
    emoji: "\u{1F4CA}",
    description: "Creates professional presentation decks and data visualizations",
    agentId: "david-decks",
    capabilities: ["Data Visualization", "Complex Modeling", "Presentations"],
  },
  {
    id: "sarah-research",
    name: "Sarah",
    title: "Senior Engineer",
    emoji: "\u{1F50D}",
    description: "Deep research, system design, and full stack development",
    agentId: "sarah-research",
    capabilities: ["Full Stack Dev", "System Design", "Research"],
  },
];

export function resolveEmployees(pluginConfig: Record<string, unknown> | undefined): EmployeeConfig[] {
  const raw = pluginConfig?.employees;
  if (Array.isArray(raw) && raw.length > 0) {
    return raw as EmployeeConfig[];
  }
  return DEFAULT_EMPLOYEES;
}

export function buildEmployeeList(employees: EmployeeConfig[]) {
  return employees.map((emp) => {
    const busy = isEmployeeBusy(emp.id);
    const activeTask = busy ? getActiveTaskForEmployee(emp.id) : null;
    return {
      id: emp.id,
      name: emp.name,
      title: emp.title,
      emoji: emp.emoji,
      description: emp.description,
      capabilities: emp.capabilities,
      status: busy ? "busy" : "online",
      currentTaskId: activeTask?.id ?? null,
      avatarSystemName: emp.avatarSystemName ?? "person.circle.fill",
    };
  });
}
