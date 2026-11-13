#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR=".build"
MODULE_CACHE="${BUILD_DIR}/module-cache"
TEST_BIN="${BUILD_DIR}/VPlayerTestsRunner"

SDK_PATH=""
if [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"
elif [ -d "/Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk" ]; then
    SDK_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX14.4.sdk"
else
    SDK_PATH="$(xcrun --show-sdk-path)"
fi

mkdir -p "${BUILD_DIR}" "${MODULE_CACHE}"

swiftc \
    -parse-as-library \
    -sdk "${SDK_PATH}" \
    -target arm64-apple-macosx14.0 \
    -module-cache-path "${MODULE_CACHE}" \
    -o "${TEST_BIN}" \
    Sources/VPlayer/Models/Track.swift \
    Sources/VPlayer/Models/Lyrics.swift \
    Sources/VPlayer/Models/Enums.swift \
    Sources/VPlayer/Services/LyricsService.swift \
    Sources/VPlayer/Services/LibraryScanner.swift \
    Sources/VPlayer/Services/PlaylistPersistenceService.swift \
    Tests/VPlayerTests/VPlayerTests.swift

"${TEST_BIN}"
