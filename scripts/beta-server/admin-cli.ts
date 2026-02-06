#!/usr/bin/env bun
/**
 * Beta License Admin CLI
 * Manage licenses from your terminal
 *
 * Usage:
 *   export BETA_ADMIN_SECRET="your-admin-secret"
 *   export BETA_SERVER_URL="https://your-worker.workers.dev"
 *
 *   bun admin-cli.ts list                              # List all licenses
 *   bun admin-cli.ts create alice@test.com "Alice"     # Create license
 *   bun admin-cli.ts create bob@test.com "Bob" 500000  # Create with 500k credits
 *   bun admin-cli.ts revoke beta-abc123                # Revoke license
 *   bun admin-cli.ts status                            # Summary dashboard
 */

const SERVER_URL = process.env.BETA_SERVER_URL || "https://your-worker.workers.dev";
const ADMIN_SECRET = process.env.BETA_ADMIN_SECRET;

if (!ADMIN_SECRET) {
  console.error("❌ Set BETA_ADMIN_SECRET environment variable");
  process.exit(1);
}

interface License {
  key: string;
  email: string;
  name: string;
  creditsTotal: number;
  creditsUsed: number;
  active: boolean;
  createdAt: number;
  expiresAt: number;
  lastSeen?: number;
}

async function apiCall(path: string, method: string = "GET", body?: object): Promise<unknown> {
  const response = await fetch(`${SERVER_URL}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${ADMIN_SECRET}`,
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`API error (${response.status}): ${error}`);
  }

  return response.json();
}

async function listLicenses(): Promise<void> {
  const data = await apiCall("/admin/licenses") as { licenses: License[] };

  console.log("\n📋 Beta Licenses");
  console.log("═".repeat(80));

  if (data.licenses.length === 0) {
    console.log("No licenses found");
    return;
  }

  for (const license of data.licenses) {
    const creditsPercent = ((license.creditsUsed / license.creditsTotal) * 100).toFixed(1);
    const status = !license.active ? "❌ REVOKED" :
                   Date.now() > license.expiresAt ? "⏰ EXPIRED" :
                   license.creditsUsed >= license.creditsTotal ? "🚫 EXHAUSTED" :
                   "✅ ACTIVE";

    const lastSeen = license.lastSeen
      ? `${Math.round((Date.now() - license.lastSeen) / 60000)}m ago`
      : "never";

    console.log(`
┌─ ${license.key} ─────────────────────────────────
│ Name:    ${license.name} <${license.email}>
│ Status:  ${status}
│ Credits: ${license.creditsUsed.toLocaleString()} / ${license.creditsTotal.toLocaleString()} (${creditsPercent}%)
│ Expires: ${new Date(license.expiresAt).toLocaleDateString()}
│ Last seen: ${lastSeen}
└${"─".repeat(50)}`);
  }
}

async function createLicense(email: string, name: string, credits?: number, days?: number): Promise<void> {
  const data = await apiCall("/admin/licenses", "POST", {
    email,
    name,
    credits: credits || 100000,
    expiresInDays: days || 7,
  }) as { license: License };

  console.log("\n✅ License created!");
  console.log("═".repeat(50));
  console.log(`Key:       ${data.license.key}`);
  console.log(`Name:      ${data.license.name}`);
  console.log(`Email:     ${data.license.email}`);
  console.log(`Credits:   ${data.license.creditsTotal.toLocaleString()} tokens`);
  console.log(`Expires:   ${new Date(data.license.expiresAt).toLocaleDateString()}`);
  console.log("");
  console.log("📧 Send this to the user:");
  console.log("─".repeat(50));
  console.log(`
Hi ${name},

Your OpenClaw Workforce beta access is ready!

1. Download the installer:
   curl -fsSL https://your-server.com/beta-install.sh | bash

2. Activate with your license key:
   openclaw-beta activate ${data.license.key}

3. Start the gateway:
   openclaw gateway run

Your license includes ${data.license.creditsTotal.toLocaleString()} tokens and expires on ${new Date(data.license.expiresAt).toLocaleDateString()}.

Questions? Reply to this email.
`);
}

async function revokeLicense(licenseKey: string): Promise<void> {
  await apiCall("/admin/revoke", "POST", { licenseKey });
  console.log(`\n✅ License ${licenseKey} has been revoked`);
  console.log("   The user will be disconnected on next heartbeat (within 5 minutes)");
}

async function showStatus(): Promise<void> {
  const data = await apiCall("/admin/licenses") as { licenses: License[] };

  const total = data.licenses.length;
  const active = data.licenses.filter(l => l.active && Date.now() < l.expiresAt).length;
  const totalCreditsUsed = data.licenses.reduce((sum, l) => sum + l.creditsUsed, 0);
  const totalCreditsAllocated = data.licenses.reduce((sum, l) => sum + l.creditsTotal, 0);

  // Estimate cost (Sonnet 4.5 pricing)
  const estimatedCost = (totalCreditsUsed / 1_000_000) * 9; // ~$9 per 1M tokens average

  console.log("\n📊 Beta Dashboard");
  console.log("═".repeat(50));
  console.log(`Licenses:        ${active} active / ${total} total`);
  console.log(`Tokens used:     ${(totalCreditsUsed / 1000).toFixed(1)}k / ${(totalCreditsAllocated / 1000).toFixed(1)}k`);
  console.log(`Est. API cost:   $${estimatedCost.toFixed(2)}`);
  console.log(`Actual cost:     $0 (using OAuth subscription)`);
  console.log("");

  // Recent activity
  const recentlyActive = data.licenses
    .filter(l => l.lastSeen && Date.now() - l.lastSeen < 24 * 60 * 60 * 1000)
    .sort((a, b) => (b.lastSeen || 0) - (a.lastSeen || 0));

  if (recentlyActive.length > 0) {
    console.log("Recent activity (last 24h):");
    for (const l of recentlyActive.slice(0, 5)) {
      const ago = Math.round((Date.now() - (l.lastSeen || 0)) / 60000);
      console.log(`  • ${l.name}: ${ago}m ago (${l.creditsUsed.toLocaleString()} tokens used)`);
    }
  }
}

// Main CLI
const command = process.argv[2];

switch (command) {
  case "list":
    await listLicenses();
    break;

  case "create":
    const email = process.argv[3];
    const name = process.argv[4];
    const credits = process.argv[5] ? parseInt(process.argv[5]) : undefined;
    const days = process.argv[6] ? parseInt(process.argv[6]) : undefined;

    if (!email || !name) {
      console.error("Usage: admin-cli.ts create <email> <name> [credits] [days]");
      process.exit(1);
    }
    await createLicense(email, name, credits, days);
    break;

  case "revoke":
    const licenseKey = process.argv[3];
    if (!licenseKey) {
      console.error("Usage: admin-cli.ts revoke <license-key>");
      process.exit(1);
    }
    await revokeLicense(licenseKey);
    break;

  case "status":
    await showStatus();
    break;

  default:
    console.log(`
Beta License Admin CLI

Commands:
  list                                    List all licenses
  create <email> <name> [credits] [days]  Create new license
  revoke <license-key>                    Revoke a license
  status                                  Show dashboard

Environment:
  BETA_SERVER_URL     Your Cloudflare Worker URL
  BETA_ADMIN_SECRET   Admin API key

Examples:
  bun admin-cli.ts create alice@test.com "Alice" 100000 7
  bun admin-cli.ts revoke beta-abc123
`);
}
