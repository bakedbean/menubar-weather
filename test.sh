#!/bin/bash
# Runs the unit tests; prints the summary only.
cd "$(dirname "$0")" && xcodegen generate -q && \
xcodebuild test -project MenubarWeather.xcodeproj -scheme MenubarWeather -destination 'platform=macOS' -derivedDataPath build 2>&1 | grep -E "error:|Executed|TEST (SUCCEEDED|FAILED)|failed \(" | head -40
exit ${PIPESTATUS[0]}
