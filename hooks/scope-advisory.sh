#!/bin/sh
# Axiom-PMO scope advisory -- the cheap half.
#
# This runs on every Write/Edit while the plugin is installed, so the disabled
# path has to cost almost nothing. Starting Node to discover that the feature
# is switched off would tax every edit for a feature nobody enabled.
#
# So the opt-in is checked here, in shell, against the project directory, and
# Node is started only when a project has actually asked for this.
#
# Every failure exits 0 and prints nothing. A governance advisory that breaks
# an editing session has done more damage than the deviation it watched for.

set -u

payload=$(cat 2>/dev/null || true)
[ -n "$payload" ] || exit 0

# cwd comes from the payload; grepping it out avoids a JSON parser in /bin/sh.
# A miss just means the advisory stays quiet, which is the safe direction.
cwd=$(printf '%s' "$payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

# Un-escape the JSON string. This is the whole reason the advisory never fired
# on Windows: a Windows cwd arrives as "C:\\Users\\dev\\repo", so the raw
# capture above is C:\\Users\\dev\\repo with the backslashes still doubled,
# the opt-in file is looked for at a path that does not exist, and the hook
# exits 0 having done nothing. Silent and green, which is why exit-code-only
# tests could not see it.
cwd=$(printf '%s' "$cwd" | sed -e 's/\\\//\//g' -e 's/\\\\/\\/g')

[ -n "$cwd" ] || cwd=$(pwd)

optin="$cwd/.axiom/hooks.json"
[ -f "$optin" ] || exit 0
grep -q '"scope_advisory"[[:space:]]*:[[:space:]]*true' "$optin" 2>/dev/null || exit 0

root="${CLAUDE_PLUGIN_ROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}"

node_bin="${AXIOM_NODE:-}"
if [ -z "$node_bin" ]; then
  if command -v node >/dev/null 2>&1; then node_bin="node"; fi
fi
# No Node means no advisory. It does not mean a broken tool call.
[ -n "$node_bin" ] || exit 0

printf '%s' "$payload" | "$node_bin" \
  "$root/dist/tools/hook-scope-advisory-cli.js" -ProjectPath "$cwd" 2>/dev/null || exit 0
exit 0
