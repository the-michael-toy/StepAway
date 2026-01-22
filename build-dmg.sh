#!/bin/bash
# SPDX-License-Identifier: CC0-1.0
# This file is part of StepAway - https://github.com/the-michael-toy/StepAway
#
# Build a release DMG for StepAway

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="StepAway"
BUILD_DIR="$SCRIPT_DIR/build"
STAGING_DIR="$BUILD_DIR/dmg-staging"

echo "Building release..."
xcodebuild -project StepAway.xcodeproj -scheme StepAway -configuration Release build

# Find the built app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/StepAway-*/Build/Products/Release -name "StepAway.app" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app"
    exit 1
fi

echo "Found app at: $APP_PATH"

# Get version from the app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
DMG_NAME="StepAway-${VERSION}.dmg"
VOLUME_NAME="$APP_NAME $VERSION"

echo "Creating DMG for version $VERSION..."

# Clean up any previous staging
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy app and create Applications symlink
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Remove old DMGs if they exist
rm -f "$BUILD_DIR/$DMG_NAME"
rm -f "$BUILD_DIR/temp.dmg"

# Create a read-write DMG first (so we can customize it)
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDRW "$BUILD_DIR/temp.dmg"

# Mount the DMG
MOUNT_DIR=$(hdiutil attach -readwrite -noverify "$BUILD_DIR/temp.dmg" | grep "/Volumes/" | sed 's/.*\/Volumes/\/Volumes/')

echo "Mounted at: $MOUNT_DIR"

# Use AppleScript to set icon positions and window appearance
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, 500, 350}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 80
        set position of item "StepAway.app" of container window to {100, 120}
        set position of item "Applications" of container window to {300, 120}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Unmount
hdiutil detach "$MOUNT_DIR"

# Convert to compressed read-only DMG
hdiutil convert "$BUILD_DIR/temp.dmg" -format UDZO -o "$BUILD_DIR/$DMG_NAME"

# Clean up
rm -f "$BUILD_DIR/temp.dmg"
rm -rf "$STAGING_DIR"

echo ""
echo "Created: $BUILD_DIR/$DMG_NAME"
ls -lh "$BUILD_DIR/$DMG_NAME"
