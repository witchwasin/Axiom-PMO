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
    [string]$Today = (Get-Date -Format "yyyy-MM-dd")
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
  Set-Content -LiteralPath $projectFile -Value $text -Encoding utf8 -NoNewline

  # --- DELIVERY.md ---
  $deliveryFile = Join-Path $ProjectPath "DELIVERY.md"
  $text = Get-Content -LiteralPath $deliveryFile -Raw
  $text = $text -replace '- Task source of truth: `file` / `github`', '- Task source of truth: `file`'
  $reviewStage = if ($Mode -eq "Lite") { "none" } else { "qa" }
  $strictTrigger = if ($Mode -eq "Strict") { "permission" } else { "none" }
  $designRef = if ($Mode -eq "Lite") { "not_required" } else { "DESIGN/FLOW.puml" }
  $row = "| D-001 | $Mode | $strictTrigger | E2E fixture work item | E2E PM | E2E feature | REQ-001 | $designRef | Happy path completes | Happy path | E2E Dev | high | Done | $reviewStage | DEC-003 | e2e |"
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
