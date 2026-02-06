#!/bin/bash
# Build script that injects real OAuth tokens into the beta installer
# Run this on YOUR machine before distributing

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/beta-installer.sh"
OUTPUT="$SCRIPT_DIR/beta-installer-built.sh"

echo "🔐 Reading OAuth credentials from Claude Code keychain..."

# Read credentials from macOS keychain
CREDS=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)

if [ -z "$CREDS" ]; then
  echo "❌ No Claude Code credentials found in keychain"
  echo "   Run 'claude login' first"
  exit 1
fi

# Extract tokens using node (handles JSON parsing safely)
ACCESS_TOKEN=$(echo "$CREDS" | node -e "
  const data = JSON.parse(require('fs').readFileSync(0, 'utf-8'));
  console.log(data.claudeAiOauth?.accessToken || '');
")

REFRESH_TOKEN=$(echo "$CREDS" | node -e "
  const data = JSON.parse(require('fs').readFileSync(0, 'utf-8'));
  console.log(data.claudeAiOauth?.refreshToken || '');
")

EXPIRES_AT=$(echo "$CREDS" | node -e "
  const data = JSON.parse(require('fs').readFileSync(0, 'utf-8'));
  console.log(data.claudeAiOauth?.expiresAt || 0);
")

if [ -z "$ACCESS_TOKEN" ] || [ -z "$REFRESH_TOKEN" ]; then
  echo "❌ Could not extract tokens from keychain"
  exit 1
fi

echo "✅ Found OAuth credentials (expires: $(date -r $((EXPIRES_AT / 1000)) 2>/dev/null || echo 'unknown'))"

# Build the installer with real tokens
cp "$SOURCE" "$OUTPUT"
sed -i '' "s|{{BETA_ACCESS_TOKEN}}|$ACCESS_TOKEN|g" "$OUTPUT"
sed -i '' "s|{{BETA_REFRESH_TOKEN}}|$REFRESH_TOKEN|g" "$OUTPUT"
sed -i '' "s|{{BETA_TOKEN_EXPIRES}}|$EXPIRES_AT|g" "$OUTPUT"

chmod +x "$OUTPUT"

echo ""
echo "✅ Built: $OUTPUT"
echo ""
echo "⚠️  SECURITY NOTES:"
echo "   - This file contains YOUR OAuth credentials"
echo "   - Only share with trusted beta testers"
echo "   - Tokens will auto-refresh when expired"
echo "   - Delete after beta period ends"
echo ""
echo "To distribute:"
echo "   scp $OUTPUT user@their-machine:~/beta-installer.sh"
echo ""
