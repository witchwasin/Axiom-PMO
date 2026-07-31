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

# Normalizes `test_evidence` entries into a uniform shape: which adapter type
# it claims to be, whether policy knows that type, and whether the fields the
# adapter requires are even present. Deliberately does NOT decide whether the
# evidence actually verifies -- that requires opening files, hashing bytes,
# parsing XML, and querying a live API, none of which belong in a "pure bytes
# to structure" schema file (see this file's own header comment). Real
# verification is scripts/lib/execution-contract-evidence.ps1's
# Test-EvidenceEntryVerified, called once per entry by the validator.
#
# This function's job is narrower than its previous version's: it used to
# also set a `Verifiable` flag straight from `policy.test_evidence_adapters[].verifiable`,
# which is exactly the FATAL gap Sol's review found -- that flag meant "this
# adapter type is capable of being verified," not "this entry was verified,"
# and the validator was trusting it as the latter. Renamed to `FieldsPresent`
# so a future reader cannot make the same mistake by reading the field name.
#
# An unknown adapter type is treated as unverifiable rather than rejected
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

    $missingFields = @()
    if ($adapter) {
      foreach ($required in @($adapter.requires)) {
        $prop = $item.PSObject.Properties[[string]$required]
        if ((-not $prop) -or [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
          $missingFields += [string]$required
        }
      }
    }

    # Provenance travels with the entry from here on. It answers a different
    # question from FieldsPresent or from the later Test-EvidenceEntryVerified
    # check: not "is this well-formed" or "does the artifact check out", but
    # "does this prove anything about WHO produced it". Conflating those two
    # is what let the same defect ship twice -- see the policy's
    # review_history.
    $provenance = "agent-claimed"
    if ($adapter -and -not [string]::IsNullOrWhiteSpace([string]$adapter.provenance)) {
      $provenance = [string]$adapter.provenance
    }

    $entries.Add([pscustomobject]@{
      Type = $type
      Name = [string]$item.name
      Known = ($null -ne $adapter)
      FieldsPresent = ($adapter -and $missingFields.Count -eq 0)
      MissingFields = $missingFields
      Provenance = $provenance
      Raw = $item
    }) | Out-Null
  }
  return $entries
}

# --- decision-record resolution (M5, MAJOR fix) ------------------------------
#
# A human-only authority claim citing a decision_ref used to be accepted the
# moment the field was non-empty -- "DEC-999-NOT-REAL" passed. Resolving it
# for real means answering three separate questions, and the answer to each
# has to be a hard no, not a best-effort maybe:
#
#   1. Is the reference even shaped like a decision id?
#   2. Does exactly one row with that id exist in the project's
#      decision-log.md? (Zero is not found; more than one is ambiguous, and
#      an ambiguous citation is not a resolved one.)
#   3. Requires the caller separately check whether decision-log.md itself
#      was among the files changed in the execution range under
#      verification -- a decision the same commits could have introduced
#      cannot serve as independent human authority for those commits. That
#      check needs the git observation and lives in the validator, not here.
#
# Depends on markdown-table-parser.ps1 (Get-TableRowsAfterHeading) and
# markdown-files.ps1 (Read-MarkdownText) -- callers must dot-source both.

function Read-DecisionLog {
  param([Parameter(Mandatory = $true)][string]$ProjectPath)

  $path = Join-Path $ProjectPath "decision-log.md"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    return [pscustomobject]@{ Present = $false; Rows = @(); Path = $path }
  }

  $text = Read-MarkdownText -Path $path -Raw
  # Matches both the framework-level heading ("# Decision Log - Axiom-PMO
  # (framework-level)") and the project template's ("# Decision Log -
  # <PROJECT-CODE>") -- the table always follows the document's single H1,
  # never a nested "## " section, so anchoring on "# Decision Log" is the
  # stable part of both.
  $rows = Get-TableRowsAfterHeading -Text $text -HeadingPattern '(?m)^#\s+Decision Log'
  return [pscustomobject]@{ Present = $true; Rows = $rows; Path = $path }
}

function Resolve-DecisionRecord {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$DecisionRef
  )

  $result = [pscustomobject]@{ Found = $false; Row = $null; Reason = $null; LogPath = $null }

  $trimmed = "$DecisionRef".Trim()
  if ([string]::IsNullOrWhiteSpace($trimmed)) {
    $result.Reason = "empty"
    return $result
  }
  if ($trimmed -notmatch '^DEC-\d+$') {
    $result.Reason = "'$trimmed' is not a well-formed DEC-### id"
    return $result
  }

  $log = Read-DecisionLog -ProjectPath $ProjectPath
  $result.LogPath = $log.Path
  if (-not $log.Present) {
    $result.Reason = "no decision-log.md exists in this project"
    return $result
  }

  $matches = @($log.Rows | Where-Object { ([string]$_.'Decision ID').Trim() -eq $trimmed })
  if ($matches.Count -eq 0) {
    $result.Reason = "'$trimmed' does not appear in decision-log.md"
    return $result
  }
  if ($matches.Count -gt 1) {
    $result.Reason = "'$trimmed' appears $($matches.Count) times in decision-log.md, which is ambiguous"
    return $result
  }

  $result.Found = $true
  $result.Row = $matches[0]
  return $result
}
