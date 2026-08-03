# Milestone 8.1: Adversarial Review Evidence.
#
# EXECUTION-REVIEW.json is candidate evidence, never authority (see
# pmo-config/adversarial-review-policy.json core_principle). AREV-001..006
# check whether the artifact is structurally sound and whose provenance it
# carries -- never whether its content is thorough, correct, or intelligent,
# which is not a deterministic question. A recorded verdict never changes the
# exit code this function's caller computes; only FAIL-level AREV-* rows do,
# exactly like every other rule family in this validator.
#
# Reuses rather than reinvents: Get-ExecutionFileDigest, Resolve-DecisionRecord
# and Test-DecisionAuthorityBinding (execution-contract-schema.ps1),
# Invoke-NativeCapture and Get-GitHubOwnerRepo (execution-contract-evidence.ps1)
# are all dot-sourced by the same callers that dot-source this file and are
# used here unchanged.

function Read-AdversarialReviewPolicy {
  param([Parameter(Mandatory = $true)][string]$FrameworkRoot)

  $policyPath = Join-Path $FrameworkRoot "pmo-config/adversarial-review-policy.json"
  if (-not (Test-Path -LiteralPath $policyPath -PathType Leaf)) {
    throw "Missing runtime adversarial-review policy config: $policyPath"
  }
  return (Get-Content -LiteralPath $policyPath -Raw | ConvertFrom-Json)
}

# Read a git blob's EXACT bytes, without letting PowerShell reconstruct them
# from captured text.
#
# The obvious version -- `Invoke-NativeCapture { git show ... }` then
# `$output | Out-String` -- is wrong, and wrong in a way that only shows up on
# Windows. `git show` returns an array of lines with their terminators
# stripped; `Out-String` rejoins them using the PLATFORM newline. On Linux and
# macOS that is LF, which happens to reproduce a normal LF-terminated file
# byte-for-byte, so a SHA-256 over it matches the file's real digest and every
# test passes. On Windows the same code rejoins with CRLF, so the recomputed
# digest can never equal the pinned digest of the real file, and a legitimate
# pinned workflow is rejected as tampered.
#
# CI caught exactly this: `pmo-checks` and `pmo-checks-windows-pwsh7` failed
# the two AREV-003 legitimate-match cases while the Linux and macOS pwsh7 jobs
# passed on identical code. It is the same class of defect
# docs/architecture/powershell-portability.md exists to prevent -- a construct
# that looks ordinary and behaves differently per host, silently.
#
# Start-Process with -RedirectStandardOutput writes the child's stdout to a
# file at the OS level, with no PowerShell string decoding in the path, so the
# bytes read back are the blob's actual bytes. Returns $null on any failure;
# callers treat that as "could not be read", never as a pass.
function Get-GitBlobBytes {
  param(
    [Parameter(Mandatory = $true)][string]$GitRepoRoot,
    [Parameter(Mandatory = $true)][string]$Revision
  )

  $outFile = [System.IO.Path]::GetTempFileName()
  $errFile = [System.IO.Path]::GetTempFileName()
  try {
    # Quoted explicitly: Windows PowerShell 5.1's Start-Process joins
    # -ArgumentList with spaces and does not quote for you, so a repository
    # path containing a space would otherwise split into two arguments.
    # `cat-file blob`, not `show`: `git show <rev>:<path>` can apply
    # working-tree conversion (eol/smudge filters), which makes the bytes it
    # emits depend on the caller's git configuration. `cat-file blob` emits
    # the stored object, so the digest is a property of the commit rather
    # than of whoever happens to be verifying it.
    $proc = Start-Process -FilePath "git" `
      -ArgumentList @("-C", "`"$GitRepoRoot`"", "cat-file", "blob", "`"$Revision`"") `
      -RedirectStandardOutput $outFile -RedirectStandardError $errFile `
      -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { return $null }
    return [System.IO.File]::ReadAllBytes($outFile)
  } catch {
    return $null
  } finally {
    Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
  }
}

function Read-ExecutionReview {
  param([Parameter(Mandatory = $true)][string]$Path)

  $out = [pscustomobject]@{ Present = $false; Valid = $false; Document = $null; Digest = $null; Error = $null }
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $out }
  $out.Present = $true
  $out.Digest = Get-ExecutionFileDigest -Path $Path
  try {
    $raw = Get-Content -LiteralPath $Path -Raw
    $out.Document = $raw | ConvertFrom-Json
    $out.Valid = $true
  } catch {
    $out.Error = $_.Exception.Message
  }
  return $out
}

# Effective mode, read the same way scripts/lib/mode-resolver.ps1 computes it
# for validate-project.ps1, but silently: this function must not itself emit
# MODE-001/002/003 diagnostics into a report scoped to "did this execution
# stay inside its contract," which is a different question mode-resolver.ps1
# already answers elsewhere. Requires Get-ProjectDefaultMode and
# Get-DeliveryModeSignals from mode-resolver.ps1 to be dot-sourced by the
# caller.
function Get-EffectiveModeForVerification {
  param([Parameter(Mandatory = $true)][string]$ProjectPath)

  $modeRank = @{ "Lite" = 1; "Standard" = 2; "Strict" = 3 }
  $projectDefaultModeRaw = Get-ProjectDefaultMode $ProjectPath
  $effectiveMode = if ($projectDefaultModeRaw -and $modeRank.ContainsKey($projectDefaultModeRaw)) { $projectDefaultModeRaw } else { "Standard" }
  $deliverySignals = Get-DeliveryModeSignals $ProjectPath $modeRank
  if ($deliverySignals.HighestMode -and $modeRank[$deliverySignals.HighestMode] -gt $modeRank[$effectiveMode]) {
    $effectiveMode = $deliverySignals.HighestMode
  }
  if ($deliverySignals.HasStrictTrigger) { $effectiveMode = "Strict" }
  return $effectiveMode
}

# The bindings docs/architecture/adversarial-review.md §3.3 requires before an
# externally-observed review means anything stronger than "a CI job on this
# commit happened to succeed." Independent AI Reviewer's independent review of this branch found
# the first version of this function FATAL: it verified head_sha, status,
# conclusion, the artifact digest, and the pinned workflow's content digest,
# but never verified that the cited check_run_id was actually PRODUCED BY the
# pinned workflow -- an unrelated successful check run on the same commit,
# primed to print the review artifact's digest in its own output, passed
# every check while the pinned workflow never ran. Demonstrated, not
# theorised: exactly the class of gap Milestone 5's round-1/round-2 reviews
# found in EXECUTION-RESULT.json's own evidence adapters, one level up.
#
# The fix resolves the check run to the GitHub Actions workflow run that
# actually produced it (check run -> check_suite.id -> workflow runs under
# that check suite), and requires ITS path to be the pinned workflow path.
# This also subsumes the "check name" binding Test-CiCheckEvidence uses for
# ci-check evidence: once the check run is proven to come from the pinned
# workflow, a same-named-but-different-workflow forgery is impossible by
# construction, so a separate name comparison would be redundant.
function Test-ExternallyObservedReviewBinding {
  param(
    $Review,
    [string]$ReviewPath,
    [Parameter(Mandatory = $true)][string]$GitRepoRoot,
    [Parameter(Mandatory = $true)][string]$FrameworkRoot,
    $ReviewArtifactPolicy
  )

  $result = [pscustomobject]@{ Verified = $false; Reason = $null }
  $binding = $ReviewArtifactPolicy.externally_observed_binding
  if (-not $binding -or -not $binding.pinned_workflow_digest) {
    $result.Reason = "no pinned_workflow_digest is configured in pmo-config/adversarial-review-policy.json -- an externally-observed review cannot be trusted for a required check until an organization pins its own review workflow's digest"
    return $result
  }

  $checkRunId = [string]$Review.provenance.check_run_id
  if ([string]::IsNullOrWhiteSpace($checkRunId)) {
    $result.Reason = "provenance.tier is externally-observed but provenance.check_run_id is missing"
    return $result
  }

  $ghCommand = Get-Command "gh" -ErrorAction SilentlyContinue
  if (-not $ghCommand) {
    $result.Reason = "no GitHub API context available (gh CLI not found on PATH) -- cannot independently verify, so this is unverified rather than a pass"
    return $result
  }
  $remote = Invoke-NativeCapture { git -C $GitRepoRoot remote get-url origin }
  $remoteUrl = $remote.Output
  if ($remoteUrl -is [array]) { $remoteUrl = $remoteUrl[0] }
  if ($remote.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace([string]$remoteUrl)) {
    $result.Reason = "could not resolve a git remote to query -- cannot independently verify"
    return $result
  }
  $ownerRepo = Get-GitHubOwnerRepo -RemoteUrl ([string]$remoteUrl)
  if (-not $ownerRepo) {
    $result.Reason = "the git remote is not a recognizable GitHub URL -- cannot independently verify"
    return $result
  }

  $parsedId = 0L
  if (-not [long]::TryParse($checkRunId, [ref]$parsedId)) {
    $result.Reason = "check_run_id '$checkRunId' is not a valid integer"
    return $result
  }
  $runApi = Invoke-NativeCapture { gh api "repos/$ownerRepo/check-runs/$parsedId" }
  if ($runApi.ExitCode -ne 0) {
    $result.Reason = "the GitHub API query for check run $parsedId failed -- cannot independently verify (network, auth, or the run does not exist)"
    return $result
  }
  $run = $null
  try {
    $run = ($runApi.Output | Out-String) | ConvertFrom-Json
  } catch {
    $result.Reason = "the GitHub API response for check run $parsedId could not be parsed"
    return $result
  }
  if ([string]$run.head_sha -ne [string]$Review.head_sha) {
    $result.Reason = "check run $parsedId belongs to commit $($run.head_sha), not $($Review.head_sha) -- cannot cite it as evidence for a different commit"
    return $result
  }
  if ([string]$run.status -ne "completed" -or [string]$run.conclusion -ne "success") {
    $result.Reason = "check run $parsedId has not completed successfully (status: $($run.status), conclusion: $($run.conclusion))"
    return $result
  }

  # Binding 0 (the FATAL fix): the check run must be attributable to the
  # pinned workflow, not merely present on the right commit. A check run
  # created by GitHub Actions carries a check_suite.id; every workflow run
  # under that check suite is queryable, and each carries the workflow
  # file's own repo-relative `path`. Requiring a match is what makes an
  # unrelated same-commit check run unable to stand in for the pinned one,
  # whatever it is named or however successfully it completes.
  $workflowRelPath = [string]$binding.pinned_workflow_path
  $checkSuiteId = $null
  if ($run.check_suite -and $run.check_suite.id) { $checkSuiteId = [string]$run.check_suite.id }
  if ([string]::IsNullOrWhiteSpace($checkSuiteId)) {
    $result.Reason = "check run $parsedId carries no check_suite id -- cannot resolve which GitHub Actions workflow, if any, produced it, so it cannot be attributed to the pinned review workflow"
    return $result
  }
  $runsApi = Invoke-NativeCapture { gh api "repos/$ownerRepo/actions/runs?check_suite_id=$checkSuiteId" }
  if ($runsApi.ExitCode -ne 0) {
    $result.Reason = "the GitHub API query for workflow runs under check suite $checkSuiteId failed -- cannot independently verify"
    return $result
  }
  $runsResponse = $null
  try {
    $runsResponse = ($runsApi.Output | Out-String) | ConvertFrom-Json
  } catch {
    $result.Reason = "the GitHub API response for workflow runs under check suite $checkSuiteId could not be parsed"
    return $result
  }
  # Independent AI Reviewer round-2 compatibility finding: a workflow run's own `path` field can
  # carry a trailing `@ref` (e.g. `.github/workflows/adversarial-review.yml@main`)
  # -- a legitimate GitHub API value, not a forgery attempt. Normalized away
  # before comparison; this only makes the match more lenient about the
  # suffix format, never about the path text itself, so it cannot weaken the
  # binding the FATAL fix (round 1) added.
  $matchingWorkflowRuns = @($runsResponse.workflow_runs | Where-Object { (([string]$_.path) -replace '@.*$', '') -eq $workflowRelPath })
  if ($matchingWorkflowRuns.Count -eq 0) {
    $result.Reason = "check run $parsedId's check suite is not associated with any workflow run at the pinned path '$workflowRelPath' -- this check run cannot be attributed to the pinned review workflow, whatever it is named or however successfully it completed"
    return $result
  }

  # Binding 1: the check run's own API-attested output must carry the digest
  # of the review artifact's real bytes -- never the review file's own claim
  # about its digest, which would be circular (the file cannot attest to
  # itself). The digest is looked for in output.summary/output.text, wherever
  # the workflow chose to place it.
  $realDigest = Get-ExecutionFileDigest -Path $ReviewPath
  $outputText = "$($run.output.summary) $($run.output.text)"
  if (-not $realDigest -or $outputText -notmatch [regex]::Escape($realDigest)) {
    $result.Reason = "the check run's own API-attested output does not carry the real SHA-256 digest of EXECUTION-REVIEW.json's current bytes -- the artifact on disk cannot be tied to what the check run actually produced"
    return $result
  }

  # Binding 2: the pinned workflow file's content, AT THE COMMIT BEING
  # VERIFIED, must match the digest an organization pinned in policy. This is
  # what stops an executor from weakening the review workflow within the very
  # commit range under verification -- a change here is also caught
  # independently by EXEC-004 once the pinned path is a default
  # prohibited_paths entry (see scripts/export-execution-contract.ps1).
  $workflowBytes = Get-GitBlobBytes -GitRepoRoot $GitRepoRoot -Revision "$($Review.head_sha):$workflowRelPath"
  if ($null -eq $workflowBytes) {
    $result.Reason = "the pinned review workflow '$workflowRelPath' could not be read at commit $($Review.head_sha)"
    return $result
  }
  $workflowDigest = ([System.Security.Cryptography.SHA256]::Create().ComputeHash($workflowBytes) | ForEach-Object { $_.ToString("x2") }) -join ""
  if ($workflowDigest -ne ([string]$binding.pinned_workflow_digest).ToLowerInvariant()) {
    $result.Reason = "the review workflow '$workflowRelPath' at commit $($Review.head_sha) does not match the digest pinned in policy -- the workflow was modified since it was pinned, so this run cannot be trusted as the reviewed one"
    return $result
  }

  $result.Verified = $true
  return $result
}

function Test-AdversarialReviewEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [Parameter(Mandatory = $true)][string]$ContractPath,
    $Contract,
    [string]$EffectiveMode,
    $ResultDocument,
    [string]$VerdictBaseSha,
    [string]$VerdictHeadSha,
    [string]$WorkItemId,
    [Parameter(Mandatory = $true)][string]$FrameworkRoot,
    [Parameter(Mandatory = $true)][string]$GitRepoRoot,
    [string[]]$ObservedPaths = @(),
    [string]$DecisionLogRelPath = $null
  )

  $policy = Read-AdversarialReviewPolicy -FrameworkRoot $FrameworkRoot
  $enforcement = $policy.enforcement_by_mode.$EffectiveMode
  if (-not $enforcement -or $enforcement -eq "disabled") { return }

  $reviewPath = Join-Path (Split-Path -Parent $ContractPath) "EXECUTION-REVIEW.json"
  $review = Read-ExecutionReview -Path $reviewPath

  if (-not $review.Present) {
    $severity = $policy.severity_when_missing.$EffectiveMode
    if ($severity) {
      Add-Result $severity.ToUpperInvariant() "No EXECUTION-REVIEW.json found. In $EffectiveMode mode, adversarial review evidence is $enforcement." "AREV-001" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
    }
    return
  }
  if (-not $review.Valid) {
    Add-Result FAIL "EXECUTION-REVIEW.json is present but invalid: $($review.Error)" "AREV-001" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
    return
  }
  Add-Result PASS "EXECUTION-REVIEW.json is present and structurally valid." "AREV-001" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
  $doc = $review.Document

  # --- AREV-002: contract identity -------------------------------------------
  $identityOk = $true
  if ([string]$doc.contract_sha256 -ne $Contract.Digest) {
    $identityOk = $false
    Add-Result FAIL "The review answers a different contract than the one under verification (contract_sha256 mismatch)." "AREV-002" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId -Field "contract_sha256"
  }
  if ([string]$doc.base_sha -ne $VerdictBaseSha -or [string]$doc.head_sha -ne $VerdictHeadSha) {
    $identityOk = $false
    Add-Result FAIL "The review's base_sha/head_sha do not match the commits under verification -- it cannot be cited as evidence for a different diff." "AREV-002" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId -Field "base_sha/head_sha"
  }
  if ($identityOk) {
    Add-Result PASS "The review's contract_sha256, base_sha, and head_sha match the execution under verification." "AREV-002" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
  }

  # --- AREV-003: provenance tier ---------------------------------------------
  $validTiers = @("artifact-observed", "externally-observed", "human-attested")
  $tier = [string]$doc.provenance.tier
  if ($validTiers -notcontains $tier) {
    Add-Result FAIL "provenance.tier '$tier' is not a recognized tier ($($validTiers -join ' / '))." "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId -Field "provenance.tier"
  } elseif ($enforcement -eq "required") {
    if ($tier -eq "human-attested") {
      if ([string]$doc.reviewer -and $ResultDocument -and [string]$ResultDocument.executor -and ([string]$doc.reviewer -eq [string]$ResultDocument.executor)) {
        Add-Result FAIL "provenance.tier is human-attested, but the named reviewer is the same actor as the executor -- a reviewer cannot review its own work." "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId -Field "reviewer"
      } else {
        Add-Result PASS "provenance.tier is human-attested, satisfying Strict directly." "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
      }
    } elseif ($tier -eq "externally-observed") {
      $binding = Test-ExternallyObservedReviewBinding -Review $doc -ReviewPath $reviewPath -GitRepoRoot $GitRepoRoot -FrameworkRoot $FrameworkRoot -ReviewArtifactPolicy $policy
      if ($binding.Verified) {
        Add-Result PASS "provenance.tier is externally-observed and all four bindings verified (check run, artifact digest, workflow digest, contract identity)." "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
      } else {
        Add-Result FAIL "provenance.tier is externally-observed but could not be independently verified: $($binding.Reason)" "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId -Field "provenance"
      }
    } else {
      # artifact-observed: never satisfies Strict alone. Needs a promotion --
      # the same shape EXEC-005/EXEC-007 already use for test evidence, reused
      # here with a new claim type rather than a new mechanism.
      $promoted = $false
      $promotionReason = "no review-evidence-accepted authority claim was found"
      if ($ResultDocument -and $ResultDocument.PSObject.Properties["authority_claims"]) {
        foreach ($claim in @($ResultDocument.authority_claims)) {
          if ([string]$claim.type -ne "review-evidence-accepted") { continue }
          $decisionRef = $null
          if ($claim.PSObject.Properties["decision_ref"]) { $decisionRef = [string]$claim.decision_ref }
          $resolved = Resolve-DecisionRecord -ProjectPath $ProjectPath -DecisionRef $decisionRef
          if (-not $resolved.Found) {
            $promotionReason = "authority claim cites decision record '$decisionRef', which could not be resolved: $($resolved.Reason)"
            continue
          }
          if ($DecisionLogRelPath -and ($ObservedPaths -contains $DecisionLogRelPath)) {
            $promotionReason = "decision record '$decisionRef' exists, but decision-log.md was itself changed within the commit range under verification -- not independent of the execution it would authorize"
            continue
          }
          $bindProblem = Test-DecisionAuthorityBinding -Row $resolved.Row -ClaimType "review-evidence-accepted" -WorkItemId $WorkItemId -ContractSha256 $Contract.Digest
          if ($bindProblem) {
            $promotionReason = "decision record '$decisionRef' resolves but does not authorize this claim: $bindProblem"
            continue
          }
          $promoted = $true
          break
        }
      }
      if ($promoted) {
        Add-Result PASS "provenance.tier is artifact-observed, promoted by a bound, resolvable human review-evidence-accepted claim." "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
      } else {
        Add-Result FAIL "provenance.tier is artifact-observed, which never satisfies Strict on its own: $promotionReason." "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId -Field "provenance.tier"
      }
    }
  } else {
    Add-Result PASS "provenance.tier is $tier (advisory mode; not required to satisfy a check)." "AREV-003" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
  }

  # --- AREV-004: finding schema validity -------------------------------------
  $severities = @($policy.finding_severities)
  $categories = @($policy.finding_categories)
  $statuses = @($policy.finding_statuses)
  $findingProblems = @()
  foreach ($finding in @($doc.findings)) {
    $findingId = [string]$finding.finding_id
    if ([string]::IsNullOrWhiteSpace($findingId)) { $findingProblems += "a finding is missing finding_id"; continue }
    if ($severities -notcontains [string]$finding.severity) { $findingProblems += "$findingId has invalid severity '$($finding.severity)'" }
    if ($categories -notcontains [string]$finding.category) { $findingProblems += "$findingId has invalid category '$($finding.category)'" }
    if ($statuses -notcontains [string]$finding.status) { $findingProblems += "$findingId has invalid status '$($finding.status)'" }
    if ([string]::IsNullOrWhiteSpace([string]$finding.description)) { $findingProblems += "$findingId is missing a description" }
    if ([string]::IsNullOrWhiteSpace([string]$finding.suggestion)) { $findingProblems += "$findingId is missing a suggestion" }
  }
  if ($findingProblems.Count -eq 0) {
    Add-Result PASS "Every finding carries a valid finding_id, severity, category, status, description, and suggestion." "AREV-004" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId
  } else {
    Add-Result FAIL ("Finding schema problems: " + ($findingProblems -join "; ")) "AREV-004" -Artifact "EXECUTION-REVIEW.json" -ItemId $WorkItemId -Field "findings"
  }

  # --- AREV-005/006: finding lifecycle authority -----------------------------
  # AREV-005 is closure-authority-by-role: who may set which status.
  # AREV-006 is the resolvable-decision-record requirement for a closure
  # status, and the human-only-category rule -- split from AREV-005 so a
  # missing decision_ref and a wrong-actor closure are two distinguishable
  # findings, not one blended message.
  $closurePolicy = $policy.closure_policy
  $settableBy = $closurePolicy.settable_by
  $nonClosure = @($closurePolicy.non_closure_statuses)
  $requiresDecisionRef = @($closurePolicy.statuses_requiring_decision_ref)
  $humanOnlyCategories = @($closurePolicy.human_only_categories)
  $reviewerKind = [string]$doc.reviewer_kind

  # Independent AI Reviewer's independent review found $settableBy was loaded from policy and
  # never actually applied -- an ai-kind reviewer could set
  # false_positive/accepted_risk/deferred directly, human-only category or
  # not, as long as a bound decision resolved outside the verified range.
  # Enforced here, driven by policy rather than a hardcoded list:
  # EXECUTION-REVIEW.json's findings[] is authored by the reviewer role, so a
  # status settable_by restricts to "human" and no other role may only appear
  # here when reviewer_kind is literally human -- the one case where
  # "reviewer" and "human" are provably the same actor.
  $humanOnlyStatuses = @()
  if ($settableBy) {
    foreach ($prop in $settableBy.PSObject.Properties) {
      $allowedRoles = @($prop.Value | ForEach-Object { [string]$_ })
      if ($allowedRoles.Count -eq 1 -and $allowedRoles[0] -eq "human") {
        $humanOnlyStatuses += $prop.Name
      }
    }
  }

  foreach ($finding in @($doc.findings)) {
    $findingId = [string]$finding.finding_id
    $status = [string]$finding.status
    $category = [string]$finding.category
    if ($statuses -notcontains $status) { continue } # already reported by AREV-004

    if ($requiresDecisionRef -contains $status) {
      $decisionRef = $null
      if ($finding.PSObject.Properties["decision_ref"]) { $decisionRef = [string]$finding.decision_ref }
      $resolved = Resolve-DecisionRecord -ProjectPath $ProjectPath -DecisionRef $decisionRef
      if (-not $resolved.Found) {
        Add-Result FAIL "$findingId has status '$status', which requires a resolvable decision record, but '$decisionRef' does not resolve: $($resolved.Reason)" "AREV-006" -Artifact "EXECUTION-REVIEW.json" -ItemId $findingId -Field "decision_ref"
      } elseif ($DecisionLogRelPath -and ($ObservedPaths -contains $DecisionLogRelPath)) {
        Add-Result FAIL "$findingId cites decision record '$decisionRef' for its '$status' status, but decision-log.md was itself changed within the commit range under verification." "AREV-006" -Artifact "decision-log.md" -ItemId $findingId -Field "decision_ref"
      } else {
        Add-Result PASS "$findingId's '$status' status resolves to a real, independent decision record." "AREV-006" -Artifact "EXECUTION-REVIEW.json" -ItemId $findingId
      }
    }

    if ($humanOnlyStatuses -contains $status -and $reviewerKind -ne "human") {
      Add-Result FAIL "$findingId has status '$status', which closure_policy.settable_by restricts to human authority, but reviewer_kind is '$reviewerKind'. An ai-kind reviewer may not set this status on any finding, human-only category or not." "AREV-005" -Artifact "EXECUTION-REVIEW.json" -ItemId $findingId -Field "status"
    } elseif ($humanOnlyCategories -contains $category -and $status -eq "resolved" -and $reviewerKind -ne "human") {
      Add-Result FAIL "$findingId is category '$category' (human-only) and was set to 'resolved' by a non-human reviewer (reviewer_kind: $reviewerKind). An AI reviewer may never close a human-only-category finding under any status." "AREV-005" -Artifact "EXECUTION-REVIEW.json" -ItemId $findingId -Field "status"
    } elseif ($nonClosure -contains $status) {
      # open/disputed: no further settable_by check needed -- this file
      # cannot tell who set a non-closure status, only whether the status
      # itself is a closure. An executor's own EXECUTION-RESULT.json can
      # never claim a closure status on a finding at all (checked
      # separately, below).
      continue
    }
  }

  # The executor cannot self-close: if EXECUTION-RESULT.json itself claims to
  # have set any status other than open/disputed on a finding, that is the
  # one transition this file's structure alone can attribute to the executor,
  # and it is exactly the transition the executor is never allowed to make.
  if ($ResultDocument -and $ResultDocument.PSObject.Properties["review_finding_dispositions"]) {
    foreach ($disposition in @($ResultDocument.review_finding_dispositions)) {
      $status = [string]$disposition.status
      if ($nonClosure -notcontains $status) {
        Add-Result FAIL "EXECUTION-RESULT.json claims to have set finding '$($disposition.finding_id)' to '$status'. The executor may only move a finding to 'disputed', with evidence -- never to a closure or acceptance state." "AREV-005" -Artifact "EXECUTION-RESULT.json" -ItemId ([string]$disposition.finding_id) -Field "review_finding_dispositions"
      }
    }
  }
}
