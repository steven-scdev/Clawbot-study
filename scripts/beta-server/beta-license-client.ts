/**
 * Beta License Client
 * Integrates with OpenClaw to validate licenses and report usage
 *
 * This can be:
 * 1. Integrated directly into OpenClaw as a hook
 * 2. Run as a background service
 * 3. Called from the beta installer
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Configuration
const LICENSE_SERVER_URL = process.env.BETA_LICENSE_SERVER || "https://your-worker.workers.dev";
const HEARTBEAT_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes
const USAGE_REPORT_INTERVAL_MS = 60 * 1000; // 1 minute

interface BetaConfig {
  licenseKey: string;
  serverUrl: string;
  lastValidated?: number;
  creditsRemaining?: number;
  expiresAt?: number;
}

interface Credentials {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
}

interface UsageAccumulator {
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  lastReported: number;
}

const OPENCLAW_DIR = join(homedir(), ".openclaw");
const BETA_CONFIG_PATH = join(OPENCLAW_DIR, "beta-license.json");
const AUTH_PROFILES_PATH = join(OPENCLAW_DIR, "agents", "main", "auth-profiles.json");

let usageAccumulator: UsageAccumulator = {
  inputTokens: 0,
  outputTokens: 0,
  cacheReadTokens: 0,
  cacheWriteTokens: 0,
  lastReported: Date.now(),
};

// Load beta configuration
function loadBetaConfig(): BetaConfig | null {
  if (!existsSync(BETA_CONFIG_PATH)) return null;
  try {
    return JSON.parse(readFileSync(BETA_CONFIG_PATH, "utf-8"));
  } catch {
    return null;
  }
}

// Save beta configuration
function saveBetaConfig(config: BetaConfig): void {
  mkdirSync(OPENCLAW_DIR, { recursive: true });
  writeFileSync(BETA_CONFIG_PATH, JSON.stringify(config, null, 2));
}

// Save credentials to OpenClaw auth profiles
function saveCredentials(credentials: Credentials): void {
  const agentDir = join(OPENCLAW_DIR, "agents", "main");
  mkdirSync(agentDir, { recursive: true });

  const authProfiles = {
    profiles: {
      "anthropic:beta-licensed": {
        type: "oauth",
        provider: "anthropic",
        access: credentials.accessToken,
        refresh: credentials.refreshToken,
        expires: credentials.expiresAt,
        email: "licensed-beta@openclaw.ai",
      },
    },
    order: {
      anthropic: ["anthropic:beta-licensed"],
    },
  };

  writeFileSync(AUTH_PROFILES_PATH, JSON.stringify(authProfiles, null, 2));
}

// Clear credentials (when license is revoked)
function clearCredentials(): void {
  if (existsSync(AUTH_PROFILES_PATH)) {
    writeFileSync(AUTH_PROFILES_PATH, JSON.stringify({ profiles: {}, order: {} }, null, 2));
  }
}

// Validate license with server
export async function validateLicense(licenseKey: string): Promise<{
  valid: boolean;
  error?: string;
  creditsRemaining?: number;
}> {
  const config = loadBetaConfig() || {
    licenseKey,
    serverUrl: LICENSE_SERVER_URL,
  };

  try {
    const response = await fetch(`${config.serverUrl}/validate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ licenseKey }),
    });

    const data = await response.json() as {
      valid: boolean;
      error?: string;
      credentials?: Credentials;
      license?: {
        creditsRemaining: number;
        creditsTotal: number;
        expiresAt: number;
      };
    };

    if (!data.valid) {
      clearCredentials();
      return { valid: false, error: data.error };
    }

    // Save credentials locally
    if (data.credentials) {
      saveCredentials(data.credentials);
    }

    // Update config
    config.lastValidated = Date.now();
    config.creditsRemaining = data.license?.creditsRemaining;
    config.expiresAt = data.license?.expiresAt;
    saveBetaConfig(config);

    console.log(`✅ License validated. Credits remaining: ${data.license?.creditsRemaining}`);

    return {
      valid: true,
      creditsRemaining: data.license?.creditsRemaining,
    };

  } catch (error) {
    console.error("❌ Failed to validate license:", error);
    return { valid: false, error: "Network error - could not reach license server" };
  }
}

// Report usage to server
export async function reportUsage(usage: Partial<UsageAccumulator>): Promise<{
  accepted: boolean;
  overLimit?: boolean;
  creditsRemaining?: number;
}> {
  const config = loadBetaConfig();
  if (!config) {
    return { accepted: false };
  }

  // Accumulate usage
  usageAccumulator.inputTokens += usage.inputTokens || 0;
  usageAccumulator.outputTokens += usage.outputTokens || 0;
  usageAccumulator.cacheReadTokens += usage.cacheReadTokens || 0;
  usageAccumulator.cacheWriteTokens += usage.cacheWriteTokens || 0;

  // Only report periodically to avoid too many requests
  if (Date.now() - usageAccumulator.lastReported < USAGE_REPORT_INTERVAL_MS) {
    return { accepted: true };
  }

  try {
    const response = await fetch(`${config.serverUrl}/usage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        licenseKey: config.licenseKey,
        ...usageAccumulator,
      }),
    });

    const data = await response.json() as {
      accepted: boolean;
      creditsRemaining: number;
      overLimit: boolean;
      active: boolean;
    };

    // Reset accumulator
    usageAccumulator = {
      inputTokens: 0,
      outputTokens: 0,
      cacheReadTokens: 0,
      cacheWriteTokens: 0,
      lastReported: Date.now(),
    };

    // Update local config
    config.creditsRemaining = data.creditsRemaining;
    saveBetaConfig(config);

    if (data.overLimit || !data.active) {
      console.log("⚠️ License credits exhausted or revoked");
      clearCredentials();
      return { accepted: false, overLimit: true, creditsRemaining: 0 };
    }

    return {
      accepted: true,
      creditsRemaining: data.creditsRemaining,
    };

  } catch (error) {
    console.error("Failed to report usage:", error);
    // Don't fail hard on usage report errors
    return { accepted: true };
  }
}

// Heartbeat check
export async function heartbeat(): Promise<boolean> {
  const config = loadBetaConfig();
  if (!config) return false;

  try {
    const response = await fetch(`${config.serverUrl}/heartbeat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ licenseKey: config.licenseKey }),
    });

    const data = await response.json() as { valid: boolean; creditsRemaining?: number };

    if (!data.valid) {
      console.log("⚠️ License no longer valid");
      clearCredentials();
      return false;
    }

    config.creditsRemaining = data.creditsRemaining;
    config.lastValidated = Date.now();
    saveBetaConfig(config);

    return true;
  } catch {
    // Network error - allow offline use for a bit
    const lastValidated = config.lastValidated || 0;
    const offlineGracePeriod = 24 * 60 * 60 * 1000; // 24 hours

    if (Date.now() - lastValidated > offlineGracePeriod) {
      console.log("⚠️ License validation expired (offline too long)");
      clearCredentials();
      return false;
    }

    return true; // Allow offline use within grace period
  }
}

// Start background validation (run in gateway process)
export function startBackgroundValidation(): void {
  // Initial validation
  const config = loadBetaConfig();
  if (config) {
    heartbeat();
  }

  // Periodic heartbeat
  setInterval(async () => {
    const valid = await heartbeat();
    if (!valid) {
      console.log("🛑 Beta license invalid - stopping gateway");
      process.exit(1);
    }
  }, HEARTBEAT_INTERVAL_MS);
}

// CLI for testing
if (import.meta.main) {
  const command = process.argv[2];
  const arg = process.argv[3];

  switch (command) {
    case "activate":
      if (!arg) {
        console.error("Usage: bun beta-license-client.ts activate <license-key>");
        process.exit(1);
      }
      validateLicense(arg).then((result) => {
        if (result.valid) {
          console.log("✅ License activated successfully!");
          console.log(`   Credits remaining: ${result.creditsRemaining}`);
        } else {
          console.error(`❌ Activation failed: ${result.error}`);
          process.exit(1);
        }
      });
      break;

    case "status":
      const config = loadBetaConfig();
      if (!config) {
        console.log("No beta license configured");
      } else {
        console.log("Beta License Status:");
        console.log(`  Key: ${config.licenseKey}`);
        console.log(`  Credits remaining: ${config.creditsRemaining || "unknown"}`);
        console.log(`  Last validated: ${config.lastValidated ? new Date(config.lastValidated).toISOString() : "never"}`);
        console.log(`  Expires: ${config.expiresAt ? new Date(config.expiresAt).toISOString() : "unknown"}`);
      }
      break;

    case "check":
      heartbeat().then((valid) => {
        console.log(valid ? "✅ License is valid" : "❌ License is invalid");
        process.exit(valid ? 0 : 1);
      });
      break;

    default:
      console.log("Usage:");
      console.log("  bun beta-license-client.ts activate <license-key>");
      console.log("  bun beta-license-client.ts status");
      console.log("  bun beta-license-client.ts check");
  }
}
