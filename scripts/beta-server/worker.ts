/**
 * Beta License Control Server
 * Deploy to Cloudflare Workers (free tier: 100k requests/day)
 *
 * Setup:
 *   1. npm create cloudflare@latest beta-license-server
 *   2. Copy this file to src/index.ts
 *   3. wrangler deploy
 *
 * Environment variables (set in Cloudflare dashboard):
 *   - ADMIN_SECRET: Your admin API key
 *   - OAUTH_ACCESS_TOKEN: Your Claude OAuth access token
 *   - OAUTH_REFRESH_TOKEN: Your Claude OAuth refresh token
 *   - OAUTH_EXPIRES_AT: Token expiry timestamp
 */

interface Env {
  BETA_LICENSES: KVNamespace; // Cloudflare KV for license storage
  ADMIN_SECRET: string;
  OAUTH_ACCESS_TOKEN: string;
  OAUTH_REFRESH_TOKEN: string;
  OAUTH_EXPIRES_AT: string;
}

interface License {
  key: string;
  email: string;
  name: string;
  creditsTotal: number;    // Total token credits allocated
  creditsUsed: number;     // Tokens consumed
  active: boolean;         // Can be disabled remotely
  createdAt: number;
  expiresAt: number;       // License expiry timestamp
  lastSeen?: number;       // Last validation timestamp
  lastUsageReport?: number;
}

interface UsageReport {
  licenseKey: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  sessionId?: string;
}

// CORS headers for local app
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Handle CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // Public endpoints (for beta users)
      if (path === "/validate" && request.method === "POST") {
        return handleValidate(request, env);
      }

      if (path === "/usage" && request.method === "POST") {
        return handleUsageReport(request, env);
      }

      if (path === "/heartbeat" && request.method === "POST") {
        return handleHeartbeat(request, env);
      }

      // Admin endpoints (require ADMIN_SECRET)
      const authHeader = request.headers.get("Authorization");
      const isAdmin = authHeader === `Bearer ${env.ADMIN_SECRET}`;

      if (path === "/admin/licenses" && request.method === "GET" && isAdmin) {
        return handleListLicenses(env);
      }

      if (path === "/admin/licenses" && request.method === "POST" && isAdmin) {
        return handleCreateLicense(request, env);
      }

      if (path === "/admin/revoke" && request.method === "POST" && isAdmin) {
        return handleRevoke(request, env);
      }

      if (path === "/admin/update-tokens" && request.method === "POST" && isAdmin) {
        return handleUpdateTokens(request, env);
      }

      if (path.startsWith("/admin/") && !isAdmin) {
        return jsonResponse({ error: "Unauthorized" }, 401);
      }

      return jsonResponse({ error: "Not found" }, 404);
    } catch (error) {
      console.error("Error:", error);
      return jsonResponse({ error: "Internal server error" }, 500);
    }
  },
};

// Validate license and return OAuth token if valid
async function handleValidate(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { licenseKey: string };
  const { licenseKey } = body;

  if (!licenseKey) {
    return jsonResponse({ valid: false, error: "Missing license key" }, 400);
  }

  const license = await getLicense(env, licenseKey);

  if (!license) {
    return jsonResponse({ valid: false, error: "Invalid license key" }, 403);
  }

  if (!license.active) {
    return jsonResponse({ valid: false, error: "License has been revoked" }, 403);
  }

  if (Date.now() > license.expiresAt) {
    return jsonResponse({ valid: false, error: "License has expired" }, 403);
  }

  if (license.creditsUsed >= license.creditsTotal) {
    return jsonResponse({
      valid: false,
      error: "Credit limit reached",
      creditsUsed: license.creditsUsed,
      creditsTotal: license.creditsTotal,
    }, 403);
  }

  // Update last seen
  license.lastSeen = Date.now();
  await saveLicense(env, license);

  // Return OAuth credentials
  return jsonResponse({
    valid: true,
    credentials: {
      accessToken: env.OAUTH_ACCESS_TOKEN,
      refreshToken: env.OAUTH_REFRESH_TOKEN,
      expiresAt: parseInt(env.OAUTH_EXPIRES_AT),
    },
    license: {
      name: license.name,
      creditsRemaining: license.creditsTotal - license.creditsUsed,
      creditsTotal: license.creditsTotal,
      expiresAt: license.expiresAt,
    },
  });
}

// Report usage and check if over limit
async function handleUsageReport(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as UsageReport;
  const { licenseKey, inputTokens, outputTokens, cacheReadTokens, cacheWriteTokens } = body;

  const license = await getLicense(env, licenseKey);

  if (!license) {
    return jsonResponse({ error: "Invalid license" }, 403);
  }

  const totalTokens = (inputTokens || 0) + (outputTokens || 0) +
                      (cacheReadTokens || 0) + (cacheWriteTokens || 0);

  license.creditsUsed += totalTokens;
  license.lastUsageReport = Date.now();

  const overLimit = license.creditsUsed >= license.creditsTotal;

  if (overLimit) {
    license.active = false; // Auto-disable when over limit
  }

  await saveLicense(env, license);

  return jsonResponse({
    accepted: true,
    creditsUsed: license.creditsUsed,
    creditsRemaining: Math.max(0, license.creditsTotal - license.creditsUsed),
    overLimit,
    active: license.active,
  });
}

// Simple heartbeat to check if license is still valid
async function handleHeartbeat(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { licenseKey: string };
  const license = await getLicense(env, body.licenseKey);

  if (!license || !license.active || Date.now() > license.expiresAt) {
    return jsonResponse({ valid: false }, 403);
  }

  if (license.creditsUsed >= license.creditsTotal) {
    return jsonResponse({ valid: false, reason: "credits_exhausted" }, 403);
  }

  return jsonResponse({
    valid: true,
    creditsRemaining: license.creditsTotal - license.creditsUsed,
  });
}

// Admin: List all licenses
async function handleListLicenses(env: Env): Promise<Response> {
  const list = await env.BETA_LICENSES.list();
  const licenses: License[] = [];

  for (const key of list.keys) {
    const license = await getLicense(env, key.name);
    if (license) licenses.push(license);
  }

  return jsonResponse({ licenses });
}

// Admin: Create new license
async function handleCreateLicense(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as {
    email: string;
    name: string;
    credits?: number;
    expiresInDays?: number;
  };

  const licenseKey = `beta-${generateId()}`;
  const license: License = {
    key: licenseKey,
    email: body.email,
    name: body.name,
    creditsTotal: body.credits || 100000, // Default 100k tokens
    creditsUsed: 0,
    active: true,
    createdAt: Date.now(),
    expiresAt: Date.now() + (body.expiresInDays || 7) * 24 * 60 * 60 * 1000,
  };

  await saveLicense(env, license);

  return jsonResponse({ license });
}

// Admin: Revoke license
async function handleRevoke(request: Request, env: Env): Promise<Response> {
  const body = await request.json() as { licenseKey: string };
  const license = await getLicense(env, body.licenseKey);

  if (!license) {
    return jsonResponse({ error: "License not found" }, 404);
  }

  license.active = false;
  await saveLicense(env, license);

  return jsonResponse({ revoked: true, license });
}

// Admin: Update OAuth tokens (when they need refreshing)
async function handleUpdateTokens(request: Request, env: Env): Promise<Response> {
  // Note: This updates the Worker's environment variables
  // In practice, you'd update these in the Cloudflare dashboard
  // This endpoint is just for documentation
  return jsonResponse({
    message: "Update tokens in Cloudflare dashboard: Settings > Variables",
    required: ["OAUTH_ACCESS_TOKEN", "OAUTH_REFRESH_TOKEN", "OAUTH_EXPIRES_AT"],
  });
}

// Helpers
async function getLicense(env: Env, key: string): Promise<License | null> {
  const data = await env.BETA_LICENSES.get(key);
  return data ? JSON.parse(data) : null;
}

async function saveLicense(env: Env, license: License): Promise<void> {
  await env.BETA_LICENSES.put(license.key, JSON.stringify(license));
}

function generateId(): string {
  return Math.random().toString(36).substring(2, 10);
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
    },
  });
}
