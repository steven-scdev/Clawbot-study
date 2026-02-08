import {
  copyFileSync,
  writeFileSync,
  readFileSync,
  readdirSync,
  unlinkSync,
  existsSync,
  mkdirSync,
  statSync,
} from "node:fs";
import { join, basename, extname } from "node:path";
import { resolveEmployeeWorkspaceDir } from "./agent-workspaces.js";

/**
 * Metadata record for a user-provided reference document.
 * Stored as JSON in workspace-{employeeId}/references/ref-{id}.json.
 */
export type ReferenceDoc = {
  id: string;
  originalName: string;
  addedAt: string;
  addedVia: "chat" | "api" | "manual";
  type: "template" | "example" | "style-guide" | "reference";
  digest: string;
  tags: string[];
  fileSize: number;
};

type AddReferenceOpts = {
  addedVia?: ReferenceDoc["addedVia"];
  type?: ReferenceDoc["type"];
  tags?: string[];
};

function refsDir(employeeId: string): string {
  return join(resolveEmployeeWorkspaceDir(employeeId), "references");
}

function originalsDir(employeeId: string): string {
  return join(refsDir(employeeId), "originals");
}

function generateRefId(): string {
  return `ref-${crypto.randomUUID().slice(0, 8)}`;
}

/**
 * Build a simple digest from the filename and size.
 * In the future this could use an LLM to summarize file contents.
 */
function buildDigest(originalName: string, fileSize: number): string {
  const ext = extname(originalName).replace(".", "").toUpperCase() || "FILE";
  const sizeKB = Math.round(fileSize / 1024);
  return `${ext} file "${originalName}" (${sizeKB} KB)`;
}

/**
 * Copy a file into the employee's reference store and create metadata.
 * Returns the created ReferenceDoc.
 */
export function addReference(
  employeeId: string,
  filePath: string,
  opts: AddReferenceOpts = {},
): ReferenceDoc {
  const id = generateRefId();
  const originalName = basename(filePath);
  const ext = extname(originalName);

  // Ensure directories exist
  const origDir = originalsDir(employeeId);
  mkdirSync(origDir, { recursive: true });

  // Copy the original file
  const destPath = join(origDir, `${id}${ext}`);
  copyFileSync(filePath, destPath);

  const stat = statSync(destPath);

  const doc: ReferenceDoc = {
    id,
    originalName,
    addedAt: new Date().toISOString(),
    addedVia: opts.addedVia ?? "chat",
    type: opts.type ?? "reference",
    digest: buildDigest(originalName, stat.size),
    tags: opts.tags ?? [],
    fileSize: stat.size,
  };

  // Write metadata JSON
  const metadataPath = join(refsDir(employeeId), `${id}.json`);
  writeFileSync(metadataPath, JSON.stringify(doc, null, 2));

  return doc;
}

/**
 * List all reference documents for an employee, sorted by addedAt DESC.
 */
export function listReferences(employeeId: string): ReferenceDoc[] {
  const dir = refsDir(employeeId);
  if (!existsSync(dir)) return [];

  const files = readdirSync(dir).filter(
    (f) => f.endsWith(".json") && f.startsWith("ref-"),
  );

  const docs: ReferenceDoc[] = [];
  for (const file of files) {
    try {
      const content = readFileSync(join(dir, file), "utf-8");
      docs.push(JSON.parse(content) as ReferenceDoc);
    } catch {
      // Skip malformed files
    }
  }

  return docs.sort(
    (a, b) => new Date(b.addedAt).getTime() - new Date(a.addedAt).getTime(),
  );
}

/**
 * Get a single reference document by ID.
 */
export function getReference(
  employeeId: string,
  refId: string,
): ReferenceDoc | null {
  const metadataPath = join(refsDir(employeeId), `${refId}.json`);
  if (!existsSync(metadataPath)) return null;
  try {
    const content = readFileSync(metadataPath, "utf-8");
    return JSON.parse(content) as ReferenceDoc;
  } catch {
    return null;
  }
}

/**
 * Remove a reference: deletes both the metadata JSON and the original file.
 */
export function removeReference(employeeId: string, refId: string): boolean {
  const metadataPath = join(refsDir(employeeId), `${refId}.json`);
  if (!existsSync(metadataPath)) return false;

  // Read metadata to find the original file extension
  let doc: ReferenceDoc | null = null;
  try {
    doc = JSON.parse(readFileSync(metadataPath, "utf-8")) as ReferenceDoc;
  } catch {
    // proceed with metadata deletion anyway
  }

  // Delete metadata
  unlinkSync(metadataPath);

  // Delete original file (try all common extensions if doc parsing failed)
  if (doc) {
    const ext = extname(doc.originalName);
    const origPath = join(originalsDir(employeeId), `${refId}${ext}`);
    if (existsSync(origPath)) {
      unlinkSync(origPath);
    }
  }

  return true;
}

const IMAGE_EXTS = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".tiff", ".tif", ".heic", ".heif"]);

/**
 * Build a markdown section listing all references for context injection.
 * Image references also emit `[media attached: /absolute/path]` tags so
 * the Pi agent framework's native image detection loads them as multimodal
 * content blocks (Claude vision) automatically.
 * Returns empty string if no references exist.
 */
export function formatReferencesForPrompt(employeeId: string): string {
  const docs = listReferences(employeeId);
  if (docs.length === 0) return "";

  const origDir = originalsDir(employeeId);
  const mediaLines: string[] = [];
  const lines = ["## Reference Documents\n"];
  for (const doc of docs) {
    const tagsStr = doc.tags.length > 0 ? ` [${doc.tags.join(", ")}]` : "";
    lines.push(`- **${doc.originalName}** (${doc.type}): ${doc.digest}${tagsStr}`);
    const ext = extname(doc.originalName).toLowerCase();
    if (IMAGE_EXTS.has(ext)) {
      const absPath = join(origDir, `${doc.id}${extname(doc.originalName)}`);
      mediaLines.push(`[media attached: ${absPath} (${doc.digest})]`);
    }
  }
  lines.push("");
  if (mediaLines.length > 0) {
    lines.push(...mediaLines, "");
  }
  return lines.join("\n");
}
