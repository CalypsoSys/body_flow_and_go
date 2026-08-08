#!/usr/bin/env bash
set -euo pipefail

dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test

if command -v gitleaks >/dev/null 2>&1; then
  gitleaks dir --redact --no-banner --max-target-megabytes 10 .
else
  echo "warning: Gitleaks is not installed; skipping local secret scan" >&2
fi

echo "Verification passed."
