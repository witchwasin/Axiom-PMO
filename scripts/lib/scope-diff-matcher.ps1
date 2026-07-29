# SCOPE-DIFF matching engine: glob compilation, scope declaration loading,
# and per-file verdicts. No git invocation lives here -- see
# scripts/lib/scope-diff-git-adapter.ps1 for the changed-file source. This
# split lets the matching rules (the part that decides right/wrong) be tested
# completely deterministically, with a plain array of paths, no repository or
# git binary required.
#
# Deterministic only, by design: this file never reads a source file's
# content and never asks an LLM whether a path "seems related" to anything.
# It compares literal path strings against literal glob patterns. That is
# the entire contract.

# Deliberately small glob grammar: '*', '?', '**', and literal characters
# (regex-escaped). No character classes, brace expansion, or extglob --
# a smaller grammar is one that can be tested exhaustively instead of
# approximately, and "the pattern almost certainly means X" is exactly the
# kind of inference SCOPE-DIFF exists to avoid.
#
#   *   any run of characters except '/'
#   ?   any single character except '/'
#   **  globstar: zero or more path segments, including their separators
#
# Patterns are always repo-root-relative, POSIX-style (forward slash). A
# pattern containing a backslash is rejected by Test-ScopeGlobSyntax before
# this function is ever called -- see the docstring there for why.
function ConvertTo-ScopeGlobRegex {
  param([Parameter(Mandatory = $true)][string]$Pattern)

  # SOH/STX/ETX: control characters that cannot appear in a glob pattern a
  # human would type, used as placeholders so the wildcard characters survive
  # [regex]::Escape untouched, then get expanded to their regex meaning
  # afterward. This keeps the escaping pass single-purpose (escape literals)
  # instead of hand-rolling a parallel escape table that has to be kept in
  # sync with .NET's own metacharacter set.
  $globstarToken = [string][char]1
  $starToken = [string][char]2
  $qmarkToken = [string][char]3

  $tokenized = $Pattern.Replace('**', $globstarToken).Replace('*', $starToken).Replace('?', $qmarkToken)
  $escaped = [regex]::Escape($tokenized)

  if ($escaped -eq $globstarToken) {
    # The whole pattern is "**" -- matches anything, including nothing.
    $escaped = '.*'
  } else {
    # Order matters: most specific (both sides bounded by '/') first, so a
    # globstar that is both preceded and followed by '/' is not first
    # consumed by the leading- or trailing-only rule.
    $escaped = $escaped -replace ('/' + $globstarToken + '/'), '/(?:.*/)?'
    $escaped = $escaped -replace ('^' + $globstarToken + '/'), '(?:.*/)?'
    $escaped = $escaped -replace ('/' + $globstarToken + '$'), '(?:/.*)?'
    # Whatever globstar tokens remain (a lone "**" with no adjacent slash,
    # e.g. mid-segment "ab**cd", or a pattern that is just "**" glued to
    # other text with no separator) degrade to "any characters" rather than
    # being rejected -- accepting an unusual-but-unambiguous pattern is
    # safer here than silently matching nothing.
    $escaped = $escaped -replace $globstarToken, '.*'
  }

  $escaped = $escaped -replace $starToken, '[^/]*'
  $escaped = $escaped -replace $qmarkToken, '[^/]'

  return "^$escaped`$"
}

# Explicit syntax gate before ConvertTo-ScopeGlobRegex ever runs, so a scope
# declaration that would silently mean something other than what its author
# intended is rejected as SCOPE-DIFF-003 instead of quietly compiling into a
# regex nobody reviewed for that meaning.
function Test-ScopeGlobSyntax {
  param([string]$Pattern)

  if ([string]::IsNullOrWhiteSpace($Pattern)) { return "pattern is empty" }
  if ($Pattern.StartsWith('/')) { return "pattern must not start with '/' -- patterns are already repo-root-relative" }
  if ($Pattern.Contains('\')) { return "pattern contains a backslash -- use forward slashes, git paths are always POSIX-style even on Windows" }
  if ($Pattern -match '(^|/)\.\.(/|$)') { return "pattern contains a '..' segment, which has no meaningful effect on a repo-relative include/exclude list" }
  if ($Pattern.Contains("`0")) { return "pattern contains a NUL character" }
  return $null
}

# Loads <ProjectPath>/SCOPE.json. Returns:
#   Present = $false                              -- file does not exist (SCOPE-DIFF-002 territory, decided by the caller)
#   Present = $true,  Valid = $false, Error = ...  -- file exists but fails schema (SCOPE-DIFF-003)
#   Present = $true,  Valid = $true,  Include/Exclude = string[]
function Read-ScopeDeclaration {
  param([Parameter(Mandatory = $true)][string]$ProjectPath)

  $scopePath = Join-Path $ProjectPath "SCOPE.json"
  if (-not (Test-Path -LiteralPath $scopePath -PathType Leaf)) {
    return [pscustomobject]@{ Present = $false; Valid = $false; Error = $null; Include = @(); Exclude = @(); Path = $scopePath }
  }

  try {
    $raw = Get-Content -LiteralPath $scopePath -Raw -ErrorAction Stop
    $doc = $raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    return [pscustomobject]@{ Present = $true; Valid = $false; Error = "SCOPE.json is not valid JSON: $($_.Exception.Message)"; Include = @(); Exclude = @(); Path = $scopePath }
  }

  if (-not $doc.implementation_scope) {
    return [pscustomobject]@{ Present = $true; Valid = $false; Error = "SCOPE.json is missing the 'implementation_scope' object"; Include = @(); Exclude = @(); Path = $scopePath }
  }

  $includeRaw = $doc.implementation_scope.include
  if ($null -eq $includeRaw) {
    return [pscustomobject]@{ Present = $true; Valid = $false; Error = "implementation_scope.include is missing"; Include = @(); Exclude = @(); Path = $scopePath }
  }
  $include = @($includeRaw)
  if ($include.Count -eq 0) {
    return [pscustomobject]@{ Present = $true; Valid = $false; Error = "implementation_scope.include is an empty list -- every changed file would be a violation; declare at least one path"; Include = @(); Exclude = @(); Path = $scopePath }
  }

  $exclude = @()
  if ($null -ne $doc.implementation_scope.exclude) {
    $exclude = @($doc.implementation_scope.exclude)
  }

  foreach ($pattern in ($include + $exclude)) {
    if ($pattern -isnot [string]) {
      return [pscustomobject]@{ Present = $true; Valid = $false; Error = "implementation_scope entries must all be strings"; Include = @(); Exclude = @(); Path = $scopePath }
    }
    $syntaxError = Test-ScopeGlobSyntax $pattern
    if ($syntaxError) {
      return [pscustomobject]@{ Present = $true; Valid = $false; Error = "invalid pattern '$pattern': $syntaxError"; Include = @(); Exclude = @(); Path = $scopePath }
    }
  }

  return [pscustomobject]@{ Present = $true; Valid = $true; Error = $null; Include = $include; Exclude = $exclude; Path = $scopePath }
}

# Loads pmo-config/scope-diff-policy.json's repo_wide_exempt list. Unlike
# SCOPE.json this file is part of the framework's own runtime config (like
# policy.json, artifact-policy.json, etc.) -- Import-PmoConfig's "missing
# config is a hard error" rule applies the same way here.
#
# A repo-wide exemption is reviewable precisely because it is explicit and
# narrow -- every entry is validated the same way a project's own SCOPE.json
# patterns are (Test-ScopeGlobSyntax), plus three checks specific to this
# file: a pattern broad enough to exempt the whole repository defeats the
# entire check for every project at once, so patterns matching "everything"
# are rejected outright; an empty reason defeats the "reviewable in a diff"
# purpose of this file; and a duplicate pattern is very likely a copy-paste
# mistake, not an intended second rule.
function Read-ScopeDiffPolicy {
  param([Parameter(Mandatory = $true)][string]$RepoRoot)

  $policyPath = Join-Path $RepoRoot "pmo-config/scope-diff-policy.json"
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    throw "Missing runtime scope-diff policy config: $policyPath"
  }
  $doc = Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json

  $tooBroad = @('**', '*', '**/*', '**/**')
  $seen = New-Object System.Collections.Generic.HashSet[string]
  $entries = @()
  foreach ($item in @($doc.repo_wide_exempt)) {
    $pattern = [string]$item.pattern
    $reason = [string]$item.reason

    $syntaxError = Test-ScopeGlobSyntax $pattern
    if ($syntaxError) {
      throw "Invalid entry in $policyPath -- pattern '$pattern': $syntaxError"
    }
    if ($tooBroad -contains $pattern) {
      throw "Invalid entry in $policyPath -- pattern '$pattern' is too broad for a repo-wide exemption: it would exempt effectively every file in every project from SCOPE-DIFF. Name a specific file or path prefix instead."
    }
    if ([string]::IsNullOrWhiteSpace($reason)) {
      throw "Invalid entry in $policyPath -- pattern '$pattern' has no reason. Every repo-wide exemption must document why it is exempt."
    }
    if (-not $seen.Add($pattern)) {
      throw "Invalid entry in $policyPath -- duplicate pattern '$pattern'"
    }

    $entries += [pscustomobject]@{ Pattern = $pattern; Reason = $reason }
  }
  return $entries
}

# One file's verdict against a compiled scope. Precedence, most specific
# first: project-level exclude beats the repo-wide exempt list, which beats
# plain inclusion. A project that explicitly excludes a path is making a
# more specific and more recently reviewed decision than a repo-wide default,
# so it wins even over an exemption.
#
#   "excluded"    -- matches the project's own exclude list (SCOPE-DIFF-005)
#   "exempt"      -- matches a repo-wide exemption, with its reason
#   "in_scope"    -- matches an include pattern, not excluded, not exempt
#   "out_of_scope" -- matches nothing approved (SCOPE-DIFF-001)
# Path comparisons here are always -cmatch (case-sensitive), never plain
# -match. PowerShell's -match is case-insensitive by default, which would
# let `SRC/PAYMENTS/admin.ts` satisfy an `include: ["src/payments/**"]`
# declaration on a case-sensitive filesystem/Git checkout (Linux/macOS, and
# most CI runners) even though the literal path does not match what was
# approved -- a real scope bypass, not a formatting edge case. git itself
# always reports the on-disk byte-for-byte path, so the comparison must
# preserve case exactly.
function Resolve-ScopeVerdict {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string[]]$IncludeRegexes,
    [string[]]$ExcludeRegexes,
    $ExemptEntries
  )

  foreach ($rx in $ExcludeRegexes) {
    if ($Path -cmatch $rx) {
      return [pscustomobject]@{ Verdict = "excluded"; Reason = $null }
    }
  }
  foreach ($entry in $ExemptEntries) {
    if ($Path -cmatch $entry.Regex) {
      return [pscustomobject]@{ Verdict = "exempt"; Reason = $entry.Reason }
    }
  }
  foreach ($rx in $IncludeRegexes) {
    if ($Path -cmatch $rx) {
      return [pscustomobject]@{ Verdict = "in_scope"; Reason = $null }
    }
  }
  return [pscustomobject]@{ Verdict = "out_of_scope"; Reason = $null }
}
