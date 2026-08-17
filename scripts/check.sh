#!/usr/bin/env bash
# Cross-platform convenience wrapper around the Node CLI. It does not
# duplicate any validation logic; it just locates Node and forwards to
# cli/axiom.mjs check, preserving the exit code.
set -euo pipefail

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js was not found on PATH." >&2
  echo "Install Node.js: https://nodejs.org" >&2
  exit 127
fi

# Run from the repository root regardless of where the wrapper is invoked.
cd "$(dirname "$0")/.."

exec node cli/axiom.mjs check "$@"
