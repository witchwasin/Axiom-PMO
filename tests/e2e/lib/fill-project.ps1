# P5.2: deterministic filler for a freshly generated project (scripts/new-project.ps1
# output). Replaces every template placeholder with fixed content -- no copying an
# example project over the generated one -- so the E2E run actually exercises the
# real template -> generator -> validator schema contract instead of hiding
# mismatches behind curated example files (this is exactly how the RTM.yaml vs
# RTM.json schema mismatch stayed invisible in Round 1).

function Set-E2EProjectContent {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][ValidateSet("Lite", "Standard", "Strict")][string]$Mode,
    [Parameter(Mandatory = $true)][string]$ProjectCode,
    [string]$Today = (Get-Date).ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
  )

  $momId = "MOM-20260710"
  $reqId = "REQ-20260710"

  # --- PROJECT.md ---
  $projectFile = Join-Path $ProjectPath "PROJECT.md"
  $text = Get-Content -LiteralPath $projectFile -Raw
  $text = $text -replace '> Status: draft.*', "> Status: release-approved"
  $text = $text -replace '<PM/PO>', "E2E PM"
  $text = $text -replace '<YYYY-MM-DD>', $Today
  $text = $text -replace 'MOM-YYYYMMDD', $momId
  $text = $text -replace 'REQ-YYYYMMDD', $reqId
  $text = $text -replace '<sha256>', ("0" * 64)
  $text = $text -replace '<ISO-8601>', "$Today`T09:00:00+07:00"
  $text = $text -replace '> <Who will achieve what outcome by when, measured how\?>', "> E2E fixture project validates the generator-to-Release path end to end."
  $text = $text -replace '`source/MOM/<file>`', "``source/MOM/mom.md``"
  $text = $text -replace '`source/REQ/<file>`', "``source/REQ/req.md``"
  # new-project.ps1 already substitutes bare "YYYY-MM-DD" with the real date
  # for PROJECT.md before this filler runs, so only the bracketed placeholder
  # text itself is left to replace here.
  $text = $text -replace '<meeting purpose>', "E2E kickoff"
  $text = $text -replace '<source note>', "E2E requirement source"
  $text = $text -replace '> Task source: file / github', "> Task source: file"
  $text = $text -replace '<atomic, testable requirement>', "User can complete the E2E happy path"
  $text = $text -replace '<Explicit non-goal>', "Out-of-scope E2E item"
  $text = $text -replace '<rule>', "E2E business rule"
  $text = $text -replace '<assumption>', "E2E environment is stable"
  $text = $text -replace '<how to validate>', "Manual smoke check"
  $text = $text -replace '<question>', "None outstanding for the fixture"
  $text = $text -replace '<scope/design/test impact>', "none"
  $text = $text -replace '<risk>', "E2E fixture risk"
  $text = $text -replace '<impact>', "low"
  $text = $text -replace '<mitigation>', "None needed for a fixture"
  $text = $text -replace '<owner>', "E2E PM"
  $text = $text -replace '<approver name>', "E2E Approver"
  $text = $text -replace '(?m)^\| (Scope Approved|Design Ready|Release Approved) \| pending', '| $1 | approved'
  # Lite gets no decision-log, so its approval evidence must be a typed ref that
  # resolves without one (H4). Swap the template's DEC-00N approval evidence for
  # an externally-verified ISSUE ref; Standard/Strict keep DEC refs, which their
  # generated decision-log resolves.
  if ($Mode -eq "Lite") {
    $text = $text -replace '(\| (?:Scope Approved|Design Ready|Release Approved) \| approved \|[^|]*\|[^|]*\|[^|]*\| )DEC-00(\d) \|', '$1ISSUE:10$2 |'
  }
  Set-Content -LiteralPath $projectFile -Value $text -Encoding utf8 -NoNewline

  # --- DELIVERY.md ---
  $deliveryFile = Join-Path $ProjectPath "DELIVERY.md"
  $text = Get-Content -LiteralPath $deliveryFile -Raw
  $text = $text -replace '- Task source of truth: `file` / `github`', '- Task source of truth: `file`'
  $reviewStage = if ($Mode -eq "Lite") { "none" } else { "qa" }
  $strictTrigger = if ($Mode -eq "Strict") { "permission" } else { "none" }
  $designRef = if ($Mode -eq "Lite") { "not_required" } else { "DESIGN/FLOW.puml" }
  # Lite work-item evidence must resolve without a decision-log (H4); use a
  # typed ISSUE ref. Standard/Strict use DEC-003 which their decision-log resolves.
  $workItemEvidence = if ($Mode -eq "Lite") { "ISSUE:123" } else { "DEC-003" }
  $row = "| D-001 | $Mode | $strictTrigger | E2E fixture work item | E2E PM | E2E feature | REQ-001 | $designRef | Happy path completes | Happy path | E2E Dev | high | Done | $reviewStage | $workItemEvidence | e2e |"
  # Literal (non-regex) replacement text: escape $ for -replace's own group syntax.
  $rowLiteral = $row.Replace('$', '$$')
  $text = $text -replace '(?m)^\| D-001 \|.*\|\s*$', $rowLiteral
  Set-Content -LiteralPath $deliveryFile -Value $text -Encoding utf8 -NoNewline

  # --- decision-log.md (generated only for Strict by new-project.ps1; Standard
  #     also needs one so DEC-### approval/evidence references resolve) ---
  $decisionFile = Join-Path $ProjectPath "decision-log.md"
  if ($Mode -ne "Lite") {
    $decisionText = @"
# Decision Log - $ProjectCode

| ID | Decision | Owner | Date |
|---|---|---|---|
| DEC-001 | Scope approved. | E2E PM | $Today |
| DEC-002 | Design approved. | E2E PM | $Today |
| DEC-003 | Release approved. | E2E PM | $Today |
"@
    Set-Content -LiteralPath $decisionFile -Value $decisionText -Encoding utf8 -NoNewline
  }

  # --- RAID-log.md (Strict only, from generator) ---
  if ($Mode -eq "Strict") {
    $raidFile = Join-Path $ProjectPath "RAID-log.md"
    $raidText = @"
# RAID Log - $ProjectCode

| ID | Type | Description | Owner | Status |
|---|---|---|---|---|
| R-001 | risk | E2E fixture risk, already mitigated. | E2E PM | closed |
"@
    Set-Content -LiteralPath $raidFile -Value $raidText -Encoding utf8 -NoNewline
  }

  # --- RELEASE.md (Standard/Strict) ---
  if ($Mode -ne "Lite") {
    $releaseFile = Join-Path $ProjectPath "RELEASE.md"
    $text = Get-Content -LiteralPath $releaseFile -Raw
    $text = $text -replace '<Decision ID or MOM>', "DEC-003"
    # H2: Test Summary rows default to "pending" with no evidence; a real
    # release needs a real result, not just an ID the RTM can point at.
    $text = $text -replace '\|\s*(TEST-\d{3})\s*\|([^|]*)\|\s*pending\s*\|\s*\|\s*\|', '| $1 |$2| passed | DEC-003 |'
    $qaRow = "| QA | approved | E2E QA Lead | QA Lead | $Today | DEC-003 |"
    $text = $text -replace '\| QA \| pending \| <reviewer> \| QA Lead \| YYYY-MM-DD \| <evidence ref> \|', $qaRow
    if ($Mode -eq "Strict") {
      $text = $text -replace "($([regex]::Escape($qaRow)))", "`$1`n| Security | approved | E2E Security Lead | Security Reviewer | $Today | DEC-003 |"
    }
    $text = $text -replace '\| <rollback trigger> \| <owner> \| <numbered rollback steps> \| <how rollback is verified> \| <evidence ref> \|', "| Fixture release blocker | E2E Tech Lead | Revert the E2E change | Fixture no longer shows the change | DEC-003 |"
    $text = $text -replace '\| Release Approved \| pending \| <approver name> \| Product Owner \| YYYY-MM-DD \| DEC-001 \|', "| Release Approved | approved | E2E Approver | Product Owner | $Today | DEC-003 |"
    Set-Content -LiteralPath $releaseFile -Value $text -Encoding utf8 -NoNewline
  }

  # --- RTM.json (Strict only) ---
  if ($Mode -eq "Strict") {
    $rtmFile = Join-Path $ProjectPath "RTM.json"
    $rtmDoc = [pscustomobject]@{
      schema_version = "1.0"
      project = $ProjectCode
      traceability = @(
        [pscustomobject]@{
          requirement_id = "REQ-001"
          source_ref = "$momId item-1"
          design_ref = "DESIGN/FLOW.puml"
          delivery_ref = "D-001"
          test_ref = "TEST-001"
          evidence_ref = "DEC-003"
          release_ref = "REL-001"
          status = "verified"
        }
      )
    }
    ($rtmDoc | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $rtmFile -Encoding utf8 -NoNewline
  }

  # --- DESIGN/WIREFRAME.md (Standard/Strict) ---
  if ($Mode -ne "Lite") {
    $wireframeFile = Join-Path $ProjectPath "DESIGN/WIREFRAME.md"
    if (Test-Path -LiteralPath $wireframeFile) {
      $text = Get-Content -LiteralPath $wireframeFile -Raw
      $text = $text -replace '<PROJECT-CODE>', $ProjectCode
      $text = $text -replace '<screen>', "E2E screen"
      $text = $text -replace '<Screen Name>', "E2E Screen"
      Set-Content -LiteralPath $wireframeFile -Value $text -Encoding utf8 -NoNewline
    }
  }

  # --- source/ (real files so REQ-001's Source Ref and the Others/ folder
  #     both resolve; a TODO here must never block Release). ---
  New-Item -ItemType Directory -Force -Path (Join-Path $ProjectPath "source/MOM") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $ProjectPath "source/REQ") | Out-Null
  "# MOM $Today`n`nTODO: attach recording." | Set-Content -LiteralPath (Join-Path $ProjectPath "source/MOM/mom.md") -Encoding utf8 -NoNewline
  "# REQ notes`n`nSee $momId item-1." | Set-Content -LiteralPath (Join-Path $ProjectPath "source/REQ/req.md") -Encoding utf8 -NoNewline
}

# P1.1 (v1.1): deterministic filler for the handoff artifacts that
# scripts/new-project.ps1 -IncludeHandoff generates. Same principle as
# Set-E2EProjectContent: fill the real templates rather than copying a curated
# example over them, so the E2E run actually proves the
# template -> generator -> Handoff gate contract holds.
function Set-E2EHandoffContent {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][ValidateSet("Lite", "Standard", "Strict")][string]$Mode,
    [Parameter(Mandatory = $true)][string]$ProjectCode,
    [string]$Today = (Get-Date).ToString("yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
  )

  $handoffFile = Join-Path $ProjectPath "HANDOFF.md"
  $text = Get-Content -LiteralPath $handoffFile -Raw

  $text = $text -replace '- Handoff Owner: <Name \(Role\)>', "- Handoff Owner: E2E Delivery Lead"
  $text = $text -replace '- Named Integrator: <Name \(Role\)>', "- Named Integrator: E2E Senior Engineer"

  $text = $text -replace '\| <what it is> \| <D-001> \| <why it matters to the target milestone> \| <Name> \|',
    "| E2E feature | D-001 | Proves the generated project reaches the Handoff gate | E2E Dev |"
  $text = $text -replace '\| <what it is> \| <deferred / do-not-build> \| <why> \| <DEC-001> \|',
    "| Second E2E feature | deferred | Out of this fixture slice | DEC-002 |"
  $text = $text -replace '\| <constraint> \| <technical / commercial / legal / operational> \| <MOM-20260101 item 3> \|',
    "| Fixture must validate offline | technical | MOM-20260710 item-1 |"
  $text = $text -replace '\| 1 \| <D-001> \| none \| <Name> \| <shared prerequisite> \|',
    "| 1 | D-001 | none | E2E Dev | Only work item in the fixture |"
  $text = $text -replace '(?m)^\| 2 \| <D-002> \| <D-001> \| <Name> \| <consumer> \|\r?\n', ""
  $text = $text -replace '\| <dev / demo / pilot> \| <device, OS, browser and version> \| <how it is served: localhost, HTTPS via proxy, packaged app> \| <DEC-001> \|',
    "| demo | Desktop Chrome 126 | Served over HTTPS from the fixture host | DEC-002 |"
  $text = $text -replace '\| Demo Date \| <YYYY-MM-DD> \|', "| Demo Date | $Today |"
  $text = $text -replace '\| Demo Device \| <the actual hardware it runs on> \|', "| Demo Device | Fixture desktop, Chrome 126 |"
  $text = $text -replace '\| Integrator \| <Name> \|', "| Integrator | E2E Senior Engineer |"
  $text = $text -replace '\| Capacity \| <person-days available before the date> \|', "| Capacity | 1 person-day |"
  $text = $text -replace '\| Reset Path \| <how to return to a clean demo state, and how long it takes> \|',
    "| Reset Path | Regenerate the fixture project; takes under a minute |"
  $text = $text -replace '\| Degraded Path \| <what is shown if the primary path fails live> \|',
    "| Degraded Path | Show the recorded validator output instead |"
  $text = $text -replace '\| <criterion> \| <how it is verified> \| <Name> \|',
    "| Handoff gate passes | scripts/validate-project.ps1 -Gate Handoff | E2E Dev |"
  $text = $text -replace '\| OA-001 \| <what is unresolved> \| <Name> \| <before_demo> \| <open> \|',
    "| OA-001 | Confirm the fixture host is reachable | E2E Delivery Lead | before_demo | open |"
  $text = $text -replace '<nothing / list>', "nothing"
  Set-Content -LiteralPath $handoffFile -Value $text -Encoding utf8 -NoNewline

  if ($Mode -ne "Lite") {
    $specFile = Join-Path $ProjectPath "DESIGN/BUILD-SPEC.md"
    $text = Get-Content -LiteralPath $specFile -Raw

    # Tables first: their cells carry enum values the generic sweep below
    # would flatten into prose.
    $text = $text -replace '\| <rear camera / offline read / file export> \| <AC-002> \| <how it is actually served> \| <DEC-001> \|',
      "| Local file read | AC-001 | Same-origin fetch over HTTPS | DEC-002 |"
    $text = $text -replace '\| <Part> \| <quantity_on_hand> \| <integer> \| <pieces> \| <1 per part per location> \| <>= 0> \|',
      "| Record | count | integer | items | 1 per record | >= 0 |"
    $text = $text -replace '\| <element> \| <yes / no> \| <DEC-001 or .not applicable.> \| <DEC-002 or .retained with the record.> \|',
      "| Record identifier | no | not applicable | retained with the record |"
    $text = $text -replace '\| AC-001 \| <REQ-001> \| <Given \.\.\., when \.\.\., then \.\.\.> \| <automated> \| <seed name> \| <how to reset> \|',
      "| AC-001 | REQ-001 | Given a seeded record, when it is read, then the count is returned | automated | e2e-seed | Regenerate the fixture |"

    # Everything else in this template is prose guidance in angle brackets.
    # One deterministic sentence keeps the section non-empty and placeholder-free.
    $text = [regex]::Replace($text, '(?m)^<[^>\r\n]+>$', "Specified deterministically by the E2E fixture.")
    Set-Content -LiteralPath $specFile -Value $text -Encoding utf8 -NoNewline
  }

  # Both digests, computed after every other artifact is final -- exactly what a
  # real reviewer does with scripts/handoff-digest.ps1. Computing them earlier
  # would record a review of files this function is about to rewrite.
  $reviewFile = Join-Path $ProjectPath "HANDOFF-REVIEW.json"
  $projectText = Get-Content -LiteralPath (Join-Path $ProjectPath "PROJECT.md") -Raw
  $digest = Get-SourceSnapshotDigest -ProjectText $projectText
  $repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../../..")).Path
  $handoffPolicy = (Get-Content -LiteralPath (Join-Path $repoRoot "pmo-config/handoff-policy.json") -Raw | ConvertFrom-Json)
  $inputDigest = Get-ReviewInputDigest -Project $ProjectPath -HandoffPolicy $handoffPolicy

  $lensIds = @(
    "value_and_scope_slice", "capability_lifecycle", "data_cardinality_and_units",
    "state_transitions_and_rollback", "concurrency_and_idempotency", "dependencies_and_build_order",
    "ownership_and_capacity", "acceptance_seed_reachability", "automated_manual_test_split",
    "privacy_and_data_classification", "environment_and_device_constraints",
    "demo_startup_reset_and_recovery"
  )
  $review = [pscustomobject]@{
    schema_version = "1.0"
    project_code = $ProjectCode
    reviewed_at = $Today
    reviewer_kind = "ai"
    reviewer = "e2e fixture"
    handoff_target = "demo"
    source_snapshot = [pscustomobject]@{
      source_ids = @("MOM-20260710", "REQ-20260710")
      digest = $digest
    }
    review_inputs = [pscustomobject]@{ digest = $inputDigest }
    lenses = @($lensIds | ForEach-Object { [pscustomobject]@{ lens = $_; status = "reviewed" } })
    findings = @()
    recommendation = [pscustomobject]@{
      ready_to_start_development = $true
      ready_to_demo = $true
      notes = "E2E fixture: no findings raised."
    }
  }
  ($review | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $reviewFile -Encoding utf8 -NoNewline
}
