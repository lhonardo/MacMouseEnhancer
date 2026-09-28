#!/bin/bash
# Build and package MouseFix as a .app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/debug"
APP_DIR="$SCRIPT_DIR/MouseFix.app"
CONTENTS="$APP_DIR/Contents"

echo "Building MouseFix..."
cd "$SCRIPT_DIR"
swift build

echo "Creating .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"

# Copy the binary
cp "$BUILD_DIR/MouseFix" "$CONTENTS/MacOS/MouseFix"

# Copy the Info.plist
cp "$SCRIPT_DIR/Info.plist" "$CONTENTS/Info.plist"

echo ""
echo "Done! MouseFix.app created at:"
echo "  $APP_DIR"
echo ""
echo "To run:"
echo "  open \"$APP_DIR\""
echo ""
echo "NOTE: macOS will ask you to grant Accessibility permissions."
echo "Go to System Settings > Privacy & Security > Accessibility and enable MouseFix."
