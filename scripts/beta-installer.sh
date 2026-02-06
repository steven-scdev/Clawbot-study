#!/bin/bash
# Beta Installer for OpenClaw Workforce
# For internal testing with 1-3 users only

set -e

echo "🦞 Installing OpenClaw Workforce Beta..."

# Create directories
OPENCLAW_DIR="$HOME/.openclaw"
AGENT_DIR="$OPENCLAW_DIR/agents/main"
mkdir -p "$AGENT_DIR"

# Install beta credentials
# These will be replaced during build with actual tokens
cat > "$AGENT_DIR/auth-profiles.json" << 'CREDENTIALS_EOF'
{
  "profiles": {
    "anthropic:workforce-beta": {
      "type": "oauth",
      "provider": "anthropic",
      "access": "{{BETA_ACCESS_TOKEN}}",
      "refresh": "{{BETA_REFRESH_TOKEN}}",
      "expires": {{BETA_TOKEN_EXPIRES}},
      "email": "workforce-beta@openclaw.ai"
    }
  },
  "order": {
    "anthropic": ["anthropic:workforce-beta"]
  }
}
CREDENTIALS_EOF

# Create basic config if not exists
if [ ! -f "$OPENCLAW_DIR/openclaw.json" ]; then
  cat > "$OPENCLAW_DIR/openclaw.json" << 'CONFIG_EOF'
{
  "meta": {
    "lastTouchedVersion": "beta"
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-sonnet-4-5"
      }
    }
  },
  "gateway": {
    "mode": "local",
    "auth": {
      "token": "beta-local-token"
    }
  }
}
CONFIG_EOF
fi

echo ""
echo "✅ Beta credentials installed!"
echo ""
echo "To start using OpenClaw Workforce:"
echo "  1. Start the gateway:  openclaw gateway run"
echo "  2. Chat with agents:   openclaw agent --agent main --message \"Hello\""
echo ""
echo "To check usage:          openclaw status --usage"
echo ""
