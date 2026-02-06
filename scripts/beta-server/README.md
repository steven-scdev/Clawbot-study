# Beta License Server

Cloud-controlled beta distribution system for OpenClaw Workforce.

## Features

- **License-based access**: Each beta user gets a unique license key
- **Credit limits**: Set token budgets per user (e.g., 100k tokens)
- **Remote revocation**: Disable any user instantly
- **Usage tracking**: See exactly how many tokens each user consumes
- **Automatic expiry**: Licenses expire after configurable time (default: 7 days)
- **Offline grace period**: Users can work offline for 24 hours

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  YOUR MACHINE (Admin)                                        │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ admin-cli.ts                                            ││
│  │   • Create licenses                                     ││
│  │   • Revoke access                                       ││
│  │   • View usage dashboard                                ││
│  └─────────────────────────────────────────────────────────┘│
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  CLOUDFLARE WORKER (Free tier)                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ worker.ts                                               ││
│  │   • Validates licenses                                  ││
│  │   • Vends OAuth tokens                                  ││
│  │   • Tracks usage                                        ││
│  │   • Handles revocation                                  ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Cloudflare KV                                           ││
│  │   • Stores license data                                 ││
│  │   • Persists usage counters                             ││
│  └─────────────────────────────────────────────────────────┘│
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  Beta User A    │ │  Beta User B    │ │  Beta User C    │
│  license: abc123│ │  license: def456│ │  license: ghi789│
│  credits: 100k  │ │  credits: 100k  │ │  credits: 50k   │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

## Setup

### 1. Deploy Cloudflare Worker

```bash
# Create new worker project
npm create cloudflare@latest beta-license-server
cd beta-license-server

# Copy worker.ts to src/index.ts
cp ../worker.ts src/index.ts

# Create KV namespace
wrangler kv:namespace create BETA_LICENSES

# Add the namespace binding to wrangler.toml
# [[kv_namespaces]]
# binding = "BETA_LICENSES"
# id = "<your-namespace-id>"

# Set environment variables
wrangler secret put ADMIN_SECRET      # Your admin password
wrangler secret put OAUTH_ACCESS_TOKEN
wrangler secret put OAUTH_REFRESH_TOKEN
wrangler secret put OAUTH_EXPIRES_AT

# Deploy
wrangler deploy
```

### 2. Configure Admin CLI

```bash
# Set environment variables
export BETA_SERVER_URL="https://your-worker.your-subdomain.workers.dev"
export BETA_ADMIN_SECRET="your-admin-secret"
```

### 3. Create Licenses

```bash
# Create a license for Alice with 100k tokens, expires in 7 days
bun admin-cli.ts create alice@example.com "Alice" 100000 7

# Output:
# ✅ License created!
# Key: beta-a1b2c3d4
# ...
```

### 4. Send to Beta Users

Send them the license key and installer URL:

```bash
# They run:
curl -fsSL https://your-server.com/licensed-installer.sh | bash -s beta-a1b2c3d4
```

Or they can download and run manually:
```bash
./licensed-installer.sh beta-a1b2c3d4
```

## Admin Commands

```bash
# List all licenses
bun admin-cli.ts list

# Create new license
bun admin-cli.ts create <email> <name> [credits] [days]

# Revoke a license (immediate)
bun admin-cli.ts revoke <license-key>

# View dashboard
bun admin-cli.ts status
```

## How It Works

### License Validation Flow

1. User runs installer with license key
2. Installer calls `POST /validate` on your worker
3. Worker checks:
   - License exists
   - License is active
   - License hasn't expired
   - Credits haven't been exhausted
4. If valid, returns OAuth credentials
5. Installer saves credentials to `~/.openclaw/agents/main/auth-profiles.json`

### Heartbeat Flow

1. Every 5 minutes, OpenClaw calls `POST /heartbeat`
2. Worker checks license is still valid
3. If revoked/expired/exhausted → clears local credentials → gateway stops

### Usage Reporting Flow

1. After each API call, usage is accumulated locally
2. Every 1 minute, usage is reported via `POST /usage`
3. Worker updates credit counter
4. If over limit → license auto-disabled

## Security Notes

- **OAuth tokens are sensitive**: They're stored encrypted in Cloudflare secrets
- **Offline grace period**: Users can work offline for 24 hours before re-validation
- **Revocation delay**: Up to 5 minutes for revocation to take effect
- **Rate limits**: All users share your subscription's rate limits

## Cost

- **Cloudflare Worker**: Free tier (100k requests/day)
- **Cloudflare KV**: Free tier (100k reads/day, 1k writes/day)
- **Your Claude subscription**: $100-200/month (Max plan)

## Files

| File | Purpose |
|------|---------|
| `worker.ts` | Cloudflare Worker server code |
| `admin-cli.ts` | Admin CLI for managing licenses |
| `beta-license-client.ts` | Client library (for OpenClaw integration) |
| `licensed-installer.sh` | User installer script |

## Troubleshooting

### "License validation failed"
- Check license key is correct
- Check license hasn't expired
- Check credits haven't been exhausted

### "Network error"
- User may be offline
- Check worker URL is correct
- Check worker is deployed

### User still has access after revocation
- Heartbeat runs every 5 minutes
- Wait up to 5 minutes for revocation to take effect
- For immediate cutoff, ask user to restart gateway
