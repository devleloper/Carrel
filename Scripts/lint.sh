#!/usr/bin/env bash
# Style and hygiene checks. Any formatting finding or grep rule below fails the build.
set -euo pipefail
cd "$(dirname "$0")/.."

sources=(Carrel CarrelTests CarrelUITests Packages/CarrelKit)

if xcrun --find swift-format >/dev/null 2>&1; then
  xcrun swift-format lint --strict --recursive --configuration .swift-format "${sources[@]}"
elif [[ -n "${CI:-}" ]]; then
  echo "swift-format is missing from the CI toolchain, so formatting cannot be checked." >&2
  exit 1
else
  echo "swift-format is not available in this toolchain; skipping formatting checks." >&2
fi

status=0
# SwiftPM's generated sources in .build carry their own TODOs after a local `swift test`.
if grep -rn --include='*.swift' --exclude-dir=.build -E '\b(TODO|FIXME)\b' "${sources[@]}"; then
  echo "Resolve TODO/FIXME comments or turn them into issues." >&2
  status=1
fi
# The package reads files from disk and must never crash on bad input: damaged files are recovered, not trapped on.
if grep -rn --include='*.swift' -E 'fatalError|precondition(Failure)?\(|try!' Packages/CarrelKit/Sources; then
  echo "CarrelKit must not trap. Throw an error the caller can recover from." >&2
  status=1
fi
exit $status
