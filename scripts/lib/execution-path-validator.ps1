# Milestone 7: execution_path is a governed declaration of *current delivery
# strategy* -- development_handoff or governed_ai_execution -- never project
# identity. See docs/concepts/execution-paths.md and DEC-011.
#
# Two rules only:
#   PATH-001  the declaration itself: missing (INFO, defaults to
#             development_handoff) or unrecognized (WARN).
#   PATH-002  the declaration looks stale against an ACTIVE, unresolved
#             execution package. Archived or completed execution evidence
#             must never trigger this -- a project that ran an AI execution,
#             finished it, and moved to a vendor handoff is in a valid state.
#
# Deliberately not in scope here: no artifact-policy.json restructuring (the
# path-artifact delta is empty until Milestone 8 defines EXECUTION-REVIEW.json)
# and no execution-artifact requirement at any gate -- validate-project.ps1
# has never referenced .execution/** at all; that loop is verified separately
# by verify-execution-result.ps1, and PATH-002 reads it read-only.

function Get-ProjectExecutionPath {
  param([string]$ProjectRoot)
  $path = Join-Path $ProjectRoot "PROJECT.md"
  if (-not (Test-Path -LiteralPath $path)) { return $null }
  $text = Get-Content -LiteralPath $path -Raw
  if ($text -match '(?m)^\s*>?\s*Execution path:\s*(.+?)\s*$') {
    return $Matches[1]
  }
  return $null
}

function Test-ExecutionPath {
  param(
    [string]$Project,
    $PolicyEnums,
    $WorkItems
  )

  $declaredRaw = Get-ProjectExecutionPath $Project
  $validPaths = @($PolicyEnums.execution_paths)
  $effectivePath = "development_handoff"

  if (-not $declaredRaw) {
    Add-Result INFO "PROJECT.md does not declare an Execution path; defaulting to development_handoff" "PATH-001"
  } elseif ($validPaths -notcontains $declaredRaw) {
    Add-Result WARN "PROJECT.md Execution path '$declaredRaw' is not a recognized execution path ($($validPaths -join ' / '))" "PATH-001"
  } else {
    $effectivePath = $declaredRaw
    Add-Result PASS "Execution path declared: $effectivePath" "PATH-001"
  }

  # PATH-002 only has something to say when the project is on the Development
  # Handoff path but an execution package suggests the AI-execution path is
  # actually the current one.
  if ($effectivePath -ne "development_handoff") { return }

  $executionRoot = Join-Path $Project ".execution"
  if (-not (Test-Path -LiteralPath $executionRoot -PathType Container)) { return }

  $doneItemIds = @($WorkItems | Where-Object { $_.Status -eq "Done" } | ForEach-Object { $_.ID })

  Get-ChildItem -LiteralPath $executionRoot -Directory | ForEach-Object {
    $workItemId = $_.Name
    $contractPath = Join-Path $_.FullName "EXECUTION-CONTRACT.json"
    $resultPath = Join-Path $_.FullName "EXECUTION-RESULT.json"

    # No contract: nothing was ever exported for this id, or the directory is
    # unrelated. Not this rule's concern.
    if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) { return }
    # A result already exists: the execution ran to completion (verified or
    # not is EXEC-*'s question, not this one) -- treat it as resolved history,
    # not an active package, so a legitimate switch back to Development
    # Handoff does not warn forever.
    if (Test-Path -LiteralPath $resultPath -PathType Leaf) { return }
    # The work item itself is Done: also resolved history by the project's
    # own record, even without a result artifact on disk.
    if ($doneItemIds -contains $workItemId) { return }

    Add-Result WARN "This project declares Development Handoff, but an active, unresolved execution package exists for $workItemId. Confirm the Execution path declaration is current." "PATH-002" -ItemId $workItemId
  }
}
