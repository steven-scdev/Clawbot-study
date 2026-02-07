import {
  writeFileSync,
  readFileSync,
  existsSync,
} from "node:fs";
import { join } from "node:path";
import { resolveEmployeeWorkspaceDir } from "./agent-workspaces.js";

const CAPABILITIES_FILENAME = "CAPABILITIES.md";

type CapabilitySections = {
  role: string;
  preInstalledSkills: string[];
  acquiredSkills: Array<{ skillId: string; installedAt: string; context?: string }>;
  domainExperience: Map<string, number>;
  references: string[];
};

/**
 * Update (or create) CAPABILITIES.md for an employee.
 * Merges new data into existing sections.
 */
export function updateCapabilities(
  employeeId: string,
  opts: {
    role?: string;
    preInstalledSkills?: string[];
  },
): void {
  const existing = readCapabilities(employeeId);

  if (opts.role) {
    existing.role = opts.role;
  }
  if (opts.preInstalledSkills) {
    // Merge without duplicates
    const all = new Set([...existing.preInstalledSkills, ...opts.preInstalledSkills]);
    existing.preInstalledSkills = [...all];
  }

  writeCapabilities(employeeId, existing);
}

/**
 * Read and parse CAPABILITIES.md into structured sections.
 */
export function readCapabilities(employeeId: string): CapabilitySections {
  const capPath = join(resolveEmployeeWorkspaceDir(employeeId), CAPABILITIES_FILENAME);

  if (!existsSync(capPath)) {
    return {
      role: "",
      preInstalledSkills: [],
      acquiredSkills: [],
      domainExperience: new Map(),
      references: [],
    };
  }

  const content = readFileSync(capPath, "utf-8");
  return parseCapabilities(content);
}

/**
 * Add an acquired skill to the employee's CAPABILITIES.md.
 * Deduplicates by skillId.
 */
export function addAcquiredSkill(
  employeeId: string,
  skillId: string,
  context?: string,
): void {
  const sections = readCapabilities(employeeId);

  // Deduplicate
  if (sections.acquiredSkills.some((s) => s.skillId === skillId)) {
    return;
  }

  sections.acquiredSkills.push({
    skillId,
    installedAt: new Date().toISOString(),
    context,
  });

  writeCapabilities(employeeId, sections);
}

/**
 * Increment the task count for a domain in the employee's experience.
 */
export function addDomainExperience(
  employeeId: string,
  domain: string,
): void {
  const sections = readCapabilities(employeeId);
  const current = sections.domainExperience.get(domain) ?? 0;
  sections.domainExperience.set(domain, current + 1);
  writeCapabilities(employeeId, sections);
}

function writeCapabilities(employeeId: string, sections: CapabilitySections): void {
  const capPath = join(resolveEmployeeWorkspaceDir(employeeId), CAPABILITIES_FILENAME);
  const content = buildCapabilitiesContent(sections, employeeId);
  writeFileSync(capPath, content, "utf-8");
}

function buildCapabilitiesContent(sections: CapabilitySections, employeeId: string): string {
  const parts: string[] = [];

  parts.push(`# ${employeeId} Capabilities\n`);
  parts.push(`*Auto-maintained profile — updated after skill installs and task completion.*\n`);

  if (sections.role) {
    parts.push(`## Role\n`);
    parts.push(sections.role);
    parts.push("");
  }

  parts.push(`## Pre-installed Skills\n`);
  if (sections.preInstalledSkills.length > 0) {
    for (const skill of sections.preInstalledSkills) {
      parts.push(`- \`${skill}\``);
    }
  } else {
    parts.push("*None*");
  }
  parts.push("");

  parts.push(`## Acquired Skills\n`);
  if (sections.acquiredSkills.length > 0) {
    for (const skill of sections.acquiredSkills) {
      const date = skill.installedAt.slice(0, 10);
      const ctx = skill.context ? ` — ${skill.context}` : "";
      parts.push(`- \`${skill.skillId}\` (${date}${ctx})`);
    }
  } else {
    parts.push("*None yet — skills are acquired dynamically as needed.*");
  }
  parts.push("");

  if (sections.domainExperience.size > 0) {
    parts.push(`## Domain Experience\n`);
    const sorted = [...sections.domainExperience.entries()].sort((a, b) => b[1] - a[1]);
    for (const [domain, count] of sorted) {
      parts.push(`- ${domain}: ${count} task${count !== 1 ? "s" : ""}`);
    }
    parts.push("");
  }

  if (sections.references.length > 0) {
    parts.push(`## Reference Documents\n`);
    for (const ref of sections.references) {
      parts.push(`- ${ref}`);
    }
    parts.push("");
  }

  return parts.join("\n");
}

function parseCapabilities(content: string): CapabilitySections {
  const sections: CapabilitySections = {
    role: "",
    preInstalledSkills: [],
    acquiredSkills: [],
    domainExperience: new Map(),
    references: [],
  };

  // Parse ## Role
  const roleMatch = content.match(/## Role\n([\s\S]*?)(?=\n## |$)/);
  if (roleMatch) {
    sections.role = roleMatch[1].trim();
  }

  // Parse ## Pre-installed Skills
  const preMatch = content.match(/## Pre-installed Skills\n([\s\S]*?)(?=\n## |$)/);
  if (preMatch) {
    const lines = preMatch[1].split("\n").filter((l) => l.startsWith("- "));
    sections.preInstalledSkills = lines.map((l) =>
      l.replace(/^-\s*`?/, "").replace(/`?\s*$/, "").trim(),
    );
  }

  // Parse ## Acquired Skills
  const acqMatch = content.match(/## Acquired Skills\n([\s\S]*?)(?=\n## |$)/);
  if (acqMatch) {
    const lines = acqMatch[1].split("\n").filter((l) => l.startsWith("- "));
    for (const line of lines) {
      const skillMatch = line.match(/`([^`]+)`\s*\((\d{4}-\d{2}-\d{2})(?:\s*—\s*(.+))?\)/);
      if (skillMatch) {
        sections.acquiredSkills.push({
          skillId: skillMatch[1],
          installedAt: skillMatch[2],
          context: skillMatch[3]?.trim(),
        });
      }
    }
  }

  // Parse ## Domain Experience
  const domMatch = content.match(/## Domain Experience\n([\s\S]*?)(?=\n## |$)/);
  if (domMatch) {
    const lines = domMatch[1].split("\n").filter((l) => l.startsWith("- "));
    for (const line of lines) {
      const expMatch = line.match(/- (.+?):\s*(\d+)\s*task/);
      if (expMatch) {
        sections.domainExperience.set(expMatch[1], parseInt(expMatch[2], 10));
      }
    }
  }

  // Parse ## Reference Documents
  const refMatch = content.match(/## Reference Documents\n([\s\S]*?)(?=\n## |$)/);
  if (refMatch) {
    const lines = refMatch[1].split("\n").filter((l) => l.startsWith("- "));
    sections.references = lines.map((l) => l.replace(/^-\s*/, "").trim());
  }

  return sections;
}
