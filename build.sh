#!/usr/bin/env bash
set -euo pipefail

# VPlayer Build & Package Script for macOS
APP_NAME="VPlayer"
BUNDLE_ID="com.vplayer.app"
BUILD_DIR=".build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
MODULE_CACHE="${BUILD_DIR}/module-cache"

echo "=== Building ${APP_NAME} for macOS ==="

# 1. Resolve SDK path
SDK_PATH=""
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk"
else
    SDK_PATH="$(xcrun --show-sdk-path)"
fi
echo "Using SDK: ${SDK_PATH}"

# 2. Setup directories
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${MODULE_CACHE}"

# 3. Find all Swift source files
SWIFT_FILES=$(find Sources/VPlayer -name "*.swift" -type f)

# 4. Compile binary
echo "Compiling Swift sources..."
swiftc \
    -parse-as-library \
    -O \
    -module-cache-path "${MODULE_CACHE}" \
    -sdk "${SDK_PATH}" \
    -target arm64-apple-macosx14.0 \
    ${SWIFT_FILES} \
    -o "${MACOS_DIR}/${APP_NAME}"

chmod +x "${MACOS_DIR}/${APP_NAME}"

# 5. Copy Resources
if [ -f "Resources/AppIcon.icns" ]; then
    echo "Installing AppIcon.icns..."
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# 6. Generate Info.plist
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 VPlayer. All rights reserved.</string>
</dict>
</plist>
EOF

# 7. Ad-hoc codesign
echo "Signing bundle..."
codesign --force --deep --sign - "${APP_DIR}"

echo "=== Build Successful! ==="
echo "Application bundle created at: ${APP_DIR}"

# 7. Optional run flag
if [ "${1:-}" = "run" ]; then
    echo "Launching ${APP_NAME}..."
    open "${APP_DIR}"
fi
