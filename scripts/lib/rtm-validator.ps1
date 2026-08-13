# Release registry (Release ID + declared TEST-### rows) and row-by-row
# RTM.json traceability validation: every requirement needs its own complete,
# resolvable chain (design/delivery/test/evidence/release), not just "the
# word delivery_ref appears somewhere in the file".

function Get-ReleaseRegistry {
  param([string]$ReleaseText)
  $result = [pscustomobject]@{ ReleaseId = $null; TestIds = @(); TestRows = @() }
  if (-not $ReleaseText) { return $result }
  if ($ReleaseText -match '(?m)^\s*>?\s*Release ID:\s*(REL-\d{3})\s*$') {
    $result.ReleaseId = $Matches[1]
  }
  $testRows = @(Get-TableRowsAfterHeading $ReleaseText '^##\s+Test Summary')
  $result.TestRows = @($testRows | Where-Object { $_.ID -match '^TEST-\d{3}$' })
  $result.TestIds = @($result.TestRows | ForEach-Object { $_.ID.Trim() })
  return $result
}

function Test-TestSummary {
  # H2: a Test Summary row that still says "pending" (or is blank/failed) must
  # not let a Release pass just because a TEST-### id exists somewhere in the
  # table -- Get-ReleaseRegistry used to collect only ids, never Result or
  # Evidence, so an all-pending Test Summary was indistinguishable from an
  # all-passed one to every other check. "skipped" is allowed only with a
  # real reason in Notes (same shape as the Lite rollback waiver).
  param(
    $ReleaseRegistry,
    [string]$Project,
    [string[]]$DecisionIds,
    [string]$Mode
  )

  foreach ($row in @($ReleaseRegistry.TestRows)) {
    $result = "$($row.Result)".Trim().ToLowerInvariant()
    if ($result -eq "skipped") {
      if (Test-PlaceholderValue $row.Notes) {
        Add-Result FAIL "$($row.ID) is marked skipped but Notes does not state a reason" "TEST-RESULT-001"
        continue
      }
      # Micro-hardening: a Notes string alone ("not applicable") was enough to
      # skip a Strict test with no independent proof anyone signed off on that
      # -- Strict now needs the same resolvable Evidence a passed row would.
      if ($Mode -eq "Strict") {
        if (Test-PlaceholderValue $row.Evidence) {
          Add-Result FAIL "$($row.ID) is marked skipped but Strict requires resolvable Evidence, not just a Notes reason" "TEST-RESULT-001"
          continue
        }
        $skipRef = Resolve-Reference -Value $row.Evidence -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $Project -DecisionIds $DecisionIds
        if (-not $skipRef.Type -or -not $skipRef.Resolved) {
          Add-Result FAIL "$($row.ID) is marked skipped but Evidence '$($row.Evidence)' does not resolve to a real reference" "TEST-RESULT-001"
          continue
        }
      }
      Add-Result PASS "$($row.ID) is validly skipped (reason recorded)" "TEST-RESULT-001"
      continue
    }
    if ($result -ne "passed") {
      Add-Result FAIL "$($row.ID) has Result '$($row.Result)', expected passed (or skipped with a reason in Notes)" "TEST-RESULT-001"
      continue
    }
    if (Test-PlaceholderValue $row.Evidence) {
      Add-Result FAIL "$($row.ID) is passed but Evidence is empty" "TEST-EVIDENCE-002"
      continue
    }
    $ref = Resolve-Reference -Value $row.Evidence -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $Project -DecisionIds $DecisionIds
    if (-not $ref.Type -or -not $ref.Resolved) {
      Add-Result FAIL "$($row.ID) is passed but Evidence '$($row.Evidence)' does not resolve to a real reference" "TEST-EVIDENCE-002"
    } else {
      Add-Result PASS "$($row.ID) is passed with resolvable evidence" "TEST-EVIDENCE-002"
    }
  }
}

function Test-TestEvidenceGitGroundTruth {
  # M4 second increment (L2 completion): when the caller supplies
  # -ReleaseDiffBase/-ReleaseDiffHead to validate-project.ps1, a passed Test
  # Summary row whose FILE: evidence is tracked but was NOT changed within the
  # verified base..head range is stale -- it cannot be the output of a test run
  # of this release's work. This is the EXEC-005 stale-evidence reconciliation
  # applied to the release-path Test Summary check, per feeback.md Round 3:
  # severity mirrors APPROVAL-003 (WARN-blocking at Standard, FAIL at Strict),
  # no human-vouch escape hatch on this path, tracked files only. Opt-in: with
  # no refs supplied this function is never called and every existing caller is
  # byte-identical.
  param(
    $ReleaseRegistry,
    [string]$Project,
    [string]$Mode,
    [string]$BaseRef,
    [string]$HeadRef
  )

  $rows = @($ReleaseRegistry.TestRows)
  if ($rows.Count -eq 0) { return }
  # Lite is exempt from the release-path Test Summary rules entirely (the whole
  # TEST-SUMMARY-001 / TEST-RESULT-001 / TEST-EVIDENCE-002 block only runs at
  # Standard/Strict), so this git check does not apply there either -- mirrors
  # APPROVAL-003, which emits no row at Lite.
  if ($Mode -eq "Lite") { return }

  # Collect the passed rows that cite resolvable, in-project FILE: evidence.
  # Only those name a file git can say something about. A TEST-### id, a
  # DEC-###, an ISSUE:n, or a CI: reference names no repository file, and a
  # FILE: reference that is missing or escapes the project is already FAILed
  # by TEST-EVIDENCE-002 / REF-002 -- this check adds nothing there.
  $candidates = New-Object System.Collections.Generic.List[object]
  foreach ($row in $rows) {
    $result = "$($row.Result)".Trim().ToLowerInvariant()
    if ($result -ne "passed") { continue }
    if (Test-PlaceholderValue $row.Evidence) { continue }
    $ref = Resolve-Reference -Value $row.Evidence -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $Project -TestIds $ReleaseRegistry.TestIds
    if ($ref.Type -ne "file" -or -not $ref.Resolved -or $ref.PathEscaped) { continue }
    $candidates.Add($row) | Out-Null
  }
  if ($candidates.Count -eq 0) { return }

  # The project's own repository is the git ground truth: the evidence files
  # and the release's commit range live there. Git answers the project's
  # relationship to its repo root itself (handles symlinks and path casing the
  # way the diff will), so this check needs no separate git-root parameter the
  # way SCOPE-DIFF does -- the project IS in the repository whose history is
  # being compared.
  $gitRoot = (& git -C $Project rev-parse --show-toplevel 2>$null | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($gitRoot)) {
    Add-Result FAIL "Cannot reconcile release test evidence against git ground truth: the project is not inside a git repository, so no commit range can be verified. Supply -ReleaseDiffBase/-ReleaseDiffHead only when the project lives in a git checkout." "TEST-EVIDENCE-003"
    return
  }

  # Both refs must resolve before anything is compared. Same infra-failure
  # class as SCOPE-DIFF-004: the caller asked for a range, so an unresolvable
  # one is a configuration error (and always FAIL, regardless of mode), not a
  # pass.
  $baseSha = (& git -C $gitRoot rev-parse --verify --quiet "$BaseRef^{commit}" 2>$null | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($baseSha)) {
    Add-Result FAIL "Cannot reconcile release test evidence against git ground truth: the base commit ($BaseRef) could not be resolved in this checkout. This is commonly a shallow checkout: actions/checkout defaults to fetch-depth 1, which does not include the base commit. Increase fetch-depth (or use fetch-depth: 0)." "TEST-EVIDENCE-003"
    return
  }
  $headSha = (& git -C $gitRoot rev-parse --verify --quiet "$HeadRef^{commit}" 2>$null | Out-String).Trim()
  if ([string]::IsNullOrWhiteSpace($headSha)) {
    Add-Result FAIL "Cannot reconcile release test evidence against git ground truth: the head commit ($HeadRef) could not be resolved in this checkout." "TEST-EVIDENCE-003"
    return
  }

  # The set of paths changed within the verified range. NUL-separated output
  # so a path containing spaces (or any other character) compares exactly --
  # the same -z discipline as scope-diff-git-adapter.ps1. Raw git stderr goes
  # only to this process's own stderr (the run log), never into a result row.
  $stderrFile = [System.IO.Path]::GetTempFileName()
  $raw = $null
  try {
    $raw = & git -C $gitRoot --no-pager diff --no-color --name-only -z "$baseSha" "$headSha" 2>$stderrFile
    if ($LASTEXITCODE -ne 0) {
      $stderrText = Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
      if ($stderrText) { [Console]::Error.WriteLine($stderrText) }
      Add-Result FAIL "Cannot reconcile release test evidence against git ground truth: git diff exited $($LASTEXITCODE) comparing $baseSha to $headSha. See the run log for the underlying git error." "TEST-EVIDENCE-003"
      return
    }
  } finally {
    Remove-Item -LiteralPath $stderrFile -ErrorAction SilentlyContinue
  }
  $changedPaths = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::Ordinal)
  $rawJoined = if ($raw -is [array]) { $raw -join "`0" } else { [string]$raw }
  foreach ($token in ($rawJoined -split "`0")) {
    if (-not [string]::IsNullOrEmpty($token)) { [void]$changedPaths.Add($token) }
  }

  foreach ($row in $candidates) {
    $evidenceValue = "$($row.Evidence)".Trim()
    # reference-types.json matches the file type with ^FILE:.+$ -- the path is
    # exactly the 5-character prefix stripped, same as Resolve-Reference does.
    $filePath = $evidenceValue.Substring(5).Replace('\', '/')

    # Round 3 decision 3: tracked files only. An untracked/gitignored FILE:
    # reference is invisible to git diff regardless of how fresh it is, so
    # flagging it as stale would be a false positive against a legitimate
    # pattern (e.g. a deliberately gitignored CI report directory). Out of
    # scope entirely -- neither passed nor failed by this check.
    #
    # ls-files --error-unmatch also canonicalizes the path: run from the
    # project directory with --full-name, git itself normalizes . / ..
    # segments and path casing and answers the repo-root-relative path that
    # git diff will name -- no manual prefix joining that could drift from
    # what the diff reports.
    $gitRelPath = (& git -C $Project ls-files --full-name --error-unmatch -- $filePath 2>$null | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRelPath)) { continue }

    if ($changedPaths.Contains($gitRelPath)) {
      Add-Result PASS "$($row.ID) evidence '$gitRelPath' is part of the release's verified commit range" "TEST-EVIDENCE-003"
      continue
    }

    # Not in the range. Distinguish the working-tree states so the reason
    # names the actual defect: a clean file predates the release; a modified
    # or staged file has content that was never part of any commit in it.
    $status = (& git -C $gitRoot status --porcelain -- $gitRelPath 2>$null | Out-String).Trim()
    $uncommittedNote = ""
    if ($status) {
      $uncommittedNote = " The file also has uncommitted changes, so its current content is not part of the verified range."
    }
    $message = "$($row.ID) is passed but cites FILE:evidence '$gitRelPath', which was not changed within the release's verified commit range $BaseRef..$HeadRef — a report that predates this release's work cannot prove the released code passes.$uncommittedNote"
    if ($Mode -eq "Strict") {
      Add-Result FAIL $message "TEST-EVIDENCE-003" -Artifact $gitRelPath
    } else {
      Add-Result WARN $message "TEST-EVIDENCE-003" -Artifact $gitRelPath -Blocking $true
    }
  }
}

function Test-RtmTraceability {
  param(
    [string]$Project,
    [string[]]$ProjectReqIds,
    [string[]]$DeliveryIds,
    [string[]]$DecisionIds,
    $ReleaseRegistry,
    [string[]]$ProjectSourceIds
  )

  $rtmPath = Join-Path $Project "RTM.json"
  if (-not (Test-Path -LiteralPath $rtmPath -PathType Leaf)) { return }

  $rtmRaw = Get-Content -LiteralPath $rtmPath -Raw
  $rtmDoc = $null
  try { $rtmDoc = $rtmRaw | ConvertFrom-Json } catch { $rtmDoc = $null }

  if (-not $rtmDoc -or -not $rtmDoc.schema_version -or -not $rtmDoc.traceability -or @($rtmDoc.traceability).Count -eq 0) {
    Add-Result FAIL "RTM.json is empty, invalid, or missing schema_version/traceability" "RTM-001"
    return
  }

  $rows = @($rtmDoc.traceability)
  $rtmReqIds = @($rows | Where-Object { $_.requirement_id } | ForEach-Object { $_.requirement_id } | Sort-Object -Unique)

  foreach ($reqId in $ProjectReqIds) {
    if ($rtmReqIds -notcontains $reqId) {
      Add-Result FAIL "RTM missing requirement: $reqId" "RTM-002"
    }
  }
  foreach ($rtmReqId in $rtmReqIds) {
    if ($ProjectReqIds -notcontains $rtmReqId) {
      Add-Result FAIL "RTM traceability row references a requirement not in PROJECT.md: $rtmReqId" "RTM-007"
    }
  }

  $seen = @{}
  foreach ($row in $rows) {
    $rid = "$($row.requirement_id)"
    if ($rid -and $seen.ContainsKey($rid)) {
      Add-Result FAIL "RTM has a duplicate traceability row for: $rid" "RTM-007"
    }
    if ($rid) { $seen[$rid] = $true }

    if (-not $row.delivery_ref -or ($DeliveryIds -notcontains $row.delivery_ref)) {
      Add-Result FAIL "RTM row $rid has a broken delivery_ref: $($row.delivery_ref)" "RTM-003"
    }
    if (-not $row.test_ref -or ($ReleaseRegistry.TestIds -notcontains $row.test_ref)) {
      Add-Result FAIL "RTM row $rid has a broken test_ref: $($row.test_ref)" "RTM-004"
    }
    # H3: evidence_ref must be a typed, resolvable reference -- the old check
    # only rejected malformed DEC-### ids, so any free text that did not look
    # like a DEC id ("manual-proof", "finished", "checked-by-team") passed.
    $evidenceRef = "$($row.evidence_ref)"
    if (-not $evidenceRef -or (Test-PlaceholderValue $evidenceRef)) {
      Add-Result FAIL "RTM row $rid has a missing evidence_ref" "RTM-005"
    } else {
      $ref = Resolve-Reference -Value $evidenceRef -ReferenceTypesConfig $script:referenceTypesConfig -ProjectRoot $Project -DecisionIds $DecisionIds
      if (-not $ref.Type) {
        Add-Result FAIL "RTM row $rid has an unrecognized evidence_ref type: $evidenceRef" "RTM-005"
      } elseif (-not $ref.Resolved) {
        Add-Result FAIL "RTM row $rid has an unresolvable evidence_ref: $evidenceRef" "RTM-005"
      }
    }
    if (-not $row.release_ref -or -not $ReleaseRegistry.ReleaseId -or $row.release_ref -ne $ReleaseRegistry.ReleaseId) {
      Add-Result FAIL "RTM row $rid has a broken release_ref: $($row.release_ref)" "RTM-006"
    }

    # H3: complete the chain -- source_ref, design_ref (file existence), and
    # status were never checked, so a row could claim a fabricated source,
    # point design_ref at a missing file, or carry a nonsense status and still
    # pass "row-by-row" validation.
    if (-not $row.source_ref -or ($row.source_ref -notmatch $script:sourceRefRegex)) {
      Add-Result FAIL "RTM row $rid has a missing or malformed source_ref: $($row.source_ref)" "RTM-008"
    } elseif ($ProjectSourceIds -and @($ProjectSourceIds).Count -gt 0) {
      # Micro-hardening: the format check above lets a well-shaped but
      # fabricated id through (e.g. "REQ-20991231 row 999"); cross-check
      # against the Source IDs PROJECT.md's own Source Snapshot/Inventory
      # actually declares, same as PROJECT.md's own requirement rows already
      # are (Test-ProjectSourceSection, REF-001).
      $sourceIdMatch = [regex]::Match($row.source_ref, '(MOM|REQ|TR)-\d{8}')
      if ($sourceIdMatch.Success -and (@($ProjectSourceIds) -notcontains $sourceIdMatch.Value)) {
        Add-Result FAIL "RTM row $rid source_ref '$($row.source_ref)' does not exist in PROJECT.md's Source Snapshot/Inventory" "RTM-008"
      }
    }
    $designRef = "$($row.design_ref)"
    if (-not $designRef -or (Test-PlaceholderValue $designRef)) {
      Add-Result FAIL "RTM row $rid has a missing design_ref" "RTM-009"
    } else {
      $designPath = Get-DesignPathFromRef $designRef
      if (-not $designPath -or -not (Test-Path -LiteralPath (Join-Path $Project $designPath) -PathType Leaf)) {
        Add-Result FAIL "RTM row $rid design_ref does not resolve to an existing design file: $designRef" "RTM-009"
      }
    }
    $validStatuses = @($script:policyEnums.evidence_statuses)
    if (-not $row.status -or ($validStatuses -notcontains $row.status)) {
      Add-Result FAIL "RTM row $rid has an invalid status: $($row.status)" "RTM-010"
    }
  }
}
