#!/usr/bin/env bash
# Style and hygiene checks. Formatting findings are reported; the grep rules below fail the build.
set -euo pipefail
cd "$(dirname "$0")/.."

sources=(Carrel CarrelUITests Packages/CarrelKit)

if xcrun --find swift-format >/dev/null 2>&1; then
  xcrun swift-format lint --recursive --configuration .swift-format "${sources[@]}"
else
  echo "swift-format is not available in this toolchain; skipping formatting checks." >&2
fi

status=0
if grep -rn --include='*.swift' -E '\b(TODO|FIXME)\b' "${sources[@]}"; then
  echo "Resolve TODO/FIXME comments or turn them into issues." >&2
  status=1
fi
# The data layer must never crash on bad input: damaged files are recovered, not trapped on.
if grep -rn --include='*.swift' -E 'fatalError|preconditionFailure|try!' Packages/CarrelKit/Sources/NotebookData; then
  echo "NotebookData must not trap. Throw an error the caller can recover from." >&2
  status=1
fi
exit $status
