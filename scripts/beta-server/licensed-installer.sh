#!/bin/bash
# Licensed Beta Installer for OpenClaw Workforce
# Users run this with their license key

set -e

BETA_SERVER_URL="${BETA_SERVER_URL:-https://your-worker.workers.dev}"

echo "🦞 OpenClaw Workforce Beta Installer"
echo "════════════════════════════════════"
echo ""

# Get license key
if [ -n "$1" ]; then
  LICENSE_KEY="$1"
else
  echo -n "Enter your license key: "
  read LICENSE_KEY
fi

if [ -z "$LICENSE_KEY" ]; then
  echo "❌ License key is required"
  exit 1
fi

echo ""
echo "🔐 Validating license..."

# Validate license with server
RESPONSE=$(curl -s -X POST "$BETA_SERVER_URL/validate" \
  -H "Content-Type: application/json" \
  -d "{\"licenseKey\": \"$LICENSE_KEY\"}")

# Check if valid
VALID=$(echo "$RESPONSE" | grep -o '"valid":true' || true)

if [ -z "$VALID" ]; then
  ERROR=$(echo "$RESPONSE" | grep -o '"error":"[^"]*"' | cut -d'"' -f4)
  echo "❌ License validation failed: $ERROR"
  exit 1
fi

# Extract credentials
ACCESS_TOKEN=$(echo "$RESPONSE" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4)
REFRESH_TOKEN=$(echo "$RESPONSE" | grep -o '"refreshToken":"[^"]*"' | cut -d'"' -f4)
EXPIRES_AT=$(echo "$RESPONSE" | grep -o '"expiresAt":[0-9]*' | cut -d':' -f2)
CREDITS_REMAINING=$(echo "$RESPONSE" | grep -o '"creditsRemaining":[0-9]*' | cut -d':' -f2)

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Failed to get credentials from server"
  exit 1
fi

echo "✅ License validated!"
echo "   Credits remaining: $CREDITS_REMAINING tokens"
echo ""

# Create directories
OPENCLAW_DIR="$HOME/.openclaw"
AGENT_DIR="$OPENCLAW_DIR/agents/main"
mkdir -p "$AGENT_DIR"

# Save beta config
cat > "$OPENCLAW_DIR/beta-license.json" << EOF
{
  "licenseKey": "$LICENSE_KEY",
  "serverUrl": "$BETA_SERVER_URL",
  "lastValidated": $(date +%s)000,
  "creditsRemaining": $CREDITS_REMAINING
}
EOF

# Save auth credentials
cat > "$AGENT_DIR/auth-profiles.json" << EOF
{
  "profiles": {
    "anthropic:beta-licensed": {
      "type": "oauth",
      "provider": "anthropic",
      "access": "$ACCESS_TOKEN",
      "refresh": "$REFRESH_TOKEN",
      "expires": $EXPIRES_AT,
      "email": "licensed-beta@openclaw.ai"
    }
  },
  "order": {
    "anthropic": ["anthropic:beta-licensed"]
  }
}
EOF

# Create basic config if not exists
if [ ! -f "$OPENCLAW_DIR/openclaw.json" ]; then
  cat > "$OPENCLAW_DIR/openclaw.json" << 'EOF'
{
  "meta": { "lastTouchedVersion": "beta" },
  "agents": {
    "defaults": {
      "model": { "primary": "anthropic/claude-sonnet-4-5" }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": { "token": "beta-local-token" }
  }
}
EOF
fi

echo "✅ Installation complete!"
echo ""
echo "To start using OpenClaw Workforce:"
echo ""
echo "  1. Start the gateway:"
echo "     openclaw gateway run"
echo ""
echo "  2. Chat with your AI employees:"
echo "     openclaw agent --agent main --message \"Hello\""
echo ""
echo "  3. Check your usage:"
echo "     openclaw status --usage"
echo ""
echo "Your license will be validated periodically."
echo "If you run out of credits, contact your admin for more."
echo ""
