#!/usr/bin/env bash
# Builds the app and runs the UI tests on the newest iPad simulator. CI runs exactly this script.
set -euo pipefail
cd "$(dirname "$0")/.."

destination_id=$(xcrun simctl list devices available --json | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
for runtime in sorted((r for r in runtimes if "iOS" in r), reverse=True):
    ipads = [d for d in runtimes[runtime] if d["name"].startswith("iPad")]
    preferred = [d for d in ipads if d["name"].startswith("iPad Air")] or ipads
    if preferred:
        print(preferred[0]["udid"])
        break
')

if [[ -z "$destination_id" ]]; then
  echo "No iPad simulator is available. Install an iPadOS 27 runtime in Xcode › Settings › Components." >&2
  exit 1
fi

rm -rf build/Carrel.xcresult
xcodebuild test \
  -project Carrel.xcodeproj \
  -scheme Carrel \
  -destination "id=$destination_id" \
  -resultBundlePath build/Carrel.xcresult \
  CODE_SIGNING_ALLOWED=NO
