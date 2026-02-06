#!/usr/bin/env bun
/**
 * Beta Usage Report
 * Aggregates token usage across all sessions to estimate costs
 *
 * Run: bun scripts/beta-usage-report.ts
 */

import { readdir, readFile, stat } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";

// Anthropic pricing (as of Feb 2026)
const PRICING = {
  "claude-opus-4-5": { input: 15, output: 75, cacheRead: 1.5, cacheWrite: 18.75 }, // per 1M tokens
  "claude-sonnet-4-5": { input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75 },
  "claude-haiku-3-5": { input: 0.25, output: 1.25, cacheRead: 0.03, cacheWrite: 0.3 },
};

type Usage = {
  input: number;
  output: number;
  cacheRead: number;
  cacheWrite: number;
};

type SessionSummary = {
  sessionId: string;
  agentId: string;
  model: string;
  usage: Usage;
  cost: number;
  lastActivity: Date;
  messageCount: number;
};

async function scanSessionFile(filePath: string): Promise<SessionSummary | null> {
  const content = await readFile(filePath, "utf-8");
  const lines = content.trim().split("\n").filter(Boolean);

  const usage: Usage = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
  let model = "unknown";
  let lastActivity = new Date(0);
  let messageCount = 0;

  for (const line of lines) {
    try {
      const entry = JSON.parse(line);
      const msg = entry.message;

      if (msg?.role === "assistant" && msg?.usage) {
        messageCount++;
        const u = msg.usage;
        usage.input += u.input_tokens ?? u.inputTokens ?? u.input ?? 0;
        usage.output += u.output_tokens ?? u.outputTokens ?? u.output ?? 0;
        usage.cacheRead += u.cache_read_input_tokens ?? u.cacheRead ?? u.cache_read ?? 0;
        usage.cacheWrite += u.cache_creation_input_tokens ?? u.cacheWrite ?? u.cache_write ?? 0;

        if (msg.model) model = msg.model;

        const ts = entry.timestamp || msg.timestamp;
        if (ts) {
          const date = new Date(ts);
          if (date > lastActivity) lastActivity = date;
        }
      }
    } catch {
      // Skip malformed lines
    }
  }

  if (messageCount === 0) return null;

  // Calculate cost
  const pricing = Object.entries(PRICING).find(([m]) => model.includes(m))?.[1]
    ?? PRICING["claude-sonnet-4-5"];

  const cost = (
    (usage.input / 1_000_000) * pricing.input +
    (usage.output / 1_000_000) * pricing.output +
    (usage.cacheRead / 1_000_000) * pricing.cacheRead +
    (usage.cacheWrite / 1_000_000) * pricing.cacheWrite
  );

  const sessionId = filePath.split("/").pop()?.replace(".jsonl", "") ?? "unknown";
  const agentId = filePath.split("/").slice(-3, -2)[0] ?? "unknown";

  return { sessionId, agentId, model, usage, cost, lastActivity, messageCount };
}

async function main() {
  const openclawDir = join(homedir(), ".openclaw", "agents");

  console.log("🦞 Beta Usage Report");
  console.log("=".repeat(60));
  console.log();

  const agents = await readdir(openclawDir).catch(() => []);
  const allSessions: SessionSummary[] = [];

  for (const agent of agents) {
    const sessionsDir = join(openclawDir, agent, "sessions");
    try {
      const files = await readdir(sessionsDir);
      for (const file of files) {
        if (!file.endsWith(".jsonl")) continue;
        const summary = await scanSessionFile(join(sessionsDir, file));
        if (summary) allSessions.push(summary);
      }
    } catch {
      // No sessions for this agent
    }
  }

  // Filter to last 7 days
  const weekAgo = new Date();
  weekAgo.setDate(weekAgo.getDate() - 7);
  const recentSessions = allSessions.filter(s => s.lastActivity > weekAgo);

  // Aggregate by agent
  const byAgent = new Map<string, { usage: Usage; cost: number; sessions: number; messages: number }>();

  for (const session of recentSessions) {
    const existing = byAgent.get(session.agentId) ?? {
      usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      cost: 0, sessions: 0, messages: 0
    };
    existing.usage.input += session.usage.input;
    existing.usage.output += session.usage.output;
    existing.usage.cacheRead += session.usage.cacheRead;
    existing.usage.cacheWrite += session.usage.cacheWrite;
    existing.cost += session.cost;
    existing.sessions++;
    existing.messages += session.messageCount;
    byAgent.set(session.agentId, existing);
  }

  // Total
  let totalCost = 0;
  let totalTokens = 0;
  let totalMessages = 0;

  console.log("Usage by Agent (Last 7 Days):");
  console.log("-".repeat(60));

  for (const [agent, data] of byAgent) {
    const tokens = data.usage.input + data.usage.output + data.usage.cacheRead + data.usage.cacheWrite;
    console.log(`\n📁 ${agent}`);
    console.log(`   Sessions: ${data.sessions} | Messages: ${data.messages}`);
    console.log(`   Tokens: ${(tokens / 1000).toFixed(1)}k (in: ${(data.usage.input / 1000).toFixed(1)}k, out: ${(data.usage.output / 1000).toFixed(1)}k)`);
    console.log(`   Estimated Cost: $${data.cost.toFixed(4)}`);

    totalCost += data.cost;
    totalTokens += tokens;
    totalMessages += data.messages;
  }

  console.log("\n" + "=".repeat(60));
  console.log("TOTALS (Last 7 Days):");
  console.log(`   Sessions: ${recentSessions.length}`);
  console.log(`   Messages: ${totalMessages}`);
  console.log(`   Tokens: ${(totalTokens / 1000).toFixed(1)}k`);
  console.log(`   Estimated Cost: $${totalCost.toFixed(4)}`);
  console.log();

  // Projection
  const dailyAvg = totalCost / 7;
  console.log("Projections:");
  console.log(`   Daily average: $${dailyAvg.toFixed(4)}`);
  console.log(`   Weekly: $${(dailyAvg * 7).toFixed(2)}`);
  console.log(`   Monthly: $${(dailyAvg * 30).toFixed(2)}`);
  console.log();

  // Compare to subscription
  console.log("💡 Note: You're using OAuth (subscription-based).");
  console.log("   If using API keys, these would be your actual costs.");
  console.log("   Claude Max: $100/month unlimited (what you're paying)");
  console.log();
}

main().catch(console.error);
