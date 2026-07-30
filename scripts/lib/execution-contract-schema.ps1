# Execution-contract and execution-result schema handling (M5.1/M5.2).
#
# Two documents, two trust levels, deliberately kept in separate functions so
# the difference is impossible to lose track of while reading:
#
#   EXECUTION-CONTRACT.json  written by Axiom-PMO at export time, from an
#                            already-approved DELIVERY.md work item. Trusted
#                            only because a human approved the work item it
#                            was generated from -- see the digest contract
#                            below for what stops it being edited afterward.
#
#   EXECUTION-RESULT.json    written by the execution agent. Untrusted by
#                            definition: it is authored by the same actor
#                            this milestone exists to verify. Nothing here
#                            treats a field in it as true; it is parsed into
#                            a shape the validator can then check against
#                            observable ground truth.
#
# No git, no filesystem walking, and no Add-Result calls live here -- this
# file only turns bytes into validated structures, so it can be tested with
# plain strings and no repository. Git ground truth is
# execution-contract-git.ps1; diagnostics are execution-contract-validator.ps1.

# The digest contract, and why it is the file's raw bytes rather than a
# canonical re-serialization of its parsed JSON:
#
# A contract and a result that the same actor can edit together prove nothing.
# So the contract's identity has to be pinned at approval time and checked
# later. The obvious implementation -- re-serialize the parsed JSON to a
# canonical form and hash that -- is a trap here: ConvertTo-Json's property
# ordering, escaping, and default depth differ between Windows PowerShell 5.1
# and PowerShell 7, both of which are required hosts (see ROADMAP M3.5). A
# digest that disagrees across hosts would fail runs for a reason that has
# nothing to do with tampering.
#
# Hashing the file's exact bytes has neither problem: it is identical on every
# host, and any edit whatsoever changes it. The cost is that the contract file
# must be byte-stable once written, which is fine -- it is generated once and
# then read-only by contract.
function Get-ExecutionFileDigest {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return $hash.Hash.ToLowerInvariant()
}

# Loads pmo-config/execution-contract-policy.json. Framework runtime config,
# same status as policy.json/scope-diff-policy.json: a missing file is a hard
# error, not a silently permissive default.
function Read-ExecutionContractPolicy {
  param([Parameter(Mandatory = $true)][string]$FrameworkRoot)

  $policyPath = Join-Path $FrameworkRoot "pmo-config/execution-contract-policy.json"
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    throw "Missing runtime execution-contract policy config: $policyPath"
  }
  return (Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json)
}

# Every field the contract must carry for verification to be meaningful.
# `git_authority` is deliberately required rather than defaulted: a contract
# that simply omits it would otherwise silently inherit whatever the policy
# defaults happen to be that week, and the whole point is that the granted
# authority is a reviewed, recorded decision.
$script:ExecutionContractRequired = @(
  "contract_version",
  "project_id",
  "work_item_id",
  "mode",
  "base_sha",
  "allowed_paths",
  "git_authority"
)

function Read-ExecutionContract {
  param([Parameter(Mandatory = $true)][string]$Path)

  $result = [pscustomobject]@{
    Present = $false; Valid = $false; Error = $null; Document = $null
    Digest = $null; Path = $Path
  }

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $result }
  $result.Present = $true
  $result.Digest = Get-ExecutionFileDigest -Path $Path

  try {
    $doc = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $result.Error = "EXECUTION-CONTRACT.json is not valid JSON: $($_.Exception.Message)"
    return $result
  }

  foreach ($field in $script:ExecutionContractRequired) {
    if (-not $doc.PSObject.Properties[$field]) {
      $result.Error = "EXECUTION-CONTRACT.json is missing required field '$field'"
      return $result
    }
  }

  $allowed = @($doc.allowed_paths)
  if ($allowed.Count -eq 0) {
    # An empty allowed_paths would mean "every changed file is a violation",
    # which is never what an author meant -- it is a filled-in-wrong contract,
    # not an intentionally empty one.
    $result.Error = "EXECUTION-CONTRACT.json declares an empty allowed_paths; a contract must name at least one path the work may touch"
    return $result
  }
  foreach ($pattern in $allowed) {
    if ($pattern -isnot [string]) {
      $result.Error = "EXECUTION-CONTRACT.json allowed_paths entries must all be strings"
      return $result
    }
    # Same glob grammar and the same syntax gate as SCOPE.json (M4.5): one
    # matching engine, one set of rules a reader has to learn, and a pattern
    # that means something different in the two files is impossible.
    $syntaxError = Test-ScopeGlobSyntax $pattern
    if ($syntaxError) {
      $result.Error = "EXECUTION-CONTRACT.json allowed_paths entry '$pattern' is invalid: $syntaxError"
      return $result
    }
  }

  $result.Valid = $true
  $result.Document = $doc
  return $result
}

$script:ExecutionResultRequired = @(
  "contract_version",
  "work_item_id",
  "contract_sha256",
  "base_sha",
  "execution_status"
)

$script:ExecutionStatusValues = @("completed", "partial", "blocked", "failed")

function Read-ExecutionResult {
  param([Parameter(Mandatory = $true)][string]$Path)

  $result = [pscustomobject]@{
    Present = $false; Valid = $false; Error = $null; Document = $null; Path = $Path
  }

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $result }
  $result.Present = $true

  try {
    $doc = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
  } catch {
    $result.Error = "EXECUTION-RESULT.json is not valid JSON: $($_.Exception.Message)"
    return $result
  }

  foreach ($field in $script:ExecutionResultRequired) {
    if (-not $doc.PSObject.Properties[$field]) {
      $result.Error = "EXECUTION-RESULT.json is missing required field '$field'"
      return $result
    }
  }

  if ($script:ExecutionStatusValues -notcontains [string]$doc.execution_status) {
    $result.Error = "EXECUTION-RESULT.json execution_status must be one of: $($script:ExecutionStatusValues -join ', ')"
    return $result
  }

  # A 64-hex-character digest is checked for shape here so that a truncated or
  # obviously-placeholder value fails as a schema problem (with a schema
  # message) rather than surfacing later as a confusing digest mismatch.
  if ([string]$doc.contract_sha256 -notmatch '^[0-9a-f]{64}$') {
    $result.Error = "EXECUTION-RESULT.json contract_sha256 is not a lowercase 64-character SHA-256 digest"
    return $result
  }

  $result.Valid = $true
  $result.Document = $doc
  return $result
}

# Normalizes `test_evidence` entries into a uniform shape with an explicit
# verifiable/not-verifiable verdict taken from policy, so the validator never
# has to special-case adapter types inline.
#
# An unknown adapter type is treated as NOT verifiable rather than rejected
# outright: a future adapter appearing in a result produced by a newer
# toolchain should degrade to "this does not satisfy a required test," which is
# safe, instead of failing the whole run, which would make adding an adapter a
# breaking change.
function Resolve-TestEvidenceEntries {
  param($Result, $Policy)

  $entries = New-Object System.Collections.Generic.List[object]
  if (-not $Result.PSObject.Properties["test_evidence"]) { return $entries }

  foreach ($item in @($Result.test_evidence)) {
    $type = [string]$item.type
    $adapter = $null
    foreach ($candidate in @($Policy.test_evidence_adapters)) {
      if ([string]$candidate.type -eq $type) { $adapter = $candidate; break }
    }

    $verifiable = $false
    $missingFields = @()
    if ($adapter) {
      $verifiable = [bool]$adapter.verifiable
      foreach ($required in @($adapter.requires)) {
        $prop = $item.PSObject.Properties[[string]$required]
        if ((-not $prop) -or [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
          $missingFields += [string]$required
        }
      }
    }

    # A verifiable adapter that is missing the fields making it verifiable is
    # not verifiable. Otherwise `{"type": "ci-check"}` with nothing else would
    # satisfy a required test by naming an adapter rather than by carrying
    # evidence.
    if ($missingFields.Count -gt 0) { $verifiable = $false }

    $entries.Add([pscustomobject]@{
      Type = $type
      Name = [string]$item.name
      Known = ($null -ne $adapter)
      Verifiable = $verifiable
      MissingFields = $missingFields
      Raw = $item
    }) | Out-Null
  }
  return $entries
}
