#!/usr/bin/env bash
set -euo pipefail

# Build and bundle Workforce into a minimal .app we can open.
# Outputs to dist/Workforce.app

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_ROOT="$ROOT_DIR/dist/Workforce.app"
BUILD_ROOT="$ROOT_DIR/apps/macos/.build-local"
PRODUCT="Workforce"
BUNDLE_ID="${BUNDLE_ID:-ai.openclaw.workforce.debug}"
BUILD_CONFIG="${BUILD_CONFIG:-debug}"
BUILD_ARCH="${BUILD_ARCH:-$(uname -m)}"

echo "🔨 Building $PRODUCT ($BUILD_CONFIG) [$BUILD_ARCH]"
cd "$ROOT_DIR/apps/macos"
swift build -c "$BUILD_CONFIG" --product "$PRODUCT" --build-path "$BUILD_ROOT" --arch "$BUILD_ARCH"

BIN_PATH="$BUILD_ROOT/$BUILD_CONFIG/$PRODUCT"
echo "pkg: binary $BIN_PATH" >&2

echo "🧹 Cleaning old app bundle"
rm -rf "$APP_ROOT"
mkdir -p "$APP_ROOT/Contents/MacOS"
mkdir -p "$APP_ROOT/Contents/Resources"

echo "📄 Creating Info.plist"
cat > "$APP_ROOT/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Workforce</string>
    <key>CFBundleIdentifier</key>
    <string>ai.openclaw.workforce.debug</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Workforce</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
</dict>
</plist>
EOF

# Update bundle ID if custom one provided
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "$APP_ROOT/Contents/Info.plist" || true

echo "🚚 Copying binary"
cp "$BIN_PATH" "$APP_ROOT/Contents/MacOS/Workforce"
chmod +x "$APP_ROOT/Contents/MacOS/Workforce"

# SwiftPM outputs ad-hoc signed binaries; strip the signature to avoid warnings
/usr/bin/codesign --remove-signature "$APP_ROOT/Contents/MacOS/Workforce" 2>/dev/null || true

echo "🔏 Ad-hoc signing bundle"
codesign --force --deep --sign - "$APP_ROOT" 2>/dev/null || true

echo "⏹  Stopping any running Workforce"
killall -q Workforce 2>/dev/null || true

echo "✅ Bundle ready at $APP_ROOT"

if [[ "${AUTO_LAUNCH:-1}" == "1" ]]; then
    echo "🚀 Launching Workforce..."
    open "$APP_ROOT"
else
    echo "📝 To launch: open $APP_ROOT"
fi
