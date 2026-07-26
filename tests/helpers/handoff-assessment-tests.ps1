param(
  [string]$RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "../..")).Path
)

# Behaviour tests for scripts/assess-handoff.ps1.
#
# The point of the assessment is that it does NOT collapse readiness into one
# boolean, and that the score cannot be inflated past what the evidence
# supports. Both properties are easy to lose in a refactor and neither is
# covered by the fixture suite, which only checks rule ids and exit codes.

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "../../scripts/lib/pwsh-host.ps1")

$pwshExe = Get-PowerShellHost
if (-not $pwshExe) {
  Write-Host (Get-PowerShellHostMissingMessage)
  exit 127
}

$repo = (Resolve-Path -LiteralPath $RepoPath).Path
$pass = 0
$fail = 0

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail = "")
  if ($Condition) {
    $script:pass++
    Write-Host "[PASS] $Name"
  } else {
    $script:fail++
    Write-Host "[FAIL] $Name$(if ($Detail) { " -- $Detail" })"
  }
}

function Invoke-Assessment {
  param([string]$Fixture, [string]$Mode = "Standard")

  $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $repo "scripts/assess-handoff.ps1"),
    "-ProjectPath", (Join-Path $repo $Fixture), "-Mode", $Mode, "-Format", "Json")

  $previous = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & $pwshExe @psArgs 2>$null
  $ErrorActionPreference = $previous
  return (($output | Out-String) | ConvertFrom-Json)
}

Write-Host "Axiom-PMO Handoff Assessment Tests: $repo"
Write-Host ""

# ---- The headline behaviour: build readiness and demo readiness are separate.
$demo = Invoke-Assessment -Fixture "examples/HANDOFF-DEMO"
Assert-True "demo example: contract is valid" ([bool]$demo.verdicts.'Contract Valid'
) "verdict=$($demo.verdict)"
Assert-True "demo example: ready to start development despite an open before_demo finding" `
  ($demo.verdicts.'Ready to Start Development' -eq $true) "verdict=$($demo.verdict)"
Assert-True "demo example: NOT ready to demo" `
  ($demo.verdicts.'Ready to Demo' -eq $false) "verdict=$($demo.verdict)"
Assert-True "demo example: verdict says build-yes demo-no in words" `
  ($demo.verdict -eq "READY TO BUILD, NOT READY TO DEMO") "got '$($demo.verdict)'"
Assert-True "demo example: an open before_demo finding costs its dimension points" `
  ($demo.score.awarded -lt $demo.score.total) "score=$($demo.score.awarded)/$($demo.score.total)"
Assert-True "demo example: the review is never reported as an approval" `
  (-not [bool]$demo.semantic_review.is_approval)

# ---- Readiness is unknown, not true, when nobody has reviewed.
# This is the finding that matters most to a machine consumer: `verdicts` used
# to report six greens on a project nobody had read, because "no recorded open
# finding" was treated as "no problem".
$noReviewStages = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-review-missing"
Assert-True "missing review: development readiness is unknown, not true" `
  ($null -eq $noReviewStages.verdicts.'Ready to Start Development') `
  "got '$($noReviewStages.verdicts.'Ready to Start Development')'"
Assert-True "missing review: every unknown stage says why" `
  ($noReviewStages.verdict_reasons.'Ready to Start Development' -match "unknown") `
  "got '$($noReviewStages.verdict_reasons.'Ready to Start Development')'"
Assert-True "missing review: contract validity is still a real answer" `
  ($noReviewStages.verdicts.'Contract Valid' -eq $true)

$staleStages = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-review-stale"
Assert-True "stale review: readiness is unknown rather than inherited from the stale review" `
  ($null -eq $staleStages.verdicts.'Ready to Start Development' -or $staleStages.verdicts.'Ready to Start Development' -eq $false)

# ---- A reviewed artifact changing is staleness too, not just the sources.
$staleInputs = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-review-stale-inputs"
Assert-True "editing BUILD-SPEC after review marks the review stale" `
  ([bool]$staleInputs.semantic_review.stale)
Assert-True "stale-by-artifact says which kind of staleness it is" `
  ($staleInputs.semantic_review.stale_reason -match "artifact") `
  "got '$($staleInputs.semantic_review.stale_reason)'"

# ---- Open actions in HANDOFF.md block stages, not only review findings.
$openAction = Invoke-Assessment -Fixture "tests/fixtures/valid-handoff-action-blocks-demo"
Assert-True "open-action fixture passes the gate" ([bool]$openAction.verdicts.'Contract Valid')
Assert-True "an open before_demo action blocks Ready to Demo even with every finding resolved" `
  ($openAction.verdicts.'Ready to Demo' -eq $false) "got '$($openAction.verdicts.'Ready to Demo')'"
Assert-True "an open before_demo action does not block Ready to Start Development" `
  ($openAction.verdicts.'Ready to Start Development' -eq $true)
Assert-True "the blocking open action is named in the output" `
  (@($openAction.semantic_review.open_blockers | Where-Object { $_.origin -eq "open_action" }).Count -gt 0)
Assert-True "open actions and review findings are distinguishable by origin" `
  (@($demo.semantic_review.open_blockers | Where-Object { $_.origin -eq "review_finding" }).Count -gt 0)

# A score that contradicts the verdict printed above it is worse than no score:
# the number is what ends up in a status report.
Assert-True "an open action costs score, not only a stage verdict" `
  ($openAction.score.awarded -lt $openAction.score.total) `
  "score=$($openAction.score.awarded)/$($openAction.score.total) with Ready to Demo = $($openAction.verdicts.'Ready to Demo')"
Assert-True "a project that blocks its own demo never scores full marks" `
  (($openAction.verdicts.'Ready to Demo' -eq $false) -and ($openAction.score.awarded -lt 100))
Assert-True "a non_blocking action costs nothing" `
  ($openAction.score.dimensions | Where-Object { $_.id -eq "source_scope_integrity" } | ForEach-Object { $_.awarded -eq $_.points })

# ---- A finding that names an action is one blocker, not two.
Assert-True "a review finding pointing at an action id is not double-counted" `
  (@($demo.semantic_review.open_blockers | Where-Object { $_.finding_id -eq "OA-002" }).Count -eq 0) `
  "OA-002 is already represented by finding HF-005"

# ---- Cap: no usable review means the score cannot exceed 70.
$noReview = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-review-missing"
Assert-True "missing review: score capped at 70" ($noReview.score.awarded -le 70) "score=$($noReview.score.awarded)"
Assert-True "missing review: cap is named in the output" `
  (@($noReview.score.caps_applied | Where-Object { $_.id -eq "review_absent_or_stale" }).Count -gt 0)
Assert-True "missing review: verdict does not claim plain READY" `
  ($noReview.verdict -eq "CONTRACT VALID, NOT REVIEWED") "got '$($noReview.verdict)'"

$staleReview = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-review-stale"
Assert-True "stale review: reported as stale" ([bool]$staleReview.semantic_review.stale)
Assert-True "stale review: score capped at 70" ($staleReview.score.awarded -le 70) "score=$($staleReview.score.awarded)"

# ---- Cap: an open critical finding before build caps the score at 49 and
# ---- withdraws the claim that development can start.
$blockedBuild = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-open-before-build-critical"
Assert-True "open before_build critical: score capped at 49" `
  ($blockedBuild.score.awarded -le 49) "score=$($blockedBuild.score.awarded)"
Assert-True "open before_build critical: not ready to start development" `
  ($blockedBuild.verdicts.'Ready to Start Development' -eq $false)
Assert-True "open before_build critical: cap is named in the output" `
  (@($blockedBuild.score.caps_applied | Where-Object { $_.id -eq "open_before_build_critical" }).Count -gt 0)

# ---- Cap: a deterministic FAIL is always BLOCKED, whatever the score says.
$deterministic = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-sequence-inverted"
Assert-True "deterministic FAIL: verdict is BLOCKED" ($deterministic.verdict -eq "BLOCKED") "got '$($deterministic.verdict)'"
Assert-True "deterministic FAIL: contract is not valid" ($deterministic.verdicts.'Contract Valid' -eq $false)
Assert-True "deterministic FAIL: every stage verdict is an explicit false, never unknown" `
  (@($deterministic.verdicts.PSObject.Properties | Where-Object { $_.Value -ne $false }).Count -eq 0)

$ownerGap = Invoke-Assessment -Fixture "tests/fixtures/invalid-handoff-workitem-generic-owner"
Assert-True "missing owner: cap is named in the output" `
  (@($ownerGap.score.caps_applied | Where-Object { $_.id -eq "missing_owner_or_sequence" }).Count -gt 0)

# ---- A clean Lite handoff still reports honestly rather than perfectly: Lite
# ---- does not require a review, so it cannot claim a reviewed contract.
$lite = Invoke-Assessment -Fixture "tests/fixtures/valid-handoff-lite" -Mode "Lite"
Assert-True "lite handoff: contract is valid" ($lite.verdicts.'Contract Valid' -eq $true) "verdict=$($lite.verdict)"
Assert-True "lite handoff: unreviewed contract is capped, not scored full marks" `
  ($lite.score.awarded -le 70) "score=$($lite.score.awarded)"

# ---- The score must never be presented as an approval.
Assert-True "score carries its disclaimer" `
  (-not [string]::IsNullOrWhiteSpace($demo.score.disclaimer)) "disclaimer is empty"
Assert-True "disclaimer states the score is not an approval" `
  ($demo.score.disclaimer -match "not an approval")

Write-Host ""
Write-Host "Summary: PASS=$pass FAIL=$fail"
if ($fail -gt 0) { exit 1 }
exit 0
