#!/usr/bin/env bash
# Cross-platform convenience wrapper around the PowerShell reference
# implementation. It does not duplicate any validation logic; it just locates
# PowerShell and forwards to scripts/run-all-checks.ps1, preserving the exit
# code. Linux/macOS support (via pwsh) is EXPERIMENTAL.
set -euo pipefail

if command -v pwsh >/dev/null 2>&1; then
  PS=pwsh
elif command -v powershell >/dev/null 2>&1; then
  PS=powershell
else
  echo "PowerShell was not found on PATH." >&2
  echo "Install PowerShell 7 (pwsh): https://aka.ms/powershell" >&2
  exit 127
fi

# Run from the repository root regardless of where the wrapper is invoked.
cd "$(dirname "$0")/.."

exec "$PS" -NoProfile -ExecutionPolicy Bypass -File scripts/run-all-checks.ps1 -RepoPath . "$@"
